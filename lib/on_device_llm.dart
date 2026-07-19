import 'dart:io';

import 'package:llm_llamacpp/llm_llamacpp.dart';

import 'bundled_model_extract.dart';
import 'model_paths.dart';

/// Minimalna wiadomość czatu (bez zależności od ai_chat.dart).
class LlmTurn {
  const LlmTurn({required this.role, required this.text});
  final String role;
  final String text;
}

/// Lokalny silnik GGUF (llama.cpp) — telefon + awaryjny desktop.
class OnDeviceLlm {
  OnDeviceLlm._();

  static OnDeviceLlm? _instance;
  static OnDeviceLlm get instance => _instance ??= OnDeviceLlm._();

  LlamaCppRepository? _modelRepo;
  LlamaCppChatRepository? _chat;
  String? _loadedPath;
  String? lastError;

  bool get isReady => _chat != null && _loadedPath != null;

  Future<File?> resolveGgufPath({
    bool preferDesktop = false,
    LlmProgressCallback? onProgress,
  }) async {
    if (preferDesktop && !Platform.isAndroid && !Platform.isIOS) {
      final big = await BundledModelExtract.ensureDesktopGguf();
      if (big != null) return big;
    }
    return BundledModelExtract.ensurePhoneGguf(onProgress: onProgress);
  }

  Future<bool> ensureLoaded({
    bool preferDesktop = false,
    LlmProgressCallback? onProgress,
  }) async {
    lastError = null;
    final file = await resolveGgufPath(
      preferDesktop: preferDesktop,
      onProgress: onProgress,
    );
    if (file == null) {
      lastError = BundledModelExtract.lastError ??
          'Brak zbundlowanego modelu w paczce aplikacji.';
      return false;
    }
    if (_chat != null && _loadedPath == file.path) return true;

    await dispose();
    onProgress?.call(
      const LlmPrepareProgress(
        phase: 'load',
        message:
            'Ładuję model do pamięci (jednorazowo przy tej sesji)… '
            'Może chwilę potrwać na telefonie.',
      ),
    );
    try {
      final gpu = (!Platform.isAndroid && !Platform.isIOS) ? 99 : 0;
      _modelRepo = LlamaCppRepository();
      final model = await _modelRepo!.loadModel(
        file.path,
        options: ModelLoadOptions(nGpuLayers: gpu),
      );
      _chat = LlamaCppChatRepository.withModel(
        model,
        _modelRepo!.bindings,
        contextSize: Platform.isAndroid || Platform.isIOS ? 2048 : 4096,
        nGpuLayers: gpu,
      );
      _loadedPath = file.path;
      onProgress?.call(
        const LlmPrepareProgress(
          phase: 'ready',
          message: 'Model gotowy.',
          progress: 1,
        ),
      );
      return true;
    } catch (e) {
      lastError = e.toString();
      await dispose();
      return false;
    }
  }

  Future<String?> chat({
    required List<LlmTurn> history,
    required String systemPrompt,
  }) async {
    if (_chat == null || _loadedPath == null) return null;
    try {
      final messages = <LLMMessage>[
        LLMMessage(role: LLMRole.system, content: systemPrompt),
        for (final m in history)
          if (m.role != 'system')
            LLMMessage(
              role: m.role == 'assistant' ? LLMRole.assistant : LLMRole.user,
              content: m.text,
            ),
      ];
      final response = await _chat!.chatResponse(
        _loadedPath!,
        messages: messages,
      );
      final text = (response.content ?? '').trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      _chat?.dispose();
    } catch (_) {}
    try {
      if (_modelRepo != null && _loadedPath != null) {
        _modelRepo!.unloadModel(_loadedPath!);
      }
      _modelRepo?.dispose();
    } catch (_) {}
    _chat = null;
    _modelRepo = null;
    _loadedPath = null;
  }

  String labelForLoaded() {
    final path = _loadedPath ?? '';
    if (path.contains('11B') || path.contains(kDesktopGgufName)) {
      return 'Bielik 11B v3 (llama.cpp) — lokalnie na PC';
    }
    return 'Bielik 1.5B v3 (llama.cpp) — lokalnie na urządzeniu';
  }
}
