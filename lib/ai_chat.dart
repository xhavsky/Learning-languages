import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bundled_model_extract.dart';
import 'bundled_ollama.dart';
import 'models.dart';
import 'on_device_llm.dart';
import 'storage.dart';
import 'theme.dart';
import 'ui_fx.dart';

class ChatMessage {
  ChatMessage({required this.role, required this.text});

  final String role; // user | assistant | system
  final String text;
}

const _prefsOllamaHost = 'ollamaHost';
const _defaultModel = 'bielik-full';

/// Zapisany adres Ollamy na TYM urządzeniu (opcjonalnie).
Future<String> loadOllamaHostPref() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getString(_prefsOllamaHost) ?? '').trim();
}

Future<void> saveOllamaHostPref(String host) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsOllamaHost, host.trim());
}

/// Wynik połączenia z modelem NA URZĄDZENIU (bez portalu / bez chmury).
class LocalLlmSession {
  const LocalLlmSession({
    required this.kind,
    required this.label,
    this.baseUrl,
    this.model,
  });

  /// ollama | gguf | script
  final String kind;
  final String label;
  final String? baseUrl;
  final String? model;

  bool get isLive => kind == 'ollama' || kind == 'gguf' || kind == 'script';
}

Future<String?> _ollamaChatAt({
  required String baseUrl,
  required List<ChatMessage> history,
  required String systemPrompt,
  String model = _defaultModel,
  Duration connectTimeout = const Duration(seconds: 4),
  Duration readTimeout = const Duration(seconds: 120),
}) async {
  final client = HttpClient();
  try {
    final root = baseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$root/api/chat');
    final req = await client.postUrl(uri).timeout(connectTimeout);
    req.headers.set('Content-Type', 'application/json; charset=utf-8');
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      for (final m in history)
        if (m.role != 'system') {'role': m.role, 'content': m.text},
    ];
    req.add(
      utf8.encode(
        jsonEncode({
          'model': model,
          'stream': false,
          'messages': messages,
          'options': {'temperature': 0.85, 'num_predict': 160},
        }),
      ),
    );
    final res = await req.close().timeout(readTimeout);
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final msg = decoded['message'];
    if (msg is Map && msg['content'] is String) {
      final text = (msg['content'] as String).trim();
      return text.isEmpty ? null : text;
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

List<String> _ollamaCandidateBases(String customHost) {
  final out = <String>[];
  void add(String u) {
    final t = u.trim();
    if (t.isEmpty) return;
    var url = t;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (!out.contains(url)) out.add(url);
  }

  add(customHost);
  add('http://127.0.0.1:11434');
  if (Platform.isAndroid) add('http://10.0.2.2:11434');
  return out;
}

Future<String?> _pickOllamaModel(String baseUrl) async {
  final client = HttpClient();
  try {
    final root = baseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$root/api/tags');
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 2));
    final res = await req.close().timeout(const Duration(seconds: 4));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final models = decoded['models'];
    if (models is! List) return null;
    final names = <String>[
      for (final m in models)
        if (m is Map && m['name'] is String) m['name'] as String,
    ];
    const preferred = [
      'bielik-full',
      'bielik-full:latest',
      'bielik-phone',
      'bielik-phone:latest',
      'SpeakLeash/bielik-11b-v3.0-instruct:latest',
      'SpeakLeash/bielik-11b-v3.0-instruct:Q4_K_M',
      'bielik-latest:latest',
      'bielik:latest',
    ];
    for (final p in preferred) {
      final hit = names.where(
        (t) => t == p || t.startsWith('${p.split(':').first}:'),
      );
      if (hit.isNotEmpty) return hit.first;
    }
    final bielik = names.where((t) => t.toLowerCase().contains('bielik'));
    if (bielik.isNotEmpty) return bielik.first;
    return names.isEmpty ? null : names.first;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Szuka modelu NA URZĄDZENIU: Ollama (system / bundlowana) → GGUF → skrypt.
/// NIGDY nie łączy z portalem ani chmurą.
Future<LocalLlmSession> discoverLocalLlm({
  String? customHost,
  LlmProgressCallback? onProgress,
}) async {
  final host = customHost ?? await loadOllamaHostPref();
  final desktop = !Platform.isAndroid && !Platform.isIOS;

  // 1) Desktop: bundlowana / systemowa Ollama (tylko lokalne modele — bez pull)
  if (desktop) {
    onProgress?.call(
      const LlmPrepareProgress(
        phase: 'ollama',
        message: 'Szukam lokalnej Ollamy / Bielika w paczce…',
      ),
    );
    final bundled = BundledOllama.instance;
    if (await bundled.ensureReady()) {
      final probe = await _ollamaChatAt(
        baseUrl: bundled.baseUrl,
        history: const [],
        systemPrompt: 'Ping. Odpowiedz jednym słowem: OK',
        model: bundled.modelName,
        connectTimeout: const Duration(seconds: 3),
        readTimeout: const Duration(seconds: 45),
      );
      if (probe != null) {
        onProgress?.call(
          const LlmPrepareProgress(
            phase: 'ready',
            message: 'Gotowe.',
            progress: 1,
          ),
        );
        return LocalLlmSession(
          kind: 'ollama',
          baseUrl: bundled.baseUrl,
          model: bundled.modelName,
          label:
              'Bielik (Ollama${bundled.isStarted ? ' · bundled' : ''}) — lokalnie',
        );
      }
    }

    for (final base in _ollamaCandidateBases(host)) {
      final model = await _pickOllamaModel(base);
      if (model == null) continue;
      final probe = await _ollamaChatAt(
        baseUrl: base,
        history: const [],
        systemPrompt: 'Ping. Odpowiedz jednym słowem: OK',
        model: model,
        connectTimeout: const Duration(seconds: 2),
        readTimeout: const Duration(seconds: 30),
      );
      if (probe != null) {
        return LocalLlmSession(
          kind: 'ollama',
          baseUrl: base,
          model: model,
          label: 'Bielik / Ollama ($model) — lokalnie',
        );
      }
    }
  }

  // 2) GGUF via llama.cpp (telefon: 1.5B; PC fallback)
  final gguf = OnDeviceLlm.instance;
  if (await gguf.ensureLoaded(
    preferDesktop: desktop,
    onProgress: onProgress,
  )) {
    return LocalLlmSession(
      kind: 'gguf',
      label: gguf.labelForLoaded(),
    );
  }

  // 3) Awaryjny skrypt
  return LocalLlmSession(
    kind: 'script',
    label: gguf.lastError != null
        ? 'Tryb awaryjny (brak modelu): ${gguf.lastError}'
        : 'Tryb awaryjny — brak lokalnego modelu LLM',
  );
}

Future<String?> localLlmReply({
  required LocalLlmSession session,
  required List<ChatMessage> history,
  required String systemPrompt,
  required String lang,
  required List<Word> words,
  required int userTurns,
}) async {
  if (session.kind == 'ollama' && session.baseUrl != null) {
    return _ollamaChatAt(
      baseUrl: session.baseUrl!,
      history: history,
      systemPrompt: systemPrompt,
      model: session.model ?? _defaultModel,
    );
  }
  if (session.kind == 'gguf') {
    return OnDeviceLlm.instance.chat(
      history: [
        for (final m in history) LlmTurn(role: m.role, text: m.text),
      ],
      systemPrompt: systemPrompt,
    );
  }
  return fallbackTutorReply(
    lang: lang,
    words: words,
    history: history,
    userTurns: userTurns,
  );
}

/// @Deprecated — kompatybilność; preferuj [localLlmReply].
Future<String?> ollamaReply({
  required List<ChatMessage> history,
  required String systemPrompt,
  String model = _defaultModel,
}) async {
  return _ollamaChatAt(
    baseUrl: 'http://127.0.0.1:11434',
    history: history,
    systemPrompt: systemPrompt,
    model: model,
  );
}

String buildTutorSystemPrompt({
  required String lang,
  required List<Word> words,
}) {
  final sample = (List<Word>.of(words)..shuffle(Random()))
      .take(18)
      .map((w) => w.obcy)
      .join(', ');
  return '''
Jesteś przyjaciółką-trenerką w aplikacji „Dialectium”.
Język nauki: $lang.

CEL: prawdziwa rozmowa, nie quiz ze słówek.

ZASADY:
1. 1–2 krótkie zdania na odpowiedź. Mów głównie po $lang; polski tylko gdy naprawdę trzeba (1 krótkie słowo w nawiasie).
2. Naprzemiennie: czasem TY pytasz o nią (dzień, hobby, jedzenie, szkoła, rodzina, plany), czasem ONA ma zapytać Ciebie — proś o to wprost.
3. Reaguj na to, co napisała (emocja, detal). Nie ignoruj jej wiadomości.
4. Wplataj naturalnie słowa z jej bazy ($sample), ALE:
   - NIGDY nie dawaj gotowej odpowiedzi / tłumaczenia w tej samej wiadomości co pytanie.
   - NIGDY nie dawaj hintów ani podpowiedzi (ani pierwszej litery, ani liczby liter, ani „hint: …”).
   - Jeśli utknie: zachęć krótko („spróbuj jeszcze raz”) i idź dalej z rozmową — bez zdradzania słowa.
5. Unikaj powtarzania tego samego pytania. Zmieniaj temat co 1–2 tury.
6. Nie pisz list, kodu ani meta o AI. Jesteś miłą koleżanką-trenerką.
''';
}

/// Stan rozmowy offline — zapamiętuje ostatnie słówko / temat, żeby nie powtarzać.
class _FallbackBrain {
  Word? pendingWord;
  String? lastTopic;
  final usedTopics = <String>{};
}

final _fallbackBrain = _FallbackBrain();

String fallbackTutorReply({
  required String lang,
  required List<Word> words,
  required List<ChatMessage> history,
  required int userTurns,
}) {
  final rng = Random();
  final pool = words.isEmpty
      ? [Word(id: 'x', pl: 'cześć', obcy: 'hello')]
      : words;

  final lastUser = history.reversed
      .where((m) => m.role == 'user')
      .map((m) => m.text.trim())
      .firstOrNull;
  final lastAssistant = history.reversed
      .where((m) => m.role == 'assistant')
      .map((m) => m.text)
      .firstOrNull;

  // Otwarcie — pytanie o nią, bez quizu ze spoilerem.
  if (userTurns <= 1 && (lastUser == null || lastUser.isEmpty)) {
    return _opening(lang, rng);
  }

  // Jeśli wcześniej pytaliśmy o słówko — sprawdź odpowiedź delikatnie.
  final pending = _fallbackBrain.pendingWord;
  if (pending != null && lastUser != null) {
    final u = lastUser.toLowerCase();
    final ok = u.contains(pending.obcy.toLowerCase()) ||
        u.contains(pending.pl.toLowerCase()) ||
        // krótkie „tak / yes / sí / да” po wcześniejszej zachęcie
        RegExp(r'^(tak|yes|ok|sí|si|да|хорошо|jasne|pewnie)\b',
                caseSensitive: false)
            .hasMatch(u);
    _fallbackBrain.pendingWord = null;
    if (ok) {
      return _praiseThenAskAboutHer(lang, rng, pool);
    }
    // Bez hintów — zachęta i nowe pytanie.
    return _encourageThenContinue(lang, rng, pool);
  }

  // Co 3. turę — poproś, żeby ONA zapytała.
  if (userTurns >= 2 && userTurns % 3 == 0) {
    return _askHerToAsk(lang, rng);
  }

  // Reakcja na treść + nowe pytanie / mini-ćwiczenie bez spoilera.
  final reacted = _reactToUser(lang, lastUser, rng);
  final next = _nextBeat(lang, pool, rng, lastAssistant);
  return '$reacted $next'.trim();
}

String _opening(String lang, Random rng) {
  final opts = switch (lang) {
    'Hiszpański' => [
      '¡Hola! 😊 ¿Qué tal tu día hoy?',
      '¡Hey! ¿Qué hiciste hoy?',
      '¡Buenas! ¿Tienes hambre o estás bien?',
    ],
    'Rosyjski' => [
      'Привет! 😊 Как прошёл твой день?',
      'Привет! Что интересного сегодня?',
      'Здравствуй! Как настроение?',
    ],
    _ => [
      'Hi! 😊 How was your day?',
      'Hey! What did you do today?',
      'Hello! Are you tired or full of energy?',
    ],
  };
  return opts[rng.nextInt(opts.length)];
}

String _praiseThenAskAboutHer(String lang, Random rng, List<Word> pool) {
  final w = pool[rng.nextInt(pool.length)];
  final praise = switch (lang) {
    'Hiszpański' => ['¡Genial!', '¡Muy bien!', '¡Sí!'],
    'Rosyjski' => ['Молодец!', 'Отлично!', 'Класс!'],
    _ => ['Nice!', 'Great!', 'Yes!'],
  }[rng.nextInt(3)];

  // Czasem pytanie o życie, czasem poproś o użycie słowa BEZ podawania tłumaczenia.
  if (rng.nextBool()) {
    return switch (lang) {
      'Hiszpański' =>
        '$praise Ahora cuéntame: ¿cuál es tu comida favorita?',
      'Rosyjski' => '$praise А теперь скажи: какая у тебя любимая еда?',
      _ => '$praise Now tell me: what\'s your favourite food?',
    };
  }
  _fallbackBrain.pendingWord = w;
  return switch (lang) {
    'Hiszpański' =>
      '$praise Usa la palabra „${w.obcy}” en una frase corta sobre ti.',
    'Rosyjski' =>
      '$praise Используй слово „${w.obcy}” в коротком предложении о себе.',
    _ =>
      '$praise Use the word „${w.obcy}” in a short sentence about yourself.',
  };
}

String _encourageThenContinue(String lang, Random rng, List<Word> pool) {
  final nudge = switch (lang) {
    'Hiszpański' => [
      'Casi… inténtalo otra vez 🙂',
      'No pasa nada — prueba de nuevo.',
      'Cerca… una vez más.',
    ],
    'Rosyjski' => [
      'Почти… попробуй ещё раз 🙂',
      'Ничего — ещё раз.',
      'Близко… давай снова.',
    ],
    _ => [
      'Almost… try once more 🙂',
      'No worries — give it another go.',
      'Close… one more try.',
    ],
  }[rng.nextInt(3)];
  final next = _nextBeat(lang, pool, rng, null);
  return '$nudge $next'.trim();
}

String _askHerToAsk(String lang, Random rng) {
  final opts = switch (lang) {
    'Hiszpański' => [
      'Ahora tú: pregúntame algo. Por ejemplo sobre mi día o mi comida favorita.',
      '¡Tu turno! Hazme una pregunta en español.',
    ],
    'Rosyjski' => [
      'Теперь ты: задай мне вопрос. Например про мой день или любимую еду.',
      'Твой ход! Задай мне вопрос по-русски.',
    ],
    _ => [
      'Your turn: ask me something — about my day or my favourite food.',
      'Now you ask me a question in English!',
    ],
  };
  return opts[rng.nextInt(opts.length)];
}

String _reactToUser(String lang, String? lastUser, Random rng) {
  if (lastUser == null || lastUser.isEmpty) {
    return switch (lang) {
      'Hiszpański' => 'Vale.',
      'Rosyjski' => 'Ок.',
      _ => 'Okay.',
    };
  }
  final u = lastUser.toLowerCase();
  if (RegExp(r'(smut|sad|tired|zmęcz|уста|triste|cansad)').hasMatch(u)) {
    return switch (lang) {
      'Hiszpański' => 'Ay, lo siento…',
      'Rosyjski' => 'Ой, жаль…',
      _ => 'Aww, sorry…',
    };
  }
  if (RegExp(r'(lubię|like|love|gust|нрав|koch)').hasMatch(u)) {
    return switch (lang) {
      'Hiszpański' => '¡Qué guay!',
      'Rosyjski' => 'Круто!',
      _ => 'Cool!',
    };
  }
  if (lastUser.length <= 3) {
    return switch (lang) {
      'Hiszpański' => 'Cuéntame un poco más.',
      'Rosyjski' => 'Расскажи чуть больше.',
      _ => 'Tell me a bit more.',
    };
  }
  final soft = switch (lang) {
    'Hiszpański' => ['Entiendo.', 'Interesante.', 'Vale, gracias.'],
    'Rosyjski' => ['Поняла.', 'Интересно.', 'Спасибо.'],
    _ => ['I see.', 'Interesting.', 'Thanks for sharing.'],
  };
  return soft[rng.nextInt(soft.length)];
}

String _nextBeat(
  String lang,
  List<Word> pool,
  Random rng,
  String? lastAssistant,
) {
  final topics = switch (lang) {
    'Hiszpański' => [
      '¿Qué música te gusta?',
      '¿Prefieres gatos o perros?',
      '¿Qué comes normalmente en el desayuno?',
      'Si pudieras viajar mañana, ¿a dónde?',
      '¿Qué haces después de la escuela?',
    ],
    'Rosyjski' => [
      'Какая музыка тебе нравится?',
      'Кошки или собаки — что больше?',
      'Что обычно ешь на завтрак?',
      'Если бы завтра можно было куда-то поехать — куда?',
      'Что делаешь после школы?',
    ],
    _ => [
      'What music do you like?',
      'Cats or dogs — which one more?',
      'What do you usually eat for breakfast?',
      'If you could travel tomorrow, where?',
      'What do you do after school?',
    ],
  };

  // Unikaj powtórzenia tego samego tematu.
  final fresh = topics
      .where((t) => lastAssistant == null || !lastAssistant.contains(t))
      .toList();
  final pickFrom = fresh.isEmpty ? topics : fresh;

  // Co drugi raz — ćwiczenie ze słówkiem bez spoilera PL.
  if (rng.nextBool()) {
    final w = pool[rng.nextInt(pool.length)];
    _fallbackBrain.pendingWord = w;
    return switch (lang) {
      'Hiszpański' =>
          '¿Puedes usar „${w.obcy}” en una frase? (sin mirar la app)',
      'Rosyjski' =>
          'Можешь использовать „${w.obcy}” в предложении? (не подглядывай)',
      _ => 'Can you use „${w.obcy}” in a sentence? (no peeking)',
    };
  }

  final topic = pickFrom[rng.nextInt(pickFrom.length)];
  _fallbackBrain.lastTopic = topic;
  return topic;
}

/// Ekran codziennej rozmowy z modelem NA URZĄDZENIU (bez portalu).
class DailyChatPage extends StatefulWidget {
  const DailyChatPage({
    super.key,
    required this.lang,
    required this.pack,
    required this.store,
    required this.palette,
    required this.onXpChanged,
  });

  final String lang;
  final LangPack pack;
  final BazaStore store;
  final AppPalette palette;
  final VoidCallback onXpChanged;

  @override
  State<DailyChatPage> createState() => _DailyChatPageState();
}

class _DailyChatPageState extends State<DailyChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  var _busy = false;
  var _userTurns = 0;
  String? _status;
  double? _prepareProgress;
  var _preparing = false;
  LocalLlmSession _session = const LocalLlmSession(
    kind: 'script',
    label: 'Przygotowuję model na urządzeniu…',
  );

  @override
  void initState() {
    super.initState();
    _fallbackBrain.pendingWord = null;
    _fallbackBrain.lastTopic = null;
    _fallbackBrain.usedTopics.clear();
    _boot();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      _busy = true;
      _preparing = true;
      _prepareProgress = null;
      _status =
          'Przygotowuję lokalny model… To może być jednorazowa kopia z paczki.';
    });
    final system = buildTutorSystemPrompt(
      lang: widget.lang,
      words: widget.pack.words,
    );
    final session = await discoverLocalLlm(
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _status = p.message;
          _prepareProgress = p.progress;
          _preparing = p.phase != 'ready' && p.phase != 'error';
        });
      },
    );
    final opening = await localLlmReply(
          session: session,
          history: const [],
          systemPrompt: system,
          lang: widget.lang,
          words: widget.pack.words,
          userTurns: 0,
        ) ??
        fallbackTutorReply(
          lang: widget.lang,
          words: widget.pack.words,
          history: const [],
          userTurns: 0,
        );
    setState(() {
      _session = session;
      _status = session.label;
      _preparing = false;
      _prepareProgress = null;
      _messages.add(ChatMessage(role: 'assistant', text: opening));
      _busy = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _maybeReward() async {
    if (_userTurns < 3) return;
    final gained = widget.store.stats.completeDailyChat();
    if (gained > 0) {
      await widget.store.save();
      widget.onXpChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dzienna rozmowa ukończona! +$gained XP')),
      );
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _userTurns++;
      _busy = true;
    });
    _scrollToEnd();

    final system = buildTutorSystemPrompt(
      lang: widget.lang,
      words: widget.pack.words,
    );
    var reply = await localLlmReply(
      session: _session,
      history: _messages,
      systemPrompt: system,
      lang: widget.lang,
      words: widget.pack.words,
      userTurns: _userTurns,
    );
    if (reply == null && (_session.kind == 'ollama' || _session.kind == 'gguf')) {
      // Silnik padł — spróbuj ponownie (np. GGUF po Ollamie).
      final again = await discoverLocalLlm();
      _session = again;
      _status = again.label;
      reply = await localLlmReply(
        session: again,
        history: _messages,
        systemPrompt: system,
        lang: widget.lang,
        words: widget.pack.words,
        userTurns: _userTurns,
      );
    }
    reply ??= fallbackTutorReply(
      lang: widget.lang,
      words: widget.pack.words,
      history: _messages,
      userTurns: _userTurns,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(role: 'assistant', text: reply!));
      _busy = false;
    });
    _scrollToEnd();
    await _maybeReward();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.store.stats.chatDoneToday;
    return Scaffold(
      appBar: AppBar(
        title: Text('AI na urządzeniu · ${widget.lang}'),
        actions: [
          if (done)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: Text('✓ dziś')),
            ),
        ],
      ),
      body: GradientScaffoldBody(
        palette: widget.palette,
        child: Column(
          children: [
            if (_status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    Text(
                      _status!,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    if (_preparing) ...[
                      const SizedBox(height: 10),
                      if (_prepareProgress != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _prepareProgress,
                            minHeight: 8,
                          ),
                        )
                      else
                        const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          child: LinearProgressIndicator(minHeight: 8),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Jednorazowe przygotowanie modelu z paczki aplikacji. '
                        'Przy kolejnym wejściu będzie szybciej.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.65),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Text(
                done
                    ? 'Dzienna rozmowa zaliczona. Możesz dalej ćwiczyć.'
                    : 'Napisz 3 wiadomości, żeby dostać bonus XP za dziś.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _messages.length + (_busy ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final m = _messages[i];
                  final mine = m.role == 'user';
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.82,
                      ),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(m.text, style: const TextStyle(fontSize: 16)),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SoftPanel(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Napisz w języku obcym lub po polsku…',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy ? null : _send,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Icon(Icons.send_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
