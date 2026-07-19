import 'dart:convert';
import 'dart:io';

import 'model_paths.dart';

/// Sidecar Ollama w paczce desktopowej (Windows / Linux).
///
/// ```
/// bundle/
///   trener_jezykowy[.exe]
///   bundled/ollama/ollama[.exe]
///   models/Bielik-11B-v3.0-Instruct.Q4_K_M.gguf
/// ```
class BundledOllama {
  BundledOllama._();

  static BundledOllama? _instance;
  static BundledOllama get instance => _instance ??= BundledOllama._();

  Process? _proc;
  String? lastError;
  String baseUrl = 'http://127.0.0.1:11434';
  String modelName = kBundledOllamaModelName;

  bool get isStarted => _proc != null;

  Future<bool> _httpOk(
    String path, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final req = await client.getUrl(uri).timeout(timeout);
      final res = await req.close().timeout(timeout);
      await res.drain<void>();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<String>> listModels() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl/api/tags');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 5));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final models = decoded['models'];
      if (models is! List) return [];
      return [
        for (final m in models)
          if (m is Map && m['name'] is String) (m['name'] as String),
      ];
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> isServerUp() => _httpOk('/api/tags');

  Future<File> _modelfileFor(File gguf, String name) async {
    final dir = gguf.parent;
    final mf = File('${dir.path}/Modelfile.$name');
    await mf.writeAsString('''
FROM ${gguf.path}
TEMPLATE """{{ if .System }}<|start_header_id|>system<|end_header_id|>
{{ .System }}<|eot_id|>{{ end }}{{ if .Prompt }}<|start_header_id|>user<|end_header_id|>
{{ .Prompt }}<|eot_id|>{{ end }}<|start_header_id|>assistant<|end_header_id|>
{{ .Response }}<|eot_id|>"""
PARAMETER stop "<|start_header_id|>"
PARAMETER stop "<|end_header_id|>"
PARAMETER stop "<|eot_id|>"
PARAMETER temperature 0.7
''');
    return mf;
  }

  Future<bool> _createModel(File ollamaBin, File gguf, String name) async {
    final models = await listModels();
    if (models.any((m) => m == name || m.startsWith('$name:'))) {
      modelName = name;
      return true;
    }
    final mf = await _modelfileFor(gguf, name);
    try {
      final r = await Process.run(
        ollamaBin.path,
        ['create', name, '-f', mf.path],
        environment: {
          ...Platform.environment,
          'OLLAMA_HOST': '127.0.0.1:11434',
        },
      );
      if (r.exitCode != 0) {
        lastError = 'ollama create: ${r.stderr}'.trim();
        return false;
      }
      modelName = name;
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  /// Startuje bundlowaną Ollamę (jeśli potrzeba) i zapewnia Bielik 11B v3.
  Future<bool> ensureReady() async {
    lastError = null;
    if (Platform.isAndroid || Platform.isIOS) {
      lastError = 'Ollama sidecar tylko na PC';
      return false;
    }

    final alreadyUp = await isServerUp();
    final bin = await findBundledOllamaBinary();
    final gguf = await findDesktopGguf();

    if (!alreadyUp) {
      if (bin == null) {
        lastError = 'Brak bundled/ollama — dołącz sidecar albo zainstaluj Ollamę.';
        return false;
      }
      try {
        final modelsDir = await ensureAppModelsDir();
        _proc = await Process.start(
          bin.path,
          ['serve'],
          environment: {
            ...Platform.environment,
            'OLLAMA_HOST': '127.0.0.1:11434',
            'OLLAMA_MODELS': modelsDir.path,
          },
          mode: ProcessStartMode.detachedWithStdio,
        );
      } catch (e) {
        lastError = 'Start Ollamy: $e';
        return false;
      }
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (await isServerUp()) break;
      }
      if (!await isServerUp()) {
        lastError = 'Ollama nie wystartowała (port 11434).';
        return false;
      }
    }

    final tags = await listModels();
    const preferred = [
      kBundledOllamaModelName,
      'bielik-full:latest',
      'SpeakLeash/bielik-11b-v3.0-instruct:latest',
      'SpeakLeash/bielik-11b-v3.0-instruct:Q4_K_M',
      'speakleash/bielik-11b-v3.0-instruct:Q4_K_M',
      'bielik-latest:latest',
      'bielik:latest',
    ];
    for (final p in preferred) {
      final hit = tags.where(
        (t) => t == p || t.startsWith('${p.split(':').first}:'),
      );
      if (hit.isNotEmpty) {
        modelName = hit.first;
        return true;
      }
    }
    final bielikTag = tags.where((t) => t.toLowerCase().contains('bielik'));
    if (bielikTag.isNotEmpty) {
      modelName = bielikTag.first;
      return true;
    }

    final createBin = bin ?? await _resolveOllamaCli();
    if (gguf != null && createBin != null) {
      final ok = await _createModel(createBin, gguf, kBundledOllamaModelName);
      if (ok) return true;
    }

    // Brak lokalnego GGUF 11B (np. mały ZIP z GitHub) — cichy pull, bez klikania użytkownika.
    if (createBin != null) {
      lastError = null;
      try {
        final pull = await Process.run(
          createBin.path,
          ['pull', 'SpeakLeash/bielik-11b-v3.0-instruct:Q4_K_M'],
          environment: {
            ...Platform.environment,
            'OLLAMA_HOST': '127.0.0.1:11434',
          },
        );
        if (pull.exitCode == 0) {
          modelName = 'SpeakLeash/bielik-11b-v3.0-instruct:Q4_K_M';
          return true;
        }
        lastError = 'ollama pull: ${pull.stderr}'.trim();
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (tags.isNotEmpty) {
      modelName = tags.first;
      return true;
    }
    lastError = lastError ??
        'Ollama działa, ale brak modelu (paczka bez GGUF / brak sieci na pull).';
    return false;
  }

  Future<File?> _resolveOllamaCli() async {
    final bundled = await findBundledOllamaBinary();
    if (bundled != null) return bundled;
    try {
      final r = await Process.run('which', ['ollama']);
      if (r.exitCode == 0) {
        final p = (r.stdout as String).trim().split('\n').first;
        if (p.isNotEmpty) return File(p);
      }
    } catch (_) {}
    return null;
  }

  Future<void> stop() async {
    try {
      _proc?.kill();
    } catch (_) {}
    _proc = null;
  }
}
