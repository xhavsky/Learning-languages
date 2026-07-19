import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Nazwy plików (scripts/fetch_ondevice_models.sh → paczka release).
const kPhoneGgufName = 'Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf';
const kDesktopGgufName = 'Bielik-11B-v3.0-Instruct.Q4_K_M.gguf';
const kBundledOllamaModelName = 'bielik-full';

/// Katalog obok binarki Fluttera (release ZIP / Linux bundle).
Directory? bundleRootDir() {
  try {
    return File(Platform.resolvedExecutable).parent;
  } catch (_) {
    return null;
  }
}

Future<List<Directory>> candidateModelDirs() async {
  final out = <Directory>[];
  void add(Directory? d) {
    if (d == null) return;
    if (!out.any((x) => x.path == d.path)) out.add(d);
  }

  final root = bundleRootDir();
  if (root != null) {
    add(Directory('${root.path}/models'));
    add(Directory('${root.path}/bundled/models'));
    add(root);
    add(Directory('${root.path}/../../../../models'));
    add(Directory('${root.path}/../../../models'));
  }

  try {
    final docs = await getApplicationDocumentsDirectory();
    add(Directory('${docs.path}/models'));
    add(docs);
  } catch (_) {}

  try {
    final support = await getApplicationSupportDirectory();
    add(Directory('${support.path}/models'));
  } catch (_) {}

  return out;
}

Future<File?> findModelFile(String fileName) async {
  for (final dir in await candidateModelDirs()) {
    final f = File('${dir.path}/$fileName');
    if (await f.exists() && await f.length() > 1024 * 1024) return f;
  }
  return null;
}

Future<File?> findPhoneGguf() => findModelFile(kPhoneGgufName);

Future<File?> findDesktopGguf() => findModelFile(kDesktopGgufName);

Future<File?> findBundledOllamaBinary() async {
  final root = bundleRootDir();
  if (root == null) return null;
  final names = Platform.isWindows
      ? ['ollama.exe', 'bundled/ollama/ollama.exe']
      : ['ollama', 'bundled/ollama/ollama'];
  for (final rel in names) {
    final f = File('${root.path}/$rel');
    if (await f.exists()) return f;
  }
  return null;
}

Future<Directory> ensureAppModelsDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/models');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}
