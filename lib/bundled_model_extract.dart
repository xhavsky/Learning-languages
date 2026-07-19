import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'model_paths.dart';

const _assetChannel = MethodChannel('pl.anielka.trener_jezykowy/assets');

/// Przygotowuje lokalne modele z paczki aplikacji (bez ręcznego pobierania).
///
/// - **Android:** stream-copy GGUF 1.5B z APK assets → Documents/models/
/// - **Desktop:** modele leżą już w `models/` obok exe (skrypt package_*)
class BundledModelExtract {
  BundledModelExtract._();

  static String? lastError;
  static String? status;

  /// Zwraca ścieżkę do GGUF telefonu (1.5B), wyciągając z APK jeśli trzeba.
  static Future<File?> ensurePhoneGguf() async {
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
      status = 'Przygotowuję lokalny model Bielik (pierwszy start, chwilę)…';
      try {
        final assetPath = 'models/$kPhoneGgufName';
        final exists = await _assetChannel.invokeMethod<bool>(
          'assetExists',
          {'path': assetPath},
        );
        if (exists != true) {
          lastError =
              'W APK brak modelu ($assetPath). Zbuduj przez scripts/build_apk.sh.';
          return null;
        }
        await _assetChannel.invokeMethod<String>(
          'copyAsset',
          {'path': assetPath, 'dest': dest.path},
        );
        if (await dest.exists() && await dest.length() > 1024 * 1024) {
          status = null;
          return dest;
        }
        lastError = 'Kopiowanie modelu z APK nie powiodło się.';
        return null;
      } catch (e) {
        lastError = e.toString();
        return null;
      }
    }

    // Desktop: oczekujemy models/ w paczce release
    lastError =
        'Brak $kPhoneGgufName w paczce (folder models/ obok programu).';
    return null;
  }

  /// Desktop: upewnij się, że 11B jest dostępny obok exe (bez ściągania).
  static Future<File?> ensureDesktopGguf() async {
    lastError = null;
    final existing = await findDesktopGguf();
    if (existing != null) return existing;
    lastError =
        'Brak $kDesktopGgufName w paczce (folder models/ obok programu).';
    return null;
  }

  /// Krótki opis katalogu dokumentów (Android — debug).
  static Future<String> documentsHint() async {
    try {
      final d = await getApplicationDocumentsDirectory();
      return d.path;
    } catch (_) {
      return '';
    }
  }
}
