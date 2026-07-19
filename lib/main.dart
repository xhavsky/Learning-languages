import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_chat.dart';
import 'curiosities.dart';
import 'import_csv.dart';
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
    final dirRaw = prefs.getString('translateDir') ?? 'plToForeign';
    setState(() {
      _playbackRate = rate;
      _dir = switch (dirRaw) {
        'foreignToPl' => TranslateDir.foreignToPl,
        'mixed' => TranslateDir.mixed,
        _ => TranslateDir.plToForeign,
      };
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

  Future<void> _persistDir(TranslateDir dir) async {
    setState(() => _dir = dir);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'translateDir',
      switch (dir) {
        TranslateDir.plToForeign => 'plToForeign',
        TranslateDir.foreignToPl => 'foreignToPl',
        TranslateDir.mixed => 'mixed',
      },
    );
    _draw();
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
      // _askForeign = true → pokazujemy obcy, oczekujemy PL
      _askForeign = switch (_dir) {
        TranslateDir.plToForeign => false,
        TranslateDir.foreignToPl => true,
        TranslateDir.mixed => _rng.nextBool(),
      };
      if (_method == GameMethod.abc) {
        _abc = _buildAbc(_current!, askForeign: _askForeign);
      } else {
        _abc = [];
      }
    });
    if (_current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Auto-odtwarzaj tylko gdy na ekranie jest słowo obce —
        // przy PL→obcy NIE puszczaj odpowiedzi przed odpowiedzią.
        if (_askForeign) {
          _playText(_current!.obcy);
        }
        if (_method == GameMethod.typing) {
          _answerFocus.requestFocus();
        }
      });
    }
  }

  List<String> _buildAbc(Word correct, {required bool askForeign}) {
    final pack = _pack!;
    if (askForeign) {
      // Pokazujemy obcy → wybierz polskie
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
    // Pokazujemy polskie → wybierz obce
    final others = pack.words
        .map((w) => w.obcy)
        .where((o) => o != correct.obcy)
        .toSet()
        .toList()
      ..shuffle(_rng);
    final distractors = others.take(2).toList();
    while (distractors.length < 2) {
      distractors.add(['hello', 'cat', 'house'][distractors.length]);
    }
    return [correct.obcy, ...distractors]..shuffle(_rng);
  }

  String get _promptLabel {
    if (_askForeign) return 'Jak po polsku znaczy:';
    return 'Przetłumacz na język obcy:';
  }

  String get _promptWord {
    if (_current == null) return '';
    return _askForeign ? _current!.obcy : _current!.pl;
  }

  String get _expected {
    if (_current == null) return '';
    return _askForeign ? _current!.pl : _current!.obcy;
  }

  Future<void> _onResult(bool ok) async {
    final w = _current;
    if (w == null) return;
    applySrs(w, correct: ok);
    _store.stats.recordAnswer(ok);
    await _store.save();
    if (ok) {
      final msg = w.nauczone
          ? 'Nauczone! ✓ (3× z rzędu)'
          : 'Brawo! ✓ (${w.correctStreak}/3)';
      _flash(msg, kind: FeedbackKind.success);
      _successCtrl.forward(from: 0);
      _burstCtrl.forward(from: 0);
      await _playText(w.obcy);
      await Future<void>.delayed(const Duration(milliseconds: 850));
    } else {
      _flash('Poprawnie: $_expected', kind: FeedbackKind.fail, ms: 2000);
      await _shakeCtrl.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    await _maybeShowLevelRewards();
    if (mounted) _draw();
  }

  /// Po awansie poziomu: tytuł + ciekawostka + wyzwanie + bonus XP.
  Future<void> _maybeShowLevelRewards() async {
    final pending = _store.stats.pendingRewardLevels();
    if (pending.isEmpty) return;
    var bonusTotal = 0;
    for (final lv in pending) {
      final fact = curiosityForLevel(lv, lang: _lang);
      final bonus = levelUpBonusXpFor(lv);
      final unlockedTitle = newTitleAtLevel(lv);
      final rank = titleForLevel(lv);
      _store.stats.addXp(bonus);
      bonusTotal += bonus;
      if (!mounted) break;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('Poziom $lv! 🎉'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tytuł: ${rank.title}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (unlockedTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '✨ Nowy tytuł odblokowany!',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(unlockedTitle.blurb),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(rank.blurb),
                ],
                const SizedBox(height: 12),
                Text(
                  'Nagroda: +$bonus XP',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '📖 ${fact.title}',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(fact.text),
                if (fact.tip != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🎯 Wyzwanie: ${fact.tip}',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Super!'),
            ),
          ],
        ),
      );
    }
    _store.stats.markRewardsClaimed(pending);
    // Jeśli bonus XP dał kolejny poziom — kolejne nagrody w następnym wywołaniu.
    await _store.save();
    if (mounted) setState(() {});
    if (bonusTotal > 0 && _store.stats.pendingRewardLevels().isNotEmpty) {
      await _maybeShowLevelRewards();
    }
  }

  Future<void> _openCuriosityAlbum() async {
    final items = unlockedCuriosities(
      rewardedLevel: _store.stats.rewardedLevel,
      lang: _lang,
    );
    final rank = titleForLevel(_store.stats.playerLevel);
    if (!mounted) return;
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
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Album nagród',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Poziom ${_store.stats.playerLevel} · ${rank.title}',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                Text(
                  rank.blurb,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'Awansuj na poziom 2, żeby odblokować pierwszą ciekawostkę!',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = items[i];
                            return SoftPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.title,
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c.text),
                                  if (c.tip != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '🎯 ${c.tip}',
                                      style:
                                          Theme.of(ctx).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Future<void> _openWords() async {
    final pack = _pack;
    if (pack == null || _lang == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WordsPage(
          lang: _lang!,
          pack: pack,
          palette: widget.palette,
          onChanged: () async {
            await _store.save();
            setState(() {});
          },
        ),
      ),
    );
    setState(() {});
    _draw();
  }

  Future<void> _openSettings() async {
    final ollamaCtrl = TextEditingController(text: await loadOllamaHostPref());
    if (!mounted) {
      ollamaCtrl.dispose();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
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
                    Text(
                      'Ustawienia',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Motyw jasny/ciemny',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('System'),
                          selected: widget.themeMode == ThemeMode.system,
                          onSelected: (_) {
                            widget.onThemeModeChanged(ThemeMode.system);
                            setSheet(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Jasny'),
                          selected: widget.themeMode == ThemeMode.light,
                          onSelected: (_) {
                            widget.onThemeModeChanged(ThemeMode.light);
                            setSheet(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Ciemny'),
                          selected: widget.themeMode == ThemeMode.dark,
                          onSelected: (_) {
                            widget.onThemeModeChanged(ThemeMode.dark);
                            setSheet(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kolorystyka',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in AppPalette.values)
                          FilterChip(
                            avatar: CircleAvatar(backgroundColor: p.seed),
                            label: Text(p.label),
                            selected: widget.palette == p,
                            onSelected: (_) {
                              widget.onPaletteChanged(p);
                              setSheet(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kierunek',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('PL → obcy'),
                          selected: _dir == TranslateDir.plToForeign,
                          onSelected: (_) async {
                            await _persistDir(TranslateDir.plToForeign);
                            setSheet(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('obcy → PL'),
                          selected: _dir == TranslateDir.foreignToPl,
                          onSelected: (_) async {
                            await _persistDir(TranslateDir.foreignToPl);
                            setSheet(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Mieszany'),
                          selected: _dir == TranslateDir.mixed,
                          onSelected: (_) async {
                            await _persistDir(TranslateDir.mixed);
                            setSheet(() {});
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _dir == TranslateDir.plToForeign
                            ? 'Widzisz polskie — wpisujesz / wybierasz obce. Audio dopiero po odpowiedzi albo po 🔊.'
                            : _dir == TranslateDir.foreignToPl
                                ? 'Widzisz obce — odpowiadasz po polsku. Audio startuje od razu.'
                                : 'Losowo PL→obcy albo obcy→PL przy każdym słówku.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tempo audio',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final r in [0.75, 1.0, 1.25])
                          ChoiceChip(
                            label: Text('${r}x'),
                            selected: (_playbackRate - r).abs() < 0.01,
                            onSelected: (_) async {
                              await _persistRate(r);
                              setSheet(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI lokalne (Ollama)',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Na PC zwykle pusto (127.0.0.1). Na telefonie: zostaw pusto — '
                      'apka łączy się z modelem na PC przez portal. '
                      'Opcjonalnie wpisz adres LAN, np. http://192.168.0.130:11434',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ollamaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Adres Ollamy (opcjonalnie)',
                        hintText: 'http://192.168.0.130:11434',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () async {
                        await saveOllamaHostPref(ollamaCtrl.text);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Zapisano adres AI lokalnego'),
                            ),
                          );
                        }
                      },
                      child: const Text('Zapisz adres AI'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () async {
                        final path = await _store.exportToDocuments();
                        if (ctx.mounted) Navigator.pop(ctx);
                        _flash(
                          'Wyeksportowano:\n$path',
                          kind: FeedbackKind.info,
                          ms: 4000,
                        );
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
                        final err =
                            await _store.importFromPath(_importCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (err != null) {
                          _flash(err, kind: FeedbackKind.fail, ms: 3000);
                        } else {
                          setState(() {});
                          _draw();
                          _flash(
                            'Zaimportowano bazę',
                            kind: FeedbackKind.success,
                          );
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
                              ? 'Audio: komplet (${_store.baza.values.fold<int>(0, (n, p) => n + p.words.length)} słówek)'
                              : 'Brak audio: ${miss.length} haseł\n(PC: python3 scripts/generate_tts.py)',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dla Anielki',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
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
      },
    ).whenComplete(ollamaCtrl.dispose);
  }

  Future<void> _addWord() async {
    final plCtrl = TextEditingController();
    final obcyCtrl = TextEditingController();
    var lang = _lang ?? _store.baza.keys.first;
    String? categoryId;
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
              final groups = _store.baza[lang]?.groups ?? const <WordGroup>[];
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
                    onChanged: (v) => setLocal(() {
                      lang = v ?? lang;
                      categoryId = null;
                    }),
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
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: categoryId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Bez kategorii'),
                      ),
                      for (final g in groups)
                        DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => categoryId = v),
                    decoration: const InputDecoration(labelText: 'Kategoria'),
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
    final pl = capitalizePhrase(plCtrl.text);
    final obcy = capitalizePhrase(obcyCtrl.text);
    if (pl.isEmpty || obcy.isEmpty) {
      _flash('Wypełnij oba pola', kind: FeedbackKind.hint);
      return;
    }
    final pack = _store.baza.putIfAbsent(
      lang,
      () => LangPack(words: [], groups: []),
    );
    final created = Word.fromJson({'pl': pl, 'obcy': obcy});
    pack.words.add(created);
    if (categoryId != null) {
      final g = pack.groups.where((x) => x.id == categoryId).firstOrNull;
      if (g != null && !g.wordIds.contains(created.id)) {
        g.wordIds.add(created.id);
      }
    }
    await _store.save();
    setState(() {});
    _flash('Dodano: ${created.pl} → ${created.obcy}', kind: FeedbackKind.success);
  }

  Future<void> _openDailyChat() async {
    final pack = _pack;
    if (pack == null || _lang == null) {
      _flash('Wybierz język', kind: FeedbackKind.hint);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyChatPage(
          lang: _lang!,
          pack: pack,
          store: _store,
          palette: widget.palette,
          portal: _portal,
          onXpChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    if (mounted) {
      await _maybeShowLevelRewards();
      setState(() {});
    }
  }

  Future<void> _importWordsSheet() async {
    final pack = _pack;
    if (pack == null || _lang == null) {
      _flash('Wybierz język', kind: FeedbackKind.hint);
      return;
    }
    final textCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    var makeGroup = true;
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
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Import słówek',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wklej CSV lub tekst: pl,obcy · pl;obcy · pl - obcy\n'
                      'Jedna para w linii.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textCtrl,
                      minLines: 6,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'Tekst / CSV',
                        hintText: 'kot,cat\npies,dog\ndom - house',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Albo ścieżka do pliku .csv / .txt',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Utwórz kategorię z importu'),
                      value: makeGroup,
                      onChanged: (v) => setLocal(() => makeGroup = v),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Importuj'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (ok != true) {
      textCtrl.dispose();
      pathCtrl.dispose();
      return;
    }

    var raw = textCtrl.text;
    final path = pathCtrl.text.trim();
    textCtrl.dispose();
    pathCtrl.dispose();

    if (raw.trim().isEmpty && path.isNotEmpty) {
      try {
        raw = await File(path).readAsString();
      } catch (e) {
        _flash('Nie da się odczytać pliku: $e', kind: FeedbackKind.fail, ms: 3000);
        return;
      }
    }
    if (raw.trim().isEmpty) {
      _flash('Wklej tekst albo podaj ścieżkę', kind: FeedbackKind.hint);
      return;
    }

    final beforeIds = pack.words.map((w) => w.id).toSet();
    final result = importWordText(pack, raw);
    if (result.added > 0 && makeGroup) {
      final newIds = pack.words
          .where((w) => !beforeIds.contains(w.id))
          .map((w) => w.id)
          .toList();
      if (newIds.isNotEmpty) {
        pack.groups.add(
          WordGroup(
            id: 'g-import-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Import ${DateTime.now().day}.${DateTime.now().month}',
            wordIds: newIds,
          ),
        );
      }
    }
    await _store.save();
    setState(() {});
    _draw();
    _flash(
      result.summary,
      kind: result.added > 0 ? FeedbackKind.success : FeedbackKind.hint,
      ms: 3500,
    );
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
          'Kategoria',
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
                'v0.0.6',
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
            tooltip: 'Kategorie',
            onPressed: _openGroups,
            icon: const Icon(Icons.folder_special_outlined),
          ),
          IconButton(
            tooltip: 'Słówka',
            onPressed: _openWords,
            icon: const Icon(Icons.menu_book_outlined),
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
                            '💌 Portal Anielki',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _portal.url,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'PIN: ${_portal.pin} · Twój projekt — wspólna praca z tatą',
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
                            'Kategoria: ${_groupLabel()} · $mastered/${allInGroup.length} ($pct%)',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            'Sesja: ${_store.stats.sessionCorrect}/${_store.stats.sessionTotal}'
                            ' · streak ${_store.stats.streakDays} dni',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'Poz. ${_store.stats.playerLevel}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: _store.stats.levelProgress,
                                    minHeight: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${_store.stats.xp} XP',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Text(
                            titleForLevel(_store.stats.playerLevel).title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Do kolejnego poziomu: ${_store.stats.xpToNextLevel} XP'
                            '${_store.stats.sessionXp > 0 ? ' · +${_store.stats.sessionXp} dziś' : ''}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _openCuriosityAlbum,
                            child: const Text('Album nagród / ciekawostki'),
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
                        OutlinedButton.icon(
                          onPressed: _importWordsSheet,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Import CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openWords,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Lista'),
                        ),
                        FilledButton.icon(
                          onPressed: _openDailyChat,
                          icon: Icon(
                            _store.stats.chatDoneToday
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                          ),
                          label: Text(
                            _store.stats.chatDoneToday
                                ? 'Rozmowa ✓'
                                : 'AI lokalne',
                          ),
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
                              ? 'Brak opanowanych w tej kategorii.'
                              : 'Brak słówek do nauki w kategorii.\nDodaj słowa lub wybierz inną kategorię.',
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

  Future<bool> _pickWords({
    required String title,
    required Set<String> selected,
    required TextEditingController nameCtrl,
    required bool createMode,
  }) async {
    final filterCtrl = TextEditingController();
    var query = '';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final q = query.trim().toLowerCase();
            final sorted = List<Word>.of(widget.pack.words)
              ..sort((a, b) => a.pl.toLowerCase().compareTo(b.pl.toLowerCase()));
            final filtered = q.isEmpty
                ? sorted
                : sorted
                    .where(
                      (w) =>
                          w.pl.toLowerCase().contains(q) ||
                          w.obcy.toLowerCase().contains(q),
                    )
                    .toList();
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nazwa kategorii',
                        hintText: 'np. Czasowniki na dziś',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: filterCtrl,
                      onChanged: (v) => setLocal(() => query = v),
                      decoration: InputDecoration(
                        labelText: 'Szukaj słówka',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  filterCtrl.clear();
                                  setLocal(() => query = '');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Zaznaczone: ${selected.length} · Widoczne: ${filtered.length}',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zaznacz słowa do kategorii (możesz szukać po polsku lub obcym).',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SoftPanel(
                        margin: EdgeInsets.zero,
                        padding: EdgeInsets.zero,
                        child: filtered.isEmpty
                            ? const Center(child: Text('Brak słówek'))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final w = filtered[i];
                                  final on = selected.contains(w.id);
                                  return CheckboxListTile(
                                    value: on,
                                    dense: true,
                                    title: Text(
                                      w.pl,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text('→ ${w.obcy}'),
                                    secondary: Text(
                                      w.nauczone
                                          ? '✓'
                                          : '${w.correctStreak}/3',
                                      style: TextStyle(
                                        color: w.nauczone
                                            ? Colors.green
                                            : Theme.of(ctx)
                                                .colorScheme
                                                .outline,
                                      ),
                                    ),
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
                    ),
                    const SizedBox(height: 12),
                    if (!createMode)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                widget.pack.groups
                                    .removeWhere((x) => x.id == _editingGroupId);
                                Navigator.pop(ctx, false);
                              },
                              child: const Text('Usuń kategorię'),
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
                      )
                    else
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          selected.isEmpty
                              ? 'Utwórz (wybierz słowa)'
                              : 'Utwórz kategorię (${selected.length})',
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    filterCtrl.dispose();
    return ok == true;
  }

  String? _editingGroupId;

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();
    final selected = <String>{};
    _editingGroupId = null;
    final ok = await _pickWords(
      title: 'Nowa kategoria',
      selected: selected,
      nameCtrl: nameCtrl,
      createMode: true,
    );
    if (!ok) {
      nameCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (!mounted) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj nazwę kategorii')),
      );
      return;
    }
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaznacz przynajmniej jedno słówko')),
      );
      return;
    }
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
    _editingGroupId = g.id;
    final ok = await _pickWords(
      title: 'Edytuj kategorię',
      selected: selected,
      nameCtrl: nameCtrl,
      createMode: false,
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok) {
      g.name = name.isEmpty ? g.name : name;
      g.wordIds = selected.toList();
    }
    widget.onChanged();
    setState(() {});
  }

  Widget _tile({
    required String id,
    required String title,
    required String subtitle,
    VoidCallback? onEdit,
    List<String>? preview,
  }) {
    final selected = _selected == id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          selected: selected,
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          subtitle: Text(subtitle),
          trailing: onEdit == null
              ? null
              : IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
          onTap: () {
            setState(() => _selected = id);
            widget.onSelect(id);
          },
        ),
        if (preview != null && preview.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Text(
              preview.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
            ),
          ),
      ],
    );
  }

  List<String> _previewFor(List<String> ids) {
    return ids
        .map(widget.pack.byId)
        .whereType<Word>()
        .take(6)
        .map((w) => w.pl)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kategorie — ${widget.lang}'),
        actions: [
          IconButton(
            onPressed: _createGroup,
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Nowa kategoria',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.add),
        label: const Text('Nowa kategoria'),
      ),
      body: GradientScaffoldBody(
        palette: widget.palette,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Wybierz kategorię tematyczną albo utwórz własną z listy słówek.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SoftPanel(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      'Szybki wybór',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  _tile(
                    id: '__all__',
                    title: 'Cała baza',
                    subtitle: '${widget.pack.words.length} słów',
                    preview: _previewFor(
                      widget.pack.words.take(6).map((w) => w.id).toList(),
                    ),
                  ),
                  const Divider(height: 1),
                  _tile(
                    id: '__unlearned__',
                    title: 'Nieopanowane',
                    subtitle:
                        '${widget.pack.words.where((w) => w.level < 3).length} słów',
                  ),
                  const Divider(height: 1),
                  _tile(
                    id: '__hard__',
                    title: 'Trudne',
                    subtitle:
                        '${widget.pack.words.where((w) => w.hard || w.level <= 1).length} słów',
                  ),
                ],
              ),
            ),
            SoftPanel(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      widget.pack.groups.isEmpty
                          ? 'Kategorie (pusto — dodaj pierwszą)'
                          : 'Kategorie tematyczne (${widget.pack.groups.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (widget.pack.groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Text(
                        'Kliknij „Nowa kategoria”, wpisz nazwę i zaznacz słówka.',
                      ),
                    )
                  else
                    for (final g in widget.pack.groups) ...[
                      _tile(
                        id: g.id,
                        title: g.name,
                        subtitle: '${g.wordIds.length} słów',
                        onEdit: () => _editGroup(g),
                        preview: _previewFor(g.wordIds),
                      ),
                      if (g != widget.pack.groups.last)
                        const Divider(height: 1),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WordsPage extends StatefulWidget {
  const WordsPage({
    super.key,
    required this.lang,
    required this.pack,
    required this.palette,
    required this.onChanged,
  });

  final String lang;
  final LangPack pack;
  final AppPalette palette;
  final VoidCallback onChanged;

  @override
  State<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends State<WordsPage> {
  final _filterCtrl = TextEditingController();
  String _query = '';
  String? _categoryFilter; // null = wszystkie

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteWord(Word w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć słówko?'),
        content: Text('${w.pl} → ${w.obcy}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.pack.removeWord(w.id);
    widget.onChanged();
    setState(() {});
  }

  Future<void> _editWord(Word w) async {
    final plCtrl = TextEditingController(text: w.pl);
    final obcyCtrl = TextEditingController(text: w.obcy);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edytuj słówko', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: plCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Po polsku'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: obcyCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Tłumaczenie'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Zapisz'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) {
      plCtrl.dispose();
      obcyCtrl.dispose();
      return;
    }
    final pl = capitalizePhrase(plCtrl.text);
    final obcy = capitalizePhrase(obcyCtrl.text);
    plCtrl.dispose();
    obcyCtrl.dispose();
    if (pl.isEmpty || obcy.isEmpty) return;
    final idx = widget.pack.words.indexWhere((x) => x.id == w.id);
    if (idx < 0) return;
    widget.pack.words[idx] = Word(
      id: w.id,
      pl: pl,
      obcy: obcy,
      level: w.level,
      hard: w.hard,
      nextDue: w.nextDue,
      correctStreak: w.correctStreak,
    );
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    var sorted = List<Word>.of(widget.pack.words);
    if (_categoryFilter != null) {
      final ids = widget.pack.groups
          .where((g) => g.id == _categoryFilter)
          .expand((g) => g.wordIds)
          .toSet();
      sorted = sorted.where((w) => ids.contains(w.id)).toList();
    }
    sorted.sort((a, b) => a.pl.toLowerCase().compareTo(b.pl.toLowerCase()));
    final list = q.isEmpty
        ? sorted
        : sorted
            .where(
              (w) =>
                  w.pl.toLowerCase().contains(q) ||
                  w.obcy.toLowerCase().contains(q) ||
                  widget.pack
                      .categoriesFor(w.id)
                      .any((c) => c.toLowerCase().contains(q)),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Słówka — ${widget.lang}'),
      ),
      body: GradientScaffoldBody(
        palette: widget.palette,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _filterCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  labelText: 'Szukaj',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _filterCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            if (widget.pack.groups.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: const Text('Wszystkie'),
                        selected: _categoryFilter == null,
                        onSelected: (_) =>
                            setState(() => _categoryFilter = null),
                      ),
                    ),
                    for (final g in widget.pack.groups)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(g.name),
                          selected: _categoryFilter == g.id,
                          onSelected: (_) => setState(
                            () => _categoryFilter =
                                _categoryFilter == g.id ? null : g.id,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${list.length} słówek · przesuń w lewo, żeby usunąć',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SoftPanel(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: EdgeInsets.zero,
                child: list.isEmpty
                    ? const Center(child: Text('Brak słówek'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final w = list[i];
                          final cats = widget.pack.categoriesFor(w.id);
                          return Dismissible(
                            key: ValueKey(w.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Theme.of(context).colorScheme.error,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (_) async {
                              await _deleteWord(w);
                              return false;
                            },
                            child: ListTile(
                              title: Text(
                                w.pl,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17,
                                ),
                              ),
                              subtitle: Text(
                                cats.isEmpty
                                    ? '→ ${w.obcy}'
                                    : '→ ${w.obcy} · ${cats.join(', ')}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    w.nauczone ? '✓' : '${w.correctStreak}/3',
                                    style: TextStyle(
                                      color: w.nauczone
                                          ? Colors.green
                                          : Theme.of(context)
                                              .colorScheme
                                              .outline,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edytuj',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editWord(w),
                                  ),
                                  IconButton(
                                    tooltip: 'Usuń',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteWord(w),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
