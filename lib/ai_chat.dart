import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'ui_fx.dart';

class ChatMessage {
  ChatMessage({required this.role, required this.text});

  final String role; // user | assistant | system
  final String text;
}

/// Prosty klient lokalnej Ollamy (tylko 127.0.0.1 — bez chmury).
Future<String?> ollamaReply({
  required List<ChatMessage> history,
  required String systemPrompt,
  String model = 'bielik-latest:latest',
}) async {
  final client = HttpClient();
  try {
    // Wyłącznie localhost — rozmowa AI nie wychodzi w internet.
    final uri = Uri.parse('http://127.0.0.1:11434/api/chat');
    final req = await client.postUrl(uri).timeout(const Duration(seconds: 3));
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
          'options': {'temperature': 0.7, 'num_predict': 180},
        }),
      ),
    );
    final res = await req.close().timeout(const Duration(seconds: 90));
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

String buildTutorSystemPrompt({
  required String lang,
  required List<Word> words,
}) {
  final sample = (List<Word>.of(words)..shuffle(Random()))
      .take(24)
      .map((w) => '${w.pl} = ${w.obcy}')
      .join('; ');
  return '''
Jesteś miłą nauczycielką języków dla nastolatki Anielki w aplikacji „Trener Językowy”.
Język nauki: $lang.
Prowadź krótką codzienną rozmowę (1–3 zdania na odpowiedź).
Mów głównie w języku obcym ($lang), ale możesz dodać krótką polską podpowiedź w nawiasie.
Używaj prostych słów. Zachęcaj, poprawiaj delikatnie błędy.
Wplataj słówka z jej bazy, np.: $sample
Nie pisz długich list ani kodu. Nie wspominaj, że jesteś modelem AI — jesteś trenerką.
''';
}

String fallbackTutorReply({
  required String lang,
  required List<Word> words,
  required List<ChatMessage> history,
  required int userTurns,
}) {
  final rng = Random();
  final pool = words.isEmpty
      ? [Word(id: 'x', pl: 'Cześć', obcy: 'Hello')]
      : words;
  final w = pool[rng.nextInt(pool.length)];

  if (userTurns <= 1) {
    return switch (lang) {
      'Hiszpański' =>
        '¡Hola! 😊 Dziś porozmawiajmy po hiszpańsku. Jak powiedzieć „${w.pl}”? (podpowiedź: ${w.obcy})',
      'Rosyjski' =>
        'Привет! 😊 Сегодня поговорим по-русски. Как сказать „${w.pl}”? (подсказка: ${w.obcy})',
      _ =>
        'Hi! 😊 Today let\'s chat in English. How do you say „${w.pl}”? (hint: ${w.obcy})',
    };
  }

  final lastUser = history.reversed
      .where((m) => m.role == 'user')
      .map((m) => m.text)
      .firstOrNull;
  final okish = lastUser != null &&
      (lastUser.toLowerCase().contains(w.obcy.toLowerCase()) ||
          lastUser.trim().length >= 2);

  if (okish) {
    final next = pool[rng.nextInt(pool.length)];
    return switch (lang) {
      'Hiszpański' =>
        '¡Muy bien! 🌟 A teraz: użyj słowa „${next.obcy}" (${next.pl}) w krótkim zdaniu.',
      'Rosyjski' =>
        'Молодец! 🌟 Теперь используй слово „${next.obcy}" (${next.pl}) в коротком предложении.',
      _ =>
        'Great job! 🌟 Now use the word „${next.obcy}" (${next.pl}) in a short sentence.',
    };
  }

  return switch (lang) {
    'Hiszpański' =>
      'Casi — spróbuj jeszcze raz. Możesz napisać: ${w.obcy}. ¿Cómo estás hoy?',
    'Rosyjski' =>
      'Почти — spróbuj jeszcze raz. Możesz napisać: ${w.obcy}. Как дела сегодня?',
    _ =>
      'Almost — try again. You can write: ${w.obcy}. How are you today?',
  };
}

/// Ekran codziennej rozmowy z AI (Ollama) + tryb offline.
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
  var _usingOllama = false;
  var _userTurns = 0;
  String? _status;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() => _busy = true);
    final system = buildTutorSystemPrompt(
      lang: widget.lang,
      words: widget.pack.words,
    );
    final probe = await ollamaReply(
      history: const [],
      systemPrompt: system,
    );
    String opening;
    if (probe != null) {
      _usingOllama = true;
      opening = probe;
      _status = 'AI lokalne: Ollama na tym komputerze (bez internetu)';
    } else {
      _usingOllama = false;
      opening = fallbackTutorReply(
        lang: widget.lang,
        words: widget.pack.words,
        history: const [],
        userTurns: 0,
      );
      _status =
          'Tryb offline (brak lokalnej Ollamy) — ćwiczenie bez chmury';
    }
    setState(() {
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
    String? reply;
    if (_usingOllama) {
      reply = await ollamaReply(history: _messages, systemPrompt: system);
      if (reply == null) {
        _usingOllama = false;
        _status = 'Ollama lokalna niedostępna — tryb offline (bez chmury)';
      }
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
        title: Text('AI lokalne · ${widget.lang}'),
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
                child: Text(
                  _status!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Napisz po obcemu lub po polsku…',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _send,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
