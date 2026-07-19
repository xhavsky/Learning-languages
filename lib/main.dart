import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrenerApp());
}

class TrenerApp extends StatefulWidget {
  const TrenerApp({super.key});

  @override
  State<TrenerApp> createState() => _TrenerAppState();
}

class _TrenerAppState extends State<TrenerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('themeMode') ?? 'system';
    setState(() {
      _themeMode = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeMode',
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: Typography.material2021(platform: TargetPlatform.linux)
          .black
          .apply(
            fontSizeFactor: 1.15,
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          )
          .copyWith(
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            titleLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            bodyLarge: TextStyle(fontSize: 18, color: scheme.onSurface),
            bodyMedium: TextStyle(fontSize: 16, color: scheme.onSurface),
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trener Językowy',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomePage(
        themeMode: _themeMode,
        onThemeModeChanged: _setTheme,
      ),
    );
  }
}

class Word {
  Word({required this.pl, required this.obcy, required this.nauczone});

  final String pl;
  final String obcy;
  bool nauczone;

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        pl: json['pl'] as String? ?? '',
        obcy: json['obcy'] as String? ?? '',
        nauczone: json['nauczone'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'pl': pl,
        'obcy': obcy,
        'nauczone': nauczone,
      };
}

/// Cyrillic keyboard layout (Anielka — abc+pisanie.py).
const _cyrillicRows = [
  ['й', 'ц', 'у', 'к', 'е', 'н', 'г', 'ш', 'щ', 'з', 'х', 'ъ'],
  ['ф', 'ы', 'в', 'а', 'п', 'р', 'о', 'л', 'д', 'ж', 'э'],
  ['я', 'ч', 'с', 'м', 'и', 'т', 'ь', 'б', 'ю', 'ё'],
];

