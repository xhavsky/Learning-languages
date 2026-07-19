import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'portal.dart';
import 'storage.dart';
import 'theme.dart';
import 'ui_fx.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrenerApp());
}

enum GameMethod { abc, typing }

enum TranslateDir { plToForeign, foreignToPl, mixed }

const _cyrillicRows = [
  ['й', 'ц', 'у', 'к', 'е', 'н', 'г', 'ш', 'щ', 'з', 'х', 'ъ'],
  ['ф', 'ы', 'в', 'а', 'п', 'р', 'о', 'л', 'д', 'ж', 'э'],
  ['я', 'ч', 'с', 'м', 'и', 'т', 'ь', 'б', 'ю', 'ё'],
];

const _spanishExtras = ['á', 'é', 'í', 'ó', 'ú', 'ñ', 'ü', '¿', '¡'];

class TrenerApp extends StatefulWidget {
  const TrenerApp({super.key});

  @override
  State<TrenerApp> createState() => _TrenerAppState();
}

class _TrenerAppState extends State<TrenerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  AppPalette _palette = AppPalette.forest;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = switch (prefs.getString('themeMode') ?? 'system') {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _palette = AppPaletteX.fromName(prefs.getString('palette'));
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
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

  Future<void> _setPalette(AppPalette p) async {
    setState(() => _palette = p);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('palette', p.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trener Językowy',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: buildAppTheme(brightness: Brightness.light, palette: _palette),
      darkTheme: buildAppTheme(brightness: Brightness.dark, palette: _palette),
      home: HomePage(
        themeMode: _themeMode,
        palette: _palette,
        onThemeModeChanged: _setThemeMode,
        onPaletteChanged: _setPalette,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.themeMode,
    required this.palette,
    required this.onThemeModeChanged,
    required this.onPaletteChanged,
  });

  final ThemeMode themeMode;
  final AppPalette palette;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPalette> onPaletteChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _store = BazaStore();
  final _answerCtrl = TextEditingController();
  final _answerFocus = FocusNode();
  final _rng = Random();
  final _importCtrl = TextEditingController();
  AudioPlayer? _player;

  late final AnimationController _shakeCtrl;
  late final AnimationController _successCtrl;
  late final AnimationController _burstCtrl;

  bool _loading = true;
  String? _lang;
  String _groupId = '__all__';
  GameMethod _method = GameMethod.typing;
  TranslateDir _dir = TranslateDir.plToForeign;
  bool _poolReview = false; // false=due/new, true=review mastered
  bool _hintShown = false;
  double _playbackRate = 1.0;

  Word? _current;
  bool _askForeign = false; // true = show foreign, expect PL
  List<String> _abc = [];
  int? _abcHi;
  Color? _abcHiColor;

  String? _banner; // inline feedback (no AlertDialog)
  FeedbackKind _bannerKind = FeedbackKind.info;
  bool _bannerVisible = false;
  String? _audioHint;
  PortalInfo _portal = PortalInfo.fallback;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _boot();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _successCtrl.dispose();
    _burstCtrl.dispose();
    _answerCtrl.dispose();
    _answerFocus.dispose();
    _importCtrl.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final portal = await PortalInfo.load();
    await _store.load();
    final lang = _store.baza.containsKey('Angielski')
        ? 'Angielski'
        : (_store.baza.keys.isNotEmpty ? _store.baza.keys.first : null);
    setState(() {
      _portal = portal;
      _lang = lang;
      _loading = false;
    });
    await _loadMethodForLang(lang);
    _draw();
  }

  LangPack? get _pack =>
      _lang == null ? null : _store.baza[_lang!];

