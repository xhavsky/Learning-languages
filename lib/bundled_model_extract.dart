import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'model_paths.dart';

const _assetChannel = MethodChannel('app.dialectium/assets');
const _progressChannel = EventChannel('app.dialectium/asset_progress');

/// Postęp jednorazowego przygotowania modelu LLM.
class LlmPrepareProgress {
  const LlmPrepareProgress({
    required this.phase,
    required this.message,
    this.progress,
    this.oneShot = true,
  });

  /// idle | extract | load | ollama | ready | error
  final String phase;
  final String message;

  /// 0..1 albo null gdy nieznany.
  final double? progress;
  final bool oneShot;
}

typedef LlmProgressCallback = void Function(LlmPrepareProgress p);

/// Przygotowuje lokalne modele z paczki (Android: kopia z APK z paskiem postępu).
class BundledModelExtract {
  BundledModelExtract._();

  static String? lastError;
  static String? status;

  static Future<File?> ensurePhoneGguf({LlmProgressCallback? onProgress}) async {
    lastError = null;
    status = null;

    final existing = await findPhoneGguf();
    if (existing != null) return existing;

    final destDir = await ensureAppModelsDir();
    final dest = File('${destDir.path}/$kPhoneGgufName');
    if (await dest.exists() && await dest.length() > 1024 * 1024) {
      return dest;
    }

    if (Platform.isAndroid) {
      status = 'Przygotowuję lokalny model Bielik (jednorazowo)…';
      onProgress?.call(
        const LlmPrepareProgress(
          phase: 'extract',
          message:
              'Pierwsze uruchomienie: kopiuję model językowy z aplikacji (~1 GB). '
              'To jednorazowa operacja — potem czat otworzy się od razu.',
          progress: 0,
        ),
      );
      StreamSubscription<dynamic>? sub;
      try {
        sub = _progressChannel.receiveBroadcastStream().listen((event) {
          if (event is Map) {
            final p = event['progress'];
            final bytes = event['bytes'];
            final total = event['total'];
            double? frac;
            if (p is num && p >= 0) {
              frac = p.toDouble().clamp(0.0, 1.0);
            }
            String extra = '';
            if (bytes is num && total is num && total > 0) {
              final mb = bytes / (1024 * 1024);
              final tot = total / (1024 * 1024);
              extra = ' (${mb.toStringAsFixed(0)} / ${tot.toStringAsFixed(0)} MB)';
            } else if (bytes is num) {
              extra = ' (${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB)…';
            }
            onProgress?.call(
              LlmPrepareProgress(
                phase: 'extract',
                message:
                    'Kopiuję model Bielik z paczki aplikacji$extra. '
                    'Jednorazowo — przy następnych startach już nie trzeba.',
                progress: frac,
              ),
            );
          }
        });

        final assetPath = 'models/$kPhoneGgufName';
        final exists = await _assetChannel.invokeMethod<bool>(
          'assetExists',
          {'path': assetPath},
        );
        if (exists != true) {
          lastError =
              'W APK brak modelu ($assetPath). Zbuduj przez scripts/build_apk.sh.';
          onProgress?.call(
            LlmPrepareProgress(
              phase: 'error',
              message: lastError!,
              oneShot: false,
            ),
          );
          return null;
        }
        await _assetChannel.invokeMethod<String>(
          'copyAsset',
          {'path': assetPath, 'dest': dest.path},
        );
        if (await dest.exists() && await dest.length() > 1024 * 1024) {
          status = null;
          onProgress?.call(
            const LlmPrepareProgress(
              phase: 'load',
              message: 'Model skopiowany. Ładuję do pamięci…',
              progress: 1,
            ),
          );
          return dest;
        }
        lastError = 'Kopiowanie modelu z APK nie powiodło się.';
        return null;
      } catch (e) {
        lastError = e.toString();
        onProgress?.call(
          LlmPrepareProgress(phase: 'error', message: lastError!, oneShot: false),
        );
        return null;
      } finally {
        await sub?.cancel();
      }
    }

    lastError =
        'Brak $kPhoneGgufName w paczce (folder models/ obok programu).';
    return null;
  }

  static Future<File?> ensureDesktopGguf() async {
    lastError = null;
    final existing = await findDesktopGguf();
    if (existing != null) return existing;
    lastError =
        'Brak $kDesktopGgufName w paczce (folder models/ obok programu).';
    return null;
  }

  static Future<String> documentsHint() async {
    try {
      final d = await getApplicationDocumentsDirectory();
      return d.path;
    } catch (_) {
      return '';
    }
  }
}