enum GameMethod { abc, typing }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _answerCtrl = TextEditingController();
  final _answerFocus = FocusNode();
  final _rng = Random();
  AudioPlayer? _player;

  Map<String, List<Word>> _baza = {};
  Map<String, dynamic> _manifest = {};
  String? _jezyk;
  bool _trybNauczone = false;
  GameMethod _method = GameMethod.typing;
  Word? _aktualne;
  List<String> _abcWarianty = [];
  String? _audioHint;
  bool _loading = true;
  int? _abcHighlight; // index highlighted after answer
  Color? _abcHighlightColor;

  bool get _isRussian => _jezyk == 'Rosyjski';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _answerFocus.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<AudioPlayer?> _ensurePlayer() async {
    if (_player != null) return _player;
    try {
      _player = AudioPlayer();
      return _player;
    } catch (e) {
      setState(() => _audioHint = 'Audio niedostępne (GStreamer): $e');
      return null;
    }
  }

  Future<File> _userBazaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/baza.json');
  }

  Future<void> _bootstrap() async {
    final seed = await rootBundle.loadString('assets/data/baza.json');
    final userFile = await _userBazaFile();
    var raw = seed;
    if (await userFile.exists()) {
      final existing = await userFile.readAsString();
      if (existing.trim().isNotEmpty) {
        raw = existing;
      }
    } else {
      await userFile.writeAsString(seed);
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      decoded = jsonDecode(seed) as Map<String, dynamic>;
      await userFile.writeAsString(seed);
    }

    // Merge new languages/words from seed that user file may miss.
    final seedMap = jsonDecode(seed) as Map<String, dynamic>;
    for (final e in seedMap.entries) {
      decoded.putIfAbsent(e.key, () => e.value);
      if (decoded[e.key] is List && e.value is List) {
        final existing = (decoded[e.key] as List)
            .map((w) => '${w['pl']}|${w['obcy']}')
            .toSet();
        for (final w in e.value as List) {
          final key = '${w['pl']}|${w['obcy']}';
          if (!existing.contains(key)) {
            (decoded[e.key] as List).add(w);
          }
        }
      }
    }

    final baza = <String, List<Word>>{};
    for (final e in decoded.entries) {
      baza[e.key] = (e.value as List<dynamic>)
          .map((w) => Word.fromJson(w as Map<String, dynamic>))
          .toList();
    }

    Map<String, dynamic> manifest = {};
    try {
      final m = await rootBundle.loadString('assets/audio/manifest.json');
      if (m.trim().isNotEmpty) {
        manifest = jsonDecode(m) as Map<String, dynamic>;
      }
    } catch (_) {}

    setState(() {
      _baza = baza;
      _manifest = manifest;
      _jezyk = baza.containsKey('Angielski')
          ? 'Angielski'
          : (baza.keys.isNotEmpty ? baza.keys.first : null);
      _loading = false;
    });
    _losuj();
  }

  Future<void> _zapisz() async {
    final encoded = {
      for (final e in _baza.entries)
        e.key: e.value.map((w) => w.toJson()).toList(),
    };
    final file = await _userBazaFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(encoded));
  }

  String? _audioAssetFor(String jezyk, String obcy) {
    final entries = _manifest['entries'];
    if (entries is! Map) return null;
    final entry = entries['$jezyk|$obcy'];
    if (entry is Map && entry['file'] is String) {
      return 'audio/${entry['file']}';
    }
    return null;
  }

  Future<void> _playCurrent() async {
    final w = _aktualne;
    final j = _jezyk;
    if (w == null || j == null) return;
    // ABC mode shows foreign word — play that; typing plays foreign answer.
    final text = _method == GameMethod.abc ? w.obcy : w.obcy;
    final asset = _audioAssetFor(j, text);
    if (asset == null) {
      setState(() {
        _audioHint = _isRussian
            ? 'Brak audio dla cyrylicy (generuj Piperem/Coqui później).'
            : 'Brak lokalnego audio. Uruchom: python3 scripts/generate_tts.py';
      });
      return;
    }
    setState(() => _audioHint = null);
    final player = await _ensurePlayer();
    if (player == null) return;
    try {
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (e) {
      setState(() => _audioHint = 'Nie udało się odtworzyć audio: $e');
    }
  }

  void _losuj() {
    final j = _jezyk;
    if (j == null) return;
    final words = _baza[j] ?? [];
    final pula = words.where((w) => w.nauczone == _trybNauczone).toList();
    setState(() {
      _answerCtrl.clear();
      _abcHighlight = null;
      _abcHighlightColor = null;
      if (pula.isEmpty) {
        _aktualne = null;
        _abcWarianty = [];
      } else {
        _aktualne = pula[_rng.nextInt(pula.length)];
        if (_method == GameMethod.abc) {
          _abcWarianty = _buildAbcVariants(_aktualne!, words);
        } else {
          _abcWarianty = [];
        }
      }
    });
    if (_aktualne != null && _method == GameMethod.typing && !_isRussian) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrent());
    } else if (_aktualne != null && _method == GameMethod.abc && !_isRussian) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrent());
    }
    if (_method == GameMethod.typing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _answerFocus.requestFocus();
      });
    }
  }

  List<String> _buildAbcVariants(Word correct, List<Word> all) {
    // ABC (Anielka): show foreign word, choose Polish meaning.
    final correctPl = correct.pl;
    final others = all
        .map((w) => w.pl)
        .where((pl) => pl != correctPl)
        .toSet()
        .toList()
      ..shuffle(_rng);
    final distractors = others.take(2).toList();
    while (distractors.length < 2) {
      distractors.add(['kot', 'pies', 'dom'][distractors.length]);
    }
    final variants = [correctPl, ...distractors]..shuffle(_rng);
    return variants;
  }

  Future<void> _oznacz(bool ok) async {
    final w = _aktualne;
    if (w == null) return;
    if (ok) {
      if (!w.nauczone) {
        w.nauczone = true;
        await _zapisz();
      }
    } else {
      if (w.nauczone) {
        w.nauczone = false;
        await _zapisz();
      }
    }
  }

  Future<void> _sprawdzAbc(int idx) async {
    if (_aktualne == null || _abcWarianty.isEmpty) return;
    final chosen = _abcWarianty[idx];
    final ok = chosen == _aktualne!.pl;
    setState(() {
      _abcHighlight = idx;
      _abcHighlightColor = ok ? Colors.green : Colors.red;
    });
    await _oznacz(ok);
    if (!ok) {
      final goodIdx = _abcWarianty.indexOf(_aktualne!.pl);
      if (goodIdx >= 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() {
          _abcHighlight = goodIdx;
          _abcHighlightColor = Colors.green;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) _losuj();
  }

  Future<void> _sprawdzPisanie() async {
    final w = _aktualne;
    if (w == null) return;
    final user = _answerCtrl.text.trim().toLowerCase();
    final ok = w.obcy.trim().toLowerCase();
    if (user == ok) {
      await _oznacz(true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Brawo!'),
          content: const Text('Poprawna odpowiedź!'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dalej'),
            ),
          ],
        ),
      );
      _losuj();
    } else {
      await _oznacz(false);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Błąd'),
          content: Text('Poprawna odpowiedź to:\n${w.obcy}'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _losuj();
    }
  }

  void _wstawLitere(String litera) {
    final t = _answerCtrl.text;
    final sel = _answerCtrl.selection;
    if (sel.isValid) {
      final start = sel.start;
      final end = sel.end;
      _answerCtrl.text = t.replaceRange(start, end, litera);
      _answerCtrl.selection = TextSelection.collapsed(offset: start + litera.length);
    } else {
      _answerCtrl.text = '$t$litera';
      _answerCtrl.selection =
          TextSelection.collapsed(offset: _answerCtrl.text.length);
    }
    setState(() {});
  }

  void _cofnijLitere() {
    final t = _answerCtrl.text;
    if (t.isEmpty) return;
    _answerCtrl.text = t.substring(0, t.length - 1);
    _answerCtrl.selection =
        TextSelection.collapsed(offset: _answerCtrl.text.length);
    setState(() {});
  }

  Future<void> _dodajSlowo() async {
    final plCtrl = TextEditingController();
    final obcyCtrl = TextEditingController();
    var jezyk = _jezyk ?? _baza.keys.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Dodaj nowe słowo'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: jezyk,
                      items: _baza.keys
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => jezyk = v ?? jezyk),
                      decoration: const InputDecoration(labelText: 'Język'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Słowo po polsku'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: obcyCtrl,
                      decoration: InputDecoration(
                        labelText: jezyk == 'Rosyjski'
                            ? 'Tłumaczenie (cyrylica)'
                            : 'Tłumaczenie',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    final pl = plCtrl.text.trim();
    final obcy = obcyCtrl.text.trim();
    if (pl.isEmpty || obcy.isEmpty) return;
    setState(() {
      _baza.putIfAbsent(jezyk, () => []);
      _baza[jezyk]!.add(Word(pl: pl, obcy: obcy, nauczone: false));
    });
    await _zapisz();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Zapisano. Audio: uruchom scripts/generate_tts.py i przebuduj.',
        ),
      ),
    );
  }

  Widget _cyrillicKeyboard() {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'Klawiatura rosyjska (Cyrylica)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final row in _cyrillicRows)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final l in row)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 40),
                          ),
                          onPressed: () => _wstawLitere(l),
                          child: Text(l, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => _wstawLitere(' '),
                  child: const Text('Spacja'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _cofnijLitere,
                  child: const Text('Cofnij ←'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final j = _jezyk;
    final words = j == null ? <Word>[] : (_baza[j] ?? []);
    final doNauki = words.where((w) => !w.nauczone).length;
    final nauczone = words.where((w) => w.nauczone).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trener Językowy'),
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'Motyw',
            initialValue: widget.themeMode,
            onSelected: widget.onThemeModeChanged,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('System')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Jasny')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Ciemny')),
            ],
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : widget.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_auto,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Wybierz język', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _jezyk,
                items: _baza.keys
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _jezyk = v;
                    // Russian defaults to ABC like Anielka's app
                    if (v == 'Rosyjski') _method = GameMethod.abc;
                  });
                  _losuj();
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _dodajSlowo,
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj słowo'),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() {
                        _method = _method == GameMethod.abc
                            ? GameMethod.typing
                            : GameMethod.abc;
                      });
                      _losuj();
                    },
                    child: Text(
                      _method == GameMethod.abc
                          ? 'Metoda: Wybór ABC'
                          : 'Metoda: Wpisywanie',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() => _trybNauczone = !_trybNauczone);
                      _losuj();
                    },
                    child: Text(
                      _trybNauczone ? 'Pula: Powtórka' : 'Pula: Nauka',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Do nauki: $doNauki  |  Opanowane: $nauczone',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (_aktualne == null)
                Text(
                  _trybNauczone
                      ? 'Brak słówek w puli nauczonych.\nRozwiązuj testy w trybie nauki!'
                      : 'Gratulacje! Znasz już wszystkie słowa.\nPrzełącz na powtórki.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                )
              else ...[
                Text(
                  _method == GameMethod.abc
                      ? 'Jak po polsku znaczy słowo:'
                      : 'Przetłumacz na język obcy:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _method == GameMethod.abc
                      ? _aktualne!.obcy
                      : '"${_aktualne!.pl}"?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: _method == GameMethod.abc
                            ? const Color(0xFF1565C0)
                            : const Color(0xFF2E7D32),
                      ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: IconButton.filledTonal(
                    onPressed: _playCurrent,
                    iconSize: 36,
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Powtórz wymowę',
                  ),
                ),
                if (_audioHint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _audioHint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_method == GameMethod.abc)
                  ...List.generate(_abcWarianty.length, (i) {
                    final selected = _abcHighlight == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: selected ? _abcHighlightColor : null,
                            foregroundColor:
                                selected ? Colors.white : null,
                            minimumSize: const Size.fromHeight(56),
                          ),
                          onPressed: () => _sprawdzAbc(i),
                          child: Text(
                            _abcWarianty[i],
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    );
                  })
                else ...[
                  TextField(
                    controller: _answerCtrl,
                    focusNode: _answerFocus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                    decoration: const InputDecoration(
                      hintText: 'Wpisz tłumaczenie',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sprawdzPisanie(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _sprawdzPisanie,
                    child: const Text('Sprawdź (Enter)'),
                  ),
                  if (_isRussian) _cyrillicKeyboard(),
                ],
              ],
              const SizedBox(height: 24),
              Text(
                'Offline audio (Piper). Skrypty Anielki: legacy/',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