  void _flash(
    String msg, {
    FeedbackKind kind = FeedbackKind.info,
    int ms = 1600,
  }) {
    setState(() {
      _banner = msg;
      _bannerKind = kind;
      _bannerVisible = true;
    });
    Future<void>.delayed(Duration(milliseconds: ms), () {
      if (!mounted) return;
      if (_banner == msg) {
        setState(() => _bannerVisible = false);
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (!mounted) return;
          if (_banner == msg) setState(() => _banner = null);
        });
      }
    });
  }

  Future<AudioPlayer?> _playerOrNull() async {
    if (_player != null) return _player;
    try {
      _player = AudioPlayer();
      return _player;
    } catch (e) {
      setState(() => _audioHint = 'Audio niedostępne: $e');
      return null;
    }
  }

  Future<void> _playText(String text) async {
    final lang = _lang;
    if (lang == null) return;
    final asset = _store.audioAsset(lang, text);
    if (asset == null) {
      setState(() {
        _audioHint =
            'Brak audio. Na PC: python3 scripts/generate_tts.py';
      });
      return;
    }
    setState(() => _audioHint = null);
    final p = await _playerOrNull();
    if (p == null) return;
    try {
      await p.stop();
      await p.setPlaybackRate(_playbackRate);
      await p.play(AssetSource(asset));
    } catch (e) {
      setState(() => _audioHint = 'Odtwarzanie: $e');
    }
  }

  Future<void> _loadMethodForLang(String? lang) async {
    if (lang == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('method_$lang');
    final rate = prefs.getDouble('playbackRate') ?? 1.0;
    setState(() {
      _playbackRate = rate;
      if (raw == 'abc') {
        _method = GameMethod.abc;
      } else if (raw == 'typing') {
        _method = GameMethod.typing;
      } else if (lang == 'Rosyjski') {
        _method = GameMethod.abc;
      }
    });
  }

  Future<void> _persistMethod() async {
    final lang = _lang;
    if (lang == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'method_$lang',
      _method == GameMethod.abc ? 'abc' : 'typing',
    );
  }

  Future<void> _persistRate(double rate) async {
    setState(() => _playbackRate = rate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('playbackRate', rate);
  }

  List<Word> _sessionPool() {
    final pack = _pack;
    if (pack == null) return [];
    var words = pack.wordsForGroup(_groupId);
    final now = DateTime.now();
    if (_poolReview) {
      words = words.where((w) => w.level >= 3).toList();
    } else {
      words = words.where((w) {
        if (w.level >= 3) {
          return w.nextDue == null || !w.nextDue!.isAfter(now);
        }
        return true;
      }).toList();
      if (words.isEmpty) {
        // fallback: any non-mastered in group
        words = pack.wordsForGroup(_groupId).where((w) => w.level < 3).toList();
      }
    }
    return words;
  }

  void _draw() {
    final pool = _sessionPool();
    setState(() {
      _answerCtrl.clear();
      _hintShown = false;
      _abcHi = null;
      _abcHiColor = null;
      if (pool.isEmpty) {
        _current = null;
        _abc = [];
        return;
      }
      _current = pool[_rng.nextInt(pool.length)];
      _askForeign = switch (_dir) {
        TranslateDir.plToForeign => false,
        TranslateDir.foreignToPl => true,
        TranslateDir.mixed => _rng.nextBool(),
      };
      if (_method == GameMethod.abc) {
        // ABC always: show foreign → pick Polish (Anielka)
        _askForeign = true;
        _abc = _buildAbc(_current!);
      } else {
        _abc = [];
      }
    });
    if (_current != null) {
      final play = _askForeign ? _current!.obcy : _current!.obcy;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playText(play);
        if (_method == GameMethod.typing) {
          _answerFocus.requestFocus();
        }
      });
    }
  }

  List<String> _buildAbc(Word correct) {
    final pack = _pack!;
    final others = pack.words
        .map((w) => w.pl)
        .where((pl) => pl != correct.pl)
        .toSet()
        .toList()
      ..shuffle(_rng);
    final distractors = others.take(2).toList();
    while (distractors.length < 2) {
      distractors.add(['kot', 'pies', 'dom'][distractors.length]);
    }
    return [correct.pl, ...distractors]..shuffle(_rng);
  }

  String get _promptLabel {
    if (_method == GameMethod.abc || _askForeign) {
      return 'Jak po polsku znaczy:';
    }
    return 'Przetłumacz na język obcy:';
  }

  String get _promptWord {
    if (_current == null) return '';
    if (_method == GameMethod.abc || _askForeign) return _current!.obcy;
    return _current!.pl;
  }

  String get _expected {
    if (_current == null) return '';
    if (_method == GameMethod.abc || _askForeign) return _current!.pl;
    return _current!.obcy;
  }

  Future<void> _onResult(bool ok) async {
    final w = _current;
    if (w == null) return;
    applySrs(w, correct: ok);
    _store.stats.recordAnswer(ok);
    await _store.save();
    if (ok) {
      _flash('Brawo! ✓', kind: FeedbackKind.success);
      _successCtrl.forward(from: 0);
      _burstCtrl.forward(from: 0);
      await _playText(w.obcy);
      await Future<void>.delayed(const Duration(milliseconds: 850));
    } else {
      _flash('Poprawnie: $_expected', kind: FeedbackKind.fail, ms: 2000);
      await _shakeCtrl.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    if (mounted) _draw();
  }

  Future<void> _checkTyping() async {
    if (_current == null) return;
    final user = _answerCtrl.text.trim().toLowerCase();
    final ok = user == _expected.trim().toLowerCase();
    await _onResult(ok);
  }

  Future<void> _checkAbc(int i) async {
    if (_current == null || _abc.isEmpty) return;
    final ok = _abc[i] == _expected;
    setState(() {
      _abcHi = i;
      _abcHiColor = ok ? Colors.green : Colors.red;
    });
    if (!ok) {
      final good = _abc.indexOf(_expected);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted && good >= 0) {
        setState(() {
          _abcHi = good;
          _abcHiColor = Colors.green;
        });
      }
    }
    await _onResult(ok);
  }

  void _showHint() {
    if (_current == null) return;
    final exp = _expected;
    setState(() {
      _hintShown = true;
      if (exp.isEmpty) return;
      _flash(
        'Podpowiedź: ${exp[0]}… (${exp.length} liter)',
        kind: FeedbackKind.hint,
        ms: 2500,
      );
    });
  }

  void _insert(String ch) {
    final t = _answerCtrl.text;
    final sel = _answerCtrl.selection;
    if (sel.isValid) {
      final s = sel.start;
      final e = sel.end;
      _answerCtrl.text = t.replaceRange(s, e, ch);
      _answerCtrl.selection = TextSelection.collapsed(offset: s + ch.length);
    } else {
      _answerCtrl.text = '$t$ch';
      _answerCtrl.selection =
          TextSelection.collapsed(offset: _answerCtrl.text.length);
    }
    setState(() {});
  }

  void _backspace() {
    final t = _answerCtrl.text;
    if (t.isEmpty) return;
    _answerCtrl.text = t.substring(0, t.length - 1);
    _answerCtrl.selection =
        TextSelection.collapsed(offset: _answerCtrl.text.length);
    setState(() {});
  }

  Future<void> _openGroups() async {
    final pack = _pack;
    if (pack == null || _lang == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupsPage(
          lang: _lang!,
          pack: pack,
          selectedId: _groupId,
          palette: widget.palette,
          onChanged: () async {
            await _store.save();
            setState(() {});
          },
          onSelect: (id) {
            setState(() => _groupId = id);
            _draw();
          },
        ),
      ),
    );
    setState(() {});
    _draw();
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ustawienia', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Motyw jasny/ciemny', style: Theme.of(ctx).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('System'),
                      selected: widget.themeMode == ThemeMode.system,
                      onSelected: (_) =>
                          widget.onThemeModeChanged(ThemeMode.system),
                    ),
                    ChoiceChip(
                      label: const Text('Jasny'),
                      selected: widget.themeMode == ThemeMode.light,
                      onSelected: (_) =>
                          widget.onThemeModeChanged(ThemeMode.light),
                    ),
                    ChoiceChip(
                      label: const Text('Ciemny'),
                      selected: widget.themeMode == ThemeMode.dark,
                      onSelected: (_) =>
                          widget.onThemeModeChanged(ThemeMode.dark),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Kolorystyka', style: Theme.of(ctx).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in AppPalette.values)
                      FilterChip(
                        avatar: CircleAvatar(backgroundColor: p.seed),
                        label: Text(p.label),
                        selected: widget.palette == p,
                        onSelected: (_) => widget.onPaletteChanged(p),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Kierunek', style: Theme.of(ctx).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('PL → obcy'),
                      selected: _dir == TranslateDir.plToForeign,
                      onSelected: (_) {
                        setState(() => _dir = TranslateDir.plToForeign);
                        _draw();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('obcy → PL'),
                      selected: _dir == TranslateDir.foreignToPl,
                      onSelected: (_) {
                        setState(() => _dir = TranslateDir.foreignToPl);
                        _draw();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Mieszany'),
                      selected: _dir == TranslateDir.mixed,
                      onSelected: (_) {
                        setState(() => _dir = TranslateDir.mixed);
                        _draw();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Tempo audio', style: Theme.of(ctx).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in [0.75, 1.0, 1.25])
                      ChoiceChip(
                        label: Text('${r}x'),
                        selected: (_playbackRate - r).abs() < 0.01,
                        onSelected: (_) => _persistRate(r),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () async {
                    final path = await _store.exportToDocuments();
                    if (ctx.mounted) Navigator.pop(ctx);
                    _flash('Wyeksportowano:\n$path', kind: FeedbackKind.info, ms: 4000);
                  },
                  child: const Text('Eksportuj bazę (JSON)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _importCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ścieżka do importu JSON',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final err = await _store.importFromPath(_importCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (err != null) {
                      _flash(err, kind: FeedbackKind.fail, ms: 3000);
                    } else {
                      setState(() {});
                      _draw();
                      _flash('Zaimportowano bazę', kind: FeedbackKind.success);
                    }
                  },
                  child: const Text('Importuj z pliku'),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (_) {
                    final miss = _store.missingAudioKeys();
                    return Text(
                      miss.isEmpty
                          ? 'Audio: komplet w manifeście'
                          : 'Brak audio: ${miss.length} haseł\n(PC: python3 scripts/generate_tts.py)',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Dla Anielki', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showAnielkaPortalSheet(context, portal: _portal);
                  },
                  child: const Text('Portal WWW (adres + PIN)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showGithubPublishSheet(context, portal: _portal);
                  },
                  child: const Text('Opublikuj na moje GitHub'),
                ),
                const SizedBox(height: 6),
                Text(
                  _portal.url,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addWord() async {
    final plCtrl = TextEditingController();
    final obcyCtrl = TextEditingController();
    var lang = _lang ?? _store.baza.keys.first;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Dodaj słowo', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: lang,
                    items: _store.baza.keys
                        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (v) => setLocal(() => lang = v ?? lang),
                    decoration: const InputDecoration(labelText: 'Język'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: plCtrl,
                    decoration: const InputDecoration(labelText: 'Po polsku'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: obcyCtrl,
                    decoration: const InputDecoration(labelText: 'Tłumaczenie'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Zapisz'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true) return;
    final pl = plCtrl.text.trim();
    final obcy = obcyCtrl.text.trim();
    if (pl.isEmpty || obcy.isEmpty) {
      _flash('Wypełnij oba pola', kind: FeedbackKind.hint);
      return;
    }
    final pack = _store.baza.putIfAbsent(
      lang,
      () => LangPack(words: [], groups: []),
    );
    pack.words.add(Word(
      id: Word.fromJson({'pl': pl, 'obcy': obcy}).id,
      pl: pl,
      obcy: obcy,
    ));
    await _store.save();
    setState(() {});
    _flash('Dodano: $pl → $obcy', kind: FeedbackKind.success);
  }

  Widget _keyboard() {
    if (_lang == 'Rosyjski') {
      return _keyCard(
        'Klawiatura rosyjska',
        [
          for (final row in _cyrillicRows) row,
        ],
      );
    }
    if (_lang == 'Hiszpański') {
      return _keyCard('Znaki hiszpańskie', [_spanishExtras]);
    }
    return const SizedBox.shrink();
  }

  Widget _keyCard(String title, List<List<String>> rows) {
    return SoftPanel(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final l in row)
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(42, 42),
                        ),
                        onPressed: () => _insert(l),
                        child: Text(l, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _insert(' '),
                child: const Text('Spacja'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _backspace,
                child: const Text('Cofnij ←'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _groupLabel() {
    final pack = _pack;
    if (pack == null) return 'Cała baza';
    return switch (_groupId) {
      '__all__' => 'Cała baza',
      '__unlearned__' => 'Nieopanowane',
      '__hard__' => 'Trudne',
      _ => pack.groups
              .where((g) => g.id == _groupId)
              .map((g) => g.name)
              .firstOrNull ??
          'Zestaw',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: GradientScaffoldBody(
          palette: widget.palette,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final pack = _pack;
    final pool = _sessionPool();
    final allInGroup = pack?.wordsForGroup(_groupId) ?? [];
    final mastered = allInGroup.where((w) => w.level >= 3).length;
    final pct =
        allInGroup.isEmpty ? 0 : (100 * mastered / allInGroup.length).round();

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Trener Językowy'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                'v0.0.3',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Zestawy',
            onPressed: _openGroups,
            icon: const Icon(Icons.folder_special_outlined),
          ),
          IconButton(
            tooltip: 'Ustawienia',
            onPressed: _openSettings,
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: GradientScaffoldBody(
        palette: widget.palette,
        child: Stack(
          children: [
            SuccessBurst(animation: _burstCtrl),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    SoftPanel(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Image.asset(
                                  'assets/images/kitten_book.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Trener Językowy',
                            style: Theme.of(context).textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Ucz się słówek z uroczym kotkiem 📚',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    SoftPanel(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '💌 Portal Anielki (tymczasowy)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _portal.url,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'PIN: ${_portal.pin} · publiczny link (bez Tailscale)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () => showAnielkaPortalSheet(
                                  context,
                                  portal: _portal,
                                ),
                                child: const Text('Jak wejść?'),
                              ),
                              OutlinedButton(
                                onPressed: () => showGithubPublishSheet(
                                  context,
                                  portal: _portal,
                                ),
                                child: const Text('GitHub'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_banner != null)
                      AnimatedFeedbackBanner(
                        message: _banner!,
                        kind: _bannerKind,
                        visible: _bannerVisible,
                        onDismiss: () => setState(() {
                          _bannerVisible = false;
                          _banner = null;
                        }),
                      ),
                    SoftPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _lang,
                            items: _store.baza.keys
                                .map(
                                  (k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(k),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) async {
                              setState(() {
                                _lang = v;
                                _groupId = '__all__';
                              });
                              await _loadMethodForLang(v);
                              _draw();
                            },
                            decoration:
                                const InputDecoration(labelText: 'Język'),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Zestaw: ${_groupLabel()} · $mastered/${allInGroup.length} ($pct%)',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            'Sesja: ${_store.stats.sessionCorrect}/${_store.stats.sessionTotal}'
                            ' · streak ${_store.stats.streakDays} dni',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _addWord,
                          icon: const Icon(Icons.add),
                          label: const Text('Słowo'),
                        ),
                        FilledButton.tonal(
                          onPressed: () async {
                            setState(() {
                              _method = _method == GameMethod.abc
                                  ? GameMethod.typing
                                  : GameMethod.abc;
                            });
                            await _persistMethod();
                            _draw();
                          },
                          child: Text(
                            _method == GameMethod.abc
                                ? 'Metoda: ABC'
                                : 'Metoda: Pisanie',
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            setState(() => _poolReview = !_poolReview);
                            _draw();
                          },
                          child: Text(
                            _poolReview ? 'Pula: Powtórka' : 'Pula: Nauka',
                          ),
                        ),
                        if (_current != null)
                          OutlinedButton(
                            onPressed: () async {
                              _current!.hard = !_current!.hard;
                              await _store.save();
                              _flash(
                                _current!.hard
                                    ? 'Oznaczone jako trudne'
                                    : 'Trudne wyłączone',
                                kind: FeedbackKind.info,
                              );
                              setState(() {});
                            },
                            child:
                                Text(_current!.hard ? '★ Trudne' : 'Trudne?'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_current == null)
                      SoftPanel(
                        child: Text(
                          pool.isEmpty && _poolReview
                              ? 'Brak opanowanych w tym zestawie.'
                              : 'Brak słówek do nauki w zestawie.\nDodaj słowa lub wybierz inny zestaw.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      )
                    else
                      Shake(
                        animation: _shakeCtrl,
                        child: SuccessPulse(
                          animation: _successCtrl,
                          child: SoftPanel(
                            child: Column(
                              children: [
                                Text(
                                  _promptLabel,
                                  textAlign: TextAlign.center,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                AnimatedPromptWord(
                                  text: _promptWord,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton.filledTonal(
                                      onPressed: () =>
                                          _playText(_current!.obcy),
                                      iconSize: 32,
                                      icon: const Icon(Icons.volume_up),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed:
                                          _hintShown ? null : _showHint,
                                      child: const Text('Podpowiedź'),
                                    ),
                                  ],
                                ),
                                if (_audioHint != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _audioHint!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                if (_method == GameMethod.abc)
                                  ...List.generate(_abc.length, (i) {
                                    final sel = _abcHi == i;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 60,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          child: FilledButton.tonal(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  sel ? _abcHiColor : null,
                                              foregroundColor: sel
                                                  ? Colors.white
                                                  : null,
                                              elevation: sel ? 4 : 1,
                                            ),
                                            onPressed: () => _checkAbc(i),
                                            child: Text(
                                              _abc[i],
                                              style: const TextStyle(
                                                fontSize: 20,
                                              ),
                                            ),
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
                                      hintText: 'Twoja odpowiedź',
                                    ),
                                    onSubmitted: (_) => _checkTyping(),
                                  ),
                                  const SizedBox(height: 12),
                                  GradientButton(
                                    onPressed: _checkTyping,
                                    label: 'Sprawdź',
                                    palette: widget.palette,
                                  ),
                                  _keyboard(),
                                ],
                              ],
                            ),
                          ),
                        ),
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

class GroupsPage extends StatefulWidget {
  const GroupsPage({
    super.key,
    required this.lang,
    required this.pack,
    required this.selectedId,
    required this.palette,
    required this.onChanged,
    required this.onSelect,
  });

  final String lang;
  final LangPack pack;
  final String selectedId;
  final AppPalette palette;
  final VoidCallback onChanged;
  final ValueChanged<String> onSelect;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
  }

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();
    final selected = <String>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.85,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Nowy zestaw', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nazwa zestawu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wybierz słowa (bez duplikowania — tylko zaznaczenie):',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.pack.words.length,
                        itemBuilder: (_, i) {
                          final w = widget.pack.words[i];
                          final on = selected.contains(w.id);
                          return CheckboxListTile(
                            value: on,
                            title: Text('${w.pl} → ${w.obcy}'),
                            subtitle: Text('poziom ${w.level}${w.hard ? " · trudne" : ""}'),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  selected.add(w.id);
                                } else {
                                  selected.remove(w.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Utwórz'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty || selected.isEmpty) return;
    widget.pack.groups.add(
      WordGroup(
        id: 'g-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        wordIds: selected.toList(),
      ),
    );
    widget.onChanged();
    setState(() {});
  }

  Future<void> _editGroup(WordGroup g) async {
    final selected = g.wordIds.toSet();
    final nameCtrl = TextEditingController(text: g.name);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.85,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Edytuj zestaw', style: Theme.of(ctx).textTheme.titleLarge),
                    TextField(controller: nameCtrl),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.pack.words.length,
                        itemBuilder: (_, i) {
                          final w = widget.pack.words[i];
                          return CheckboxListTile(
                            value: selected.contains(w.id),
                            title: Text('${w.pl} → ${w.obcy}'),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  selected.add(w.id);
                                } else {
                                  selected.remove(w.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              widget.pack.groups.removeWhere((x) => x.id == g.id);
                              Navigator.pop(ctx, false);
                            },
                            child: const Text('Usuń zestaw'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Zapisz'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok == true) {
      g.name = nameCtrl.text.trim().isEmpty ? g.name : nameCtrl.text.trim();
      g.wordIds = selected.toList();
      widget.onChanged();
      setState(() {});
    } else {
      widget.onChanged();
      setState(() {});
    }
  }

  Widget _tile({
    required String id,
    required String title,
    required String subtitle,
    VoidCallback? onEdit,
  }) {
    final selected = _selected == id;
    return ListTile(
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onEdit == null
          ? null
          : IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
      onTap: () {
        setState(() => _selected = id);
        widget.onSelect(id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zestawy — ${widget.lang}'),
        actions: [
          IconButton(
            onPressed: _createGroup,
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Nowy zestaw',
          ),
        ],
      ),
      body: GradientScaffoldBody(
        palette: widget.palette,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SoftPanel(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _tile(
                    id: '__all__',
                    title: 'Cała baza',
                    subtitle: '${widget.pack.words.length} słów',
                  ),
                  _tile(
                    id: '__unlearned__',
                    title: 'Nieopanowane',
                    subtitle:
                        '${widget.pack.words.where((w) => w.level < 3).length} słów',
                  ),
                  _tile(
                    id: '__hard__',
                    title: 'Trudne',
                    subtitle:
                        '${widget.pack.words.where((w) => w.hard || w.level <= 1).length} słów',
                  ),
                ],
              ),
            ),
            if (widget.pack.groups.isNotEmpty)
              SoftPanel(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final g in widget.pack.groups)
                      _tile(
                        id: g.id,
                        title: g.name,
                        subtitle: '${g.wordIds.length} wybranych słów',
                        onEdit: () => _editGroup(g),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
