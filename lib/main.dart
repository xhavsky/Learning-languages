import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_chat.dart';
import 'answer_match.dart';
import 'curiosities.dart';
import 'import_csv.dart';
import 'l10n.dart';
import 'mascot.dart';
import 'model3d_viewer.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'ui_fx.dart';

const _appVersionLabel = 'v0.0.19';

void _bootLog(String msg) {
  try {
    final home = Platform.environment['HOME'] ?? '';
    final f = File('$home/Dokumenty/dialectium-boot.log');
    f.writeAsStringSync(
      '${DateTime.now().toIso8601String()} $msg\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
}

void main() {
  _bootLog('main start');
  WidgetsFlutterBinding.ensureInitialized();
  // CEF init dopiero przy pierwszym podglądzie 3D — inaczej przy starcie
  // apki widać procesy Chromium w docku i zbędny koszt GPU.
  _bootLog('before runApp');
  runApp(const DialectiumApp());
}

enum GameMethod { abc, typing, sentences }

enum TranslateDir { plToForeign, foreignToPl, mixed }

const _cyrillicRows = [
  ['й', 'ц', 'у', 'к', 'е', 'н', 'г', 'ш', 'щ', 'з', 'х', 'ъ'],
  ['ф', 'ы', 'в', 'а', 'п', 'р', 'о', 'л', 'д', 'ж', 'э'],
  ['я', 'ч', 'с', 'м', 'и', 'т', 'ь', 'б', 'ю', 'ё'],
];

const _spanishExtras = ['á', 'é', 'í', 'ó', 'ú', 'ñ', 'ü', '¿', '¡'];

class DialectiumApp extends StatefulWidget {
  const DialectiumApp({super.key});

  @override
  State<DialectiumApp> createState() => _DialectiumAppState();
}

class _DialectiumAppState extends State<DialectiumApp> {
  ThemeMode _themeMode = ThemeMode.system;
  AppPalette _palette = AppPalette.mint;
  UiLang _uiLang = UiLang.pl;

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
      _uiLang = UiLang.fromCode(prefs.getString('uiLang'));
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

  Future<void> _setUiLang(UiLang lang) async {
    setState(() => _uiLang = lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uiLang', lang.code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n(_uiLang);
    return MaterialApp(
      title: l10n.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: buildAppTheme(brightness: Brightness.light, palette: _palette),
      darkTheme: buildAppTheme(brightness: Brightness.dark, palette: _palette),
      home: HomePage(
        themeMode: _themeMode,
        palette: _palette,
        uiLang: _uiLang,
        onThemeModeChanged: _setThemeMode,
        onPaletteChanged: _setPalette,
        onUiLangChanged: _setUiLang,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.themeMode,
    required this.palette,
    required this.uiLang,
    required this.onThemeModeChanged,
    required this.onPaletteChanged,
    required this.onUiLangChanged,
  });

  final ThemeMode themeMode;
  final AppPalette palette;
  final UiLang uiLang;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPalette> onPaletteChanged;
  final ValueChanged<UiLang> onUiLangChanged;

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
  String _loadingMsg = L10n.pl.loadingStarting;
  String? _bootError;
  String? _lang;
  String _groupId = '__all__';
  GameMethod _method = GameMethod.typing;
  TranslateDir _dir = TranslateDir.plToForeign;
  bool _poolReview = false; // false=due/new, true=review mastered
  bool _hintShown = false;
  double _playbackRate = 1.0;
  /// Gdy false — lektor (audio) wyłączony.
  bool _audioEnabled = true;

  Word? _current;
  bool _askForeign = false; // true = show foreign, expect PL
  List<String> _abc = [];
  int? _abcHi;
  Color? _abcHiColor;

  String? _banner; // inline feedback (no AlertDialog)
  FeedbackKind _bannerKind = FeedbackKind.info;
  bool _bannerVisible = false;
  String? _audioHint;

  /// Zakładka treści: 0=Nauka, 1=Słówka, 2=Maskotka, 3=Sklep, 4=Pule, 5=Ustawienia.
  /// Dolne menu pokazuje 4 pozycje: Nauka · Słówka · Maskotka · Więcej.
  int _bottomNav = 0;

  /// Na telefonie: rozwinięte ustawienia lekcji (język / metoda / pula).
  bool _lessonSettingsOpen = false;

  /// Trwa sprawdzanie odpowiedzi — blokuje podwójne kliknięcie „Sprawdź”.
  bool _checkingAnswer = false;

  bool _isPhoneLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 900;

  /// Indeks w NavigationBar (0–3); Sklep/Pule/Ustawienia → „Więcej”.
  int get _navBarIndex => _bottomNav <= 2 ? _bottomNav : 3;

  L10n get _l10n => L10n(widget.uiLang);

  void _onNavBarSelected(int i) {
    if (i < 3) {
      setState(() => _bottomNav = i);
      return;
    }
    _showMoreMenu();
  }

  Future<void> _showMoreMenu() async {
    final l10n = _l10n;
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        Widget tile({
          required int id,
          required IconData icon,
          required String label,
          required String subtitle,
          Key? key,
        }) {
          final selected = _bottomNav == id;
          return Material(
            key: key,
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.65)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(ctx, id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: scheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                          Text(
                            subtitle,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.65),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.moreMenuTitle,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                tile(
                  id: 3,
                  key: const ValueKey('more_shop'),
                  icon: Icons.storefront_rounded,
                  label: l10n.tabShop,
                  subtitle: l10n.shopSubtitle,
                ),
                const SizedBox(height: 6),
                tile(
                  id: 4,
                  key: const ValueKey('more_pools'),
                  icon: Icons.folder_special_rounded,
                  label: l10n.tabPools,
                  subtitle: l10n.poolWordsHint,
                ),
                const SizedBox(height: 6),
                tile(
                  id: 5,
                  key: const ValueKey('more_settings'),
                  icon: Icons.settings_rounded,
                  label: l10n.tabSettings,
                  subtitle: l10n.theme,
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice != null && mounted) {
      setState(() => _bottomNav = choice);
    }
  }

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
    _bootLog('_boot start');
    try {
      if (!mounted) return;
      setState(() {
        _bootError = null;
        _loadingMsg = L10n(widget.uiLang).loadingSettings;
      });
      setState(() => _loadingMsg = L10n(widget.uiLang).loadingWords);
      _bootLog('_boot: loading baza');
      await _store.load().timeout(const Duration(seconds: 60));
      _bootLog('_boot: baza ok keys=${_store.baza.keys.length}');
      final lang = _store.baza.containsKey('Angielski')
          ? 'Angielski'
          : (_store.baza.keys.isNotEmpty ? _store.baza.keys.first : null);
      if (!mounted) return;
      setState(() {
        _lang = lang;
        _loading = false;
        _bootError = null;
      });
      _bootLog('_boot: lang=$lang loading method');
      await _loadMethodForLang(lang);
      _draw();
      _bootLog('_boot: success');
    } catch (e, st) {
      // Nigdy nie zostawiaj wiecznego spinnera — pokaż błąd.
      // ignore: avoid_print
      print('BOOT ERROR: $e\n$st');
      _bootLog('_boot ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _bootError = e.toString();
        _loadingMsg = L10n(widget.uiLang).loadingFailed;
      });
    }
  }

  Future<void> _retryBoot() async {
    setState(() {
      _loading = true;
      _bootError = null;
      _loadingMsg = L10n(widget.uiLang).loadingRetry;
    });
    await _boot();
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
      setState(() => _audioHint = _l10n.audioUnavailable(e));
      return null;
    }
  }

  Future<void> _playText(String text) async {
    if (!_audioEnabled) return;
    final lang = _lang;
    if (lang == null) return;
    final asset = _store.audioAsset(lang, text);
    if (asset == null) {
      setState(() {
        _audioHint = _l10n.noAudioHint;
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
      setState(() => _audioHint = _l10n.playbackError(e));
    }
  }

  Future<void> _loadMethodForLang(String? lang) async {
    if (lang == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('method_$lang');
    final rate = prefs.getDouble('playbackRate') ?? 1.0;
    final dirRaw = prefs.getString('translateDir') ?? 'plToForeign';
    final audioOn = prefs.getBool('audioEnabled') ?? true;
    setState(() {
      _playbackRate = rate;
      _audioEnabled = audioOn;
      _dir = switch (dirRaw) {
        'foreignToPl' => TranslateDir.foreignToPl,
        'mixed' => TranslateDir.mixed,
        _ => TranslateDir.plToForeign,
      };
      if (raw == 'abc') {
        _method = GameMethod.abc;
      } else if (raw == 'typing') {
        _method = GameMethod.typing;
      } else if (raw == 'sentences') {
        _method = GameMethod.sentences;
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
      switch (_method) {
        GameMethod.abc => 'abc',
        GameMethod.typing => 'typing',
        GameMethod.sentences => 'sentences',
      },
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

  Future<void> _persistAudioEnabled(bool on) async {
    setState(() => _audioEnabled = on);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audioEnabled', on);
    if (!on) {
      try {
        await _player?.stop();
      } catch (_) {}
    }
  }

  List<Word> _sessionPool() {
    final pack = _pack;
    if (pack == null) return [];
    var words = _method == GameMethod.sentences
        ? List<Word>.of(pack.sentences)
        : pack.wordsForGroup(_groupId);
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
        // fallback: any non-mastered in group / sentences
        if (_method == GameMethod.sentences) {
          words = pack.sentences.where((w) => w.level < 3).toList();
        } else {
          words =
              pack.wordsForGroup(_groupId).where((w) => w.level < 3).toList();
        }
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
        if (_method == GameMethod.typing ||
            _method == GameMethod.sentences) {
          _answerFocus.requestFocus();
        }
      });
    }
  }

  /// Im wyższy wynik, tym bardziej myląca (trudniejsza) opcja względem [correct].
  int _abcSimilarity(String correct, String candidate) {
    final a = stripDiacritics(normalizeAnswer(stripInfinitiveParticle(correct)));
    final b =
        stripDiacritics(normalizeAnswer(stripInfinitiveParticle(candidate)));
    if (a.isEmpty || b.isEmpty || a == b) return -9999;
    var score = 0;
    final lenDiff = (a.length - b.length).abs();
    score += (12 - lenDiff).clamp(0, 12) * 4;
    if (a[0] == b[0]) score += 20;
    if (a.length >= 2 && b.length >= 2 && a[1] == b[1]) score += 10;
    if (a[a.length - 1] == b[b.length - 1]) score += 8;
    final setA = a.split('').toSet();
    final setB = b.split('').toSet();
    score += setA.intersection(setB).length * 3;
    // wspólny prefiks
    final n = a.length < b.length ? a.length : b.length;
    var pref = 0;
    for (var i = 0; i < n; i++) {
      if (a[i] != b[i]) break;
      pref++;
    }
    score += pref * 6;
    // dystans Levenshteina (krótki = trudniej)
    final dist = _editDistance(a, b);
    score += (10 - dist).clamp(0, 10) * 5;
    return score;
  }

  int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      var diag = prev[0];
      prev[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final tmp = prev[j];
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        prev[j] = [
          prev[j] + 1,
          prev[j - 1] + 1,
          diag + cost,
        ].reduce((x, y) => x < y ? x : y);
        diag = tmp;
      }
    }
    return prev[b.length];
  }

  List<String> _pickHardDistractors(
    String correct,
    Iterable<String> pool, {
    required List<String> fallback,
  }) {
    final others = pool.where((s) => s != correct).toSet().toList();
    if (others.isEmpty) {
      return fallback.take(2).toList();
    }
    others.sort((x, y) {
      final cmp = _abcSimilarity(correct, y).compareTo(_abcSimilarity(correct, x));
      if (cmp != 0) return cmp;
      return _rng.nextBool() ? 1 : -1;
    });
    // spośród najtrudniejszych ~8 wybierz 2 losowo — nie zawsze te same
    final top = others.take(others.length < 8 ? others.length : 8).toList()
      ..shuffle(_rng);
    final distractors = top.take(2).toList();
    var i = 0;
    while (distractors.length < 2 && i < fallback.length) {
      final f = fallback[i++];
      if (f != correct && !distractors.contains(f)) distractors.add(f);
    }
    return distractors;
  }

  List<String> _buildAbc(Word correct, {required bool askForeign}) {
    final pack = _pack!;
    final poolItems =
        _method == GameMethod.sentences ? pack.sentences : pack.words;
    if (askForeign) {
      // Pokazujemy obcy → wybierz polskie (trudne, podobne opcje)
      final distractors = _pickHardDistractors(
        correct.pl,
        poolItems.map((w) => w.pl),
        fallback: const ['kot', 'pies', 'dom'],
      );
      return [correct.pl, ...distractors]..shuffle(_rng);
    }
    // Pokazujemy polskie → wybierz obce
    final distractors = _pickHardDistractors(
      correct.obcy,
      poolItems.map((w) => w.obcy),
      fallback: const ['hello', 'cat', 'house'],
    );
    return [correct.obcy, ...distractors]..shuffle(_rng);
  }

  String get _promptLabel {
    final l = _l10n;
    if (_method == GameMethod.sentences) {
      if (_askForeign) return l.promptTranslateSentencePl;
      return l.promptTranslateSentenceForeign('');
    }
    if (_askForeign) return l.promptTranslatePl;
    return l.promptTranslateForeign;
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
    final justFed = _store.stats.recordAnswer(ok);
    await _store.save();
    if (ok) {
      final l = _l10n;
      final pet = l.petName(_store.stats.mascotSpecies == MascotSpecies.dog);
      var msg = w.nauczone
          ? l.learnedStreak
          : l.bravoStreak(w.correctStreak);
      if (justFed) {
        msg = '$msg · ${l.fedBonus(pet, pawsFeedBonus)}';
      } else {
        msg = '$msg · ${l.pawsPlus(pawsPerCorrect)}';
      }
      _flash(msg, kind: FeedbackKind.success);
      _successCtrl.forward(from: 0);
      _burstCtrl.forward(from: 0);
      await _playText(w.obcy);
      await Future<void>.delayed(const Duration(milliseconds: 850));
    } else {
      _flash(_l10n.correctWas(_expected), kind: FeedbackKind.fail, ms: 2000);
      await _shakeCtrl.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    await _maybeShowLevelRewards();
    if (mounted) _draw();
  }

  /// Po awansie poziomu: tytuł + ciekawostka + ubranko Kici + bonus XP.
  Future<void> _maybeShowLevelRewards() async {
    final pending = _store.stats.pendingRewardLevels();
    if (pending.isEmpty) return;
    final l10n = _l10n;
    final ui = widget.uiLang;
    var bonusTotal = 0;
    for (final lv in pending) {
      final fact = curiosityForLevel(lv, lang: _lang, uiLang: ui);
      final bonus = levelUpBonusXpFor(lv);
      final unlockedTitle = newTitleAtLevel(lv, uiLang: ui);
      final rank = titleForLevel(lv, uiLang: ui);
      final outfit = rollMascotReward(_store.stats.unlockedMascotIds);
      if (outfit != null) {
        _store.stats.unlockMascotItem(outfit.id);
      }
      _store.stats.addXp(bonus);
      _store.stats.addGoldenPaws(pawsPerLevelUp);
      bonusTotal += bonus;
      if (!mounted) break;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.levelUpCongrats(lv)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.titleLabel(rank.title),
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (unlockedTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.newTitleUnlocked,
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
                  l10n.rewardXpPaws(bonus, pawsPerLevelUp),
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (outfit != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: outfit.color,
                        child: Text(
                          outfit.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.randomOutfit(outfit.name),
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(outfit.blurb),
                            Text(
                              l10n.wearInWardrobe,
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: DressedKicia(
                      equipped: Map<String, String>.from(
                        _store.stats.equippedMascot,
                      ),
                      placedHome: Map<String, String>.from(
                        _store.stats.placedHome,
                      ),
                      species: _store.stats.mascotSpecies,
                      furColor: Color(_store.stats.mascotColorArgb),
                      size: 140,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Żarówka tylko przy ciekawostce (nie przy samym ubranku/tytule).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Theme.of(ctx).colorScheme.tertiary,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fact.title,
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(fact.text),
                        ],
                      ),
                    ),
                  ],
                ),
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
                      l10n.challengeTip(fact.tip!),
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
              child: Text(l10n.superOk),
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
    final l10n = _l10n;
    final ui = widget.uiLang;
    final items = unlockedCuriosities(
      rewardedLevel: _store.stats.rewardedLevel,
      lang: _lang,
      uiLang: ui,
    );
    final rank = titleForLevel(_store.stats.playerLevel, uiLang: ui);
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
                  l10n.albumRewards,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.levelAndTitle(_store.stats.playerLevel, rank.title),
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                Text(
                  rank.blurb,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            l10n.unlockFirstCuriosity,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = items[i];
                            return SoftPanel(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: Theme.of(ctx).colorScheme.tertiary,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.title,
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(c.text),
                                        if (c.tip != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            '🎯 ${c.tip}',
                                            style: Theme.of(ctx)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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

  Future<void> _equipMascot(MascotItem item) async {
    setState(() => _store.stats.toggleEquipMascot(item));
    await _store.save();
  }

  Future<void> _openShop() async {
    if (!mounted) return;
    setState(() => _bottomNav = 3);
  }

  Future<void> _openWardrobe() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final unlockedIds = _store.stats.unlockedMascotIds;
            final unlocked = unlockedMascotItems(unlockedIds);
            final equipped = _store.stats.equippedMascot;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _l10n.wardrobeTitle(
                        _l10n.petName(
                          _store.stats.mascotSpecies == MascotSpecies.dog,
                        ),
                      ),
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _l10n.wardrobeBlurb(mascotDailyFeedGoal),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: DressedKicia(
                        equipped: Map<String, String>.from(equipped),
                        placedHome:
                            Map<String, String>.from(_store.stats.placedHome),
                        species: _store.stats.mascotSpecies,
                        furColor: Color(_store.stats.mascotColorArgb),
                        size: 180,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final item in mascotWardrobe)
                            ListTile(
                              leading: Opacity(
                                opacity:
                                    unlockedIds.contains(item.id) ? 1 : 0.45,
                                child: OutfitThumb(item: item, size: 44),
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                unlockedIds.contains(item.id)
                                    ? '${slotLabel(item.slot)} · ${item.blurb}'
                                    : item.isShopExclusive
                                        ? '${_l10n.shopOnly} · ${item.shopPrice} 🐾'
                                        : _l10n.notRolledYet,
                              ),
                              selected: equipped[item.slot.name] == item.id,
                              trailing: !unlockedIds.contains(item.id)
                                  ? Icon(
                                      item.isShopExclusive
                                          ? Icons.storefront_outlined
                                          : Icons.lock_outline,
                                    )
                                  : Icon(
                                      equipped[item.slot.name] == item.id
                                          ? Icons.checkroom
                                          : Icons.checkroom_outlined,
                                      color: equipped[item.slot.name] == item.id
                                          ? Theme.of(ctx).colorScheme.primary
                                          : null,
                                    ),
                              onTap: !unlockedIds.contains(item.id)
                                  ? null
                                  : () async {
                                      await _equipMascot(item);
                                      setSheet(() {});
                                    },
                            ),
                          if (unlocked.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _l10n.nothingUnlockedYet,
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
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
  }

  Future<void> _checkTyping() async {
    if (_current == null || _checkingAnswer) return;
    _checkingAnswer = true;
    try {
      final user = _answerCtrl.text;
      final ok = answersMatch(
        user,
        _expected,
        lang: _lang,
        expectPolish: _askForeign,
      );
      await _onResult(ok);
    } finally {
      _checkingAnswer = false;
    }
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
        _l10n.hintFlash(exp[0], exp.length),
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

  Future<void> _openGroups({bool openCreate = false}) async {
    final pack = _pack;
    if (pack == null || _lang == null) return;
    if (!openCreate) {
      setState(() => _bottomNav = 4);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupsPage(
                                  lang: _lang!,
                                  pack: pack,
                                  selectedId: _groupId,
                                  palette: widget.palette,
                                  uiLang: widget.uiLang,
          openCreateOnStart: openCreate,
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
    setState(() => _bottomNav = 1);
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
                  Text(_l10n.addWordTitle, style: Theme.of(ctx).textTheme.titleLarge),
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
                    decoration: InputDecoration(labelText: _l10n.language),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: plCtrl,
                    decoration: InputDecoration(labelText: _l10n.inPolish),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: obcyCtrl,
                    decoration: InputDecoration(labelText: _l10n.translation),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: categoryId,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(_l10n.noCategory),
                      ),
                      for (final g in groups)
                        DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => categoryId = v),
                    decoration: InputDecoration(labelText: _l10n.category),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(_l10n.save),
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
      _flash(_l10n.fillBothFields, kind: FeedbackKind.hint);
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
    _flash(_l10n.addedWord(created.pl, created.obcy), kind: FeedbackKind.success);
  }

  Future<void> _openDailyChat() async {
    final pack = _pack;
    if (pack == null || _lang == null) {
      _flash(_l10n.pickLanguage, kind: FeedbackKind.hint);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyChatPage(
          lang: _lang!,
          pack: pack,
          store: _store,
          palette: widget.palette,
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
      _flash(_l10n.pickLanguage, kind: FeedbackKind.hint);
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
                      _l10n.importWordsTitle,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _l10n.importWordsHelp,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textCtrl,
                      minLines: 6,
                      maxLines: 12,
                      decoration: InputDecoration(
                        labelText: _l10n.importTextLabel,
                        hintText: 'kot,cat\npies,dog\ndom - house',
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pathCtrl,
                      decoration: InputDecoration(
                        labelText: _l10n.importFilePath,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_l10n.createCategoryFromImport),
                      value: makeGroup,
                      onChanged: (v) => setLocal(() => makeGroup = v),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(_l10n.importAction),
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
        _flash(_l10n.cannotReadFile(e), kind: FeedbackKind.fail, ms: 3000);
        return;
      }
    }
    if (raw.trim().isEmpty) {
      _flash(_l10n.pasteOrPath, kind: FeedbackKind.hint);
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
        _l10n.russianKeyboard,
        [
          for (final row in _cyrillicRows) row,
        ],
      );
    }
    if (_lang == 'Hiszpański') {
      return _keyCard(_l10n.spanishChars, [_spanishExtras]);
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
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => _insert(' '),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(_l10n.spaceKey),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _backspace,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(_l10n.backspaceKey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _groupLabel() {
    final pack = _pack;
    final l = _l10n;
    if (pack == null) return l.poolAll;
    return switch (_groupId) {
      '__all__' => l.poolAll,
      '__unlearned__' => l.poolUnlearned,
      '__hard__' => l.poolHard,
      _ => pack.groups
              .where((g) => g.id == _groupId)
              .map((g) => g.name)
              .firstOrNull ??
          l.category,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_bootError != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.orangeAccent),
                const SizedBox(height: 16),
                Text(
                  _l10n.bootFailed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _bootError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  _l10n.bootFailedHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _retryBoot,
                  child: Text(_l10n.tryAgain),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFF1A1A22),
      );
    }
    if (_loading) {
      return Scaffold(
        body: GradientScaffoldBody(
          palette: widget.palette,
          child: AppBootShimmer(
            title: _l10n.starting,
            subtitle: _loadingMsg,
          ),
        ),
      );
    }
    final pack = _pack;
    final pool = _sessionPool();
    final allInGroup = pack?.wordsForGroup(_groupId) ?? [];
    final mastered = allInGroup.where((w) => w.level >= 3).length;
    final pct =
        allInGroup.isEmpty ? 0 : (100 * mastered / allInGroup.length).round();

    final phone = _isPhoneLayout(context);
    final l10n = _l10n;
    final desktop = !phone;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: false,
      appBar: null,
      bottomNavigationBar: GlassNavShell(
        child: NavigationBar(
          selectedIndex: _navBarIndex,
          onDestinationSelected: _onNavBarSelected,
          height: desktop ? 74 : 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.school_outlined, key: const ValueKey('nav_learn')),
              selectedIcon:
                  Icon(Icons.school_rounded, key: const ValueKey('nav_learn')),
              label: l10n.tabLearn,
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, key: const ValueKey('nav_words')),
              selectedIcon: Icon(Icons.menu_book_rounded,
                  key: const ValueKey('nav_words')),
              label: l10n.tabWords,
            ),
            NavigationDestination(
              icon: Icon(Icons.pets_outlined, key: const ValueKey('nav_mascot')),
              selectedIcon:
                  Icon(Icons.pets_rounded, key: const ValueKey('nav_mascot')),
              label: l10n.tabMascot,
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded, key: const ValueKey('nav_more')),
              selectedIcon: Icon(Icons.more_horiz_rounded,
                  key: const ValueKey('nav_more')),
              label: l10n.tabMore,
            ),
          ],
        ),
      ),
      body: GradientScaffoldBody(
        palette: widget.palette,
        child: Stack(
          children: [
            SuccessBurst(animation: _burstCtrl),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final maxW = wide ? constraints.maxWidth : 720.0;
                final hPad = wide ? 32.0 : 20.0;
                final xpBar = _PlayerXpBar(
                  level: _store.stats.playerLevel,
                  xp: _store.stats.xp,
                  progress: _store.stats.levelProgress,
                  xpToNext: _store.stats.xpToNextLevel,
                  paws: _store.stats.goldenPaws,
                  title: titleForLevel(
                    _store.stats.playerLevel,
                    uiLang: widget.uiLang,
                  ).title,
                  audioEnabled: _audioEnabled,
                  onToggleAudio: () =>
                      _persistAudioEnabled(!_audioEnabled),
                  onTapAlbum: _openCuriosityAlbum,
                  desktop: desktop,
                  l10n: l10n,
                  versionLabel: desktop ? _appVersionLabel : null,
                );
                final mission = // —— NAUKA NA GÓRZE ——
                  DailyMissionBanner(
                    wordsToday: _store.stats.wordsToday,
                    dailyGoal: mascotDailyFeedGoal,
                    streakDays: _store.stats.streakDays,
                    palette: widget.palette,
                    title: l10n.learnWithPet(
                      _store.stats.mascotSpecies == MascotSpecies.dog,
                    ),
                    subtitle: l10n.feedPetSubtitle(
                      _store.stats.mascotSpecies == MascotSpecies.dog,
                    ),
                  );
                final stats = SoftPanel(
                    margin: EdgeInsets.zero,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HomeStatChip(
                          icon: Icons.pets_rounded,
                          label: l10n.pawsChip(_store.stats.goldenPaws),
                        ),
                        _HomeStatChip(
                          icon: Icons.menu_book_rounded,
                          label: l10n.wordsChip(_pack?.words.length ?? 0),
                        ),
                        _HomeStatChip(
                          icon: Icons.bolt_rounded,
                          label: l10n.sessionChip(
                            _store.stats.sessionCorrect,
                            _store.stats.sessionTotal,
                          ),
                        ),
                      ],
                    ),
                  );
                final treningFields = <Widget>[
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
                              InputDecoration(labelText: l10n.language),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.methodLabel,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        if (phone)
                          Row(
                            children: [
                              for (final entry in [
                                (GameMethod.abc, Icons.abc_rounded, l10n.methodAbc),
                                (GameMethod.typing, Icons.keyboard_rounded, l10n.methodTyping),
                                (GameMethod.sentences, Icons.chat_rounded, l10n.methodSentences),
                              ]) ...[
                                if (entry.$1 != GameMethod.abc) const SizedBox(width: 8),
                                Expanded(
                                  child: Material(
                                    color: _method == entry.$1
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .surface
                                            .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () async {
                                        setState(() => _method = entry.$1);
                                        await _persistMethod();
                                        _draw();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 4,
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              entry.$2,
                                              size: 22,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              entry.$3,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        else
                          SegmentedButton<GameMethod>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: GameMethod.abc,
                                icon: const Icon(Icons.abc_rounded, size: 18),
                                label: Text(l10n.methodAbc),
                              ),
                              ButtonSegment(
                                value: GameMethod.typing,
                                icon:
                                    const Icon(Icons.keyboard_rounded, size: 18),
                                label: Text(l10n.methodTyping),
                              ),
                              ButtonSegment(
                                value: GameMethod.sentences,
                                icon: const Icon(Icons.chat_rounded, size: 18),
                                label: Text(l10n.methodSentences),
                              ),
                            ],
                            selected: {_method},
                            onSelectionChanged: (s) async {
                              if (s.isEmpty) return;
                              setState(() => _method = s.first);
                              await _persistMethod();
                              _draw();
                            },
                          ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.poolWordsHint,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FilterChip(
                                  label: Text(l10n.poolAll),
                                  selected: _groupId == '__all__',
                                  onSelected: (_) {
                                    setState(() => _groupId = '__all__');
                                    _draw();
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FilterChip(
                                  label: Text(l10n.poolUnlearned),
                                  selected: _groupId == '__unlearned__',
                                  onSelected: (_) {
                                    setState(
                                      () => _groupId = '__unlearned__',
                                    );
                                    _draw();
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FilterChip(
                                  label: Text(l10n.poolHard),
                                  selected: _groupId == '__hard__',
                                  onSelected: (_) {
                                    setState(() => _groupId = '__hard__');
                                    _draw();
                                  },
                                ),
                              ),
                              if (pack != null)
                                for (final g in pack.groups)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: FilterChip(
                                      label: Text(g.name),
                                      selected: _groupId == g.id,
                                      onSelected: (_) {
                                        setState(() => _groupId = g.id);
                                        _draw();
                                      },
                                    ),
                                  ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: ActionChip(
                                  avatar: const Icon(Icons.add, size: 18),
                                  label: Text(l10n.newPool),
                                  onPressed: () =>
                                      _openGroups(openCreate: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_groupLabel()} · $mastered/${allInGroup.length} ($pct%)',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                ];
                final trening = SoftPanel(
                    child: phone
                        ? Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: _lessonSettingsOpen,
                              onExpansionChanged: (v) =>
                                  setState(() => _lessonSettingsOpen = v),
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(top: 4),
                              title: SectionHeader(
                                title: l10n.lessonSettings,
                                subtitle:
                                    '${_lang ?? "—"} · ${_groupLabel()}',
                                icon: Icons.tune_rounded,
                              ),
                              children: treningFields,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SectionHeader(
                                title: l10n.training,
                                subtitle: l10n.trainingSubtitle,
                                icon: Icons.school_rounded,
                              ),
                              ...treningFields,
                            ],
                          ),
                  );
                final akcje = SoftPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: l10n.quickActions,
                          subtitle: l10n.quickActionsSubtitle,
                          icon: Icons.bolt_rounded,
                        ),
                        ActionGrid(
                          children: [
                            ActionTile(
                              icon: Icons.add_rounded,
                              label: l10n.addWord,
                              onPressed: _addWord,
                            ),
                            ActionTile(
                              icon: Icons.upload_file_rounded,
                              label: l10n.importCsv,
                              onPressed: _importWordsSheet,
                            ),
                            ActionTile(
                              icon: Icons.edit_note_rounded,
                              label: l10n.list,
                              onPressed: _openWords,
                            ),
                            ActionTile(
                              icon: _poolReview
                                  ? Icons.replay_rounded
                                  : Icons.school_rounded,
                              label: _poolReview
                                  ? l10n.poolReview
                                  : l10n.poolLearn,
                              onPressed: () {
                                setState(() => _poolReview = !_poolReview);
                                _draw();
                              },
                              selected: !_poolReview,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _openDailyChat,
                            icon: Icon(
                              _store.stats.chatDoneToday
                                  ? Icons.chat_bubble_rounded
                                  : Icons.chat_bubble_outline_rounded,
                            ),
                            label: Text(
                              _store.stats.chatDoneToday
                                  ? l10n.aiChatDone
                                  : l10n.aiChat,
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ),
                        if (_current != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.center,
                            child: FilterChip(
                              selected: _current!.hard,
                              avatar: Icon(
                                _current!.hard
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _current!.hard ? l10n.hardOn : l10n.hardOff,
                              ),
                              onSelected: (_) async {
                                _current!.hard = !_current!.hard;
                                await _store.save();
                                _flash(
                                  _current!.hard
                                      ? l10n.hardMarked
                                      : l10n.hardCleared,
                                  kind: FeedbackKind.info,
                                );
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                final quiz = _current == null
                    ? SoftPanel(
                          child: Text(
                            pool.isEmpty && _poolReview
                                ? (_method == GameMethod.sentences
                                    ? l10n.noSentencesReview
                                    : l10n.noWordsReview)
                                : (_method == GameMethod.sentences
                                    ? l10n.noSentencesLearn
                                    : l10n.noWordsLearn),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        )
                    : Shake(
                          animation: _shakeCtrl,
                          child: SuccessPulse(
                            animation: _successCtrl,
                            child: SoftPanel(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: widget.palette.buttonGradient(
                                          Theme.of(context).brightness ==
                                              Brightness.light,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _promptLabel,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedPromptWord(
                                    text: _promptWord,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontSize: _method ==
                                                  GameMethod.sentences
                                              ? 22
                                              : null,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  EqualButtonRow(
                                    left: FilledButton.tonalIcon(
                                      onPressed: _audioEnabled
                                          ? () => _playText(_current!.obcy)
                                          : null,
                                      icon: Icon(
                                        _audioEnabled
                                            ? Icons.volume_up_rounded
                                            : Icons.volume_off_rounded,
                                      ),
                                      label: Text(
                                        _audioEnabled
                                            ? l10n.listen
                                            : l10n.narratorOff,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                      ),
                                    ),
                                    right: OutlinedButton.icon(
                                      onPressed:
                                          _hintShown ? null : _showHint,
                                      icon: const Icon(Icons.lightbulb_outline_rounded),
                                      label: Text(l10n.hint),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                      ),
                                    ),
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
                                      style: TextStyle(
                                        fontSize: _method == GameMethod.sentences
                                            ? 18
                                            : 22,
                                      ),
                                      maxLines: _method == GameMethod.sentences
                                          ? 3
                                          : 1,
                                      decoration: InputDecoration(
                                        hintText: _method == GameMethod.sentences
                                            ? l10n.sentenceHint
                                            : l10n.wordHint,
                                      ),
                                      onSubmitted: (_) => _checkTyping(),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 12),
                                    GradientButton(
                                      onPressed: _checkTyping,
                                      label: l10n.check,
                                      palette: widget.palette,
                                    ),
                                    _keyboard(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                final mascotHeader = SoftPanel(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pets_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.mascotHeader,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  );
                final mascot = MascotCard(
                    playerLevel: _store.stats.playerLevel,
                    wordsToday: _store.stats.wordsToday,
                    fedToday: _store.stats.mascotFedToday,
                    unlockedIds: _store.stats.unlockedMascotIds,
                    equipped: _store.stats.equippedMascot,
                    placedHome: _store.stats.placedHome,
                    goldenPaws: _store.stats.goldenPaws,
                    species: _store.stats.mascotSpecies,
                    furColor: Color(_store.stats.mascotColorArgb),
                    l10n: l10n,
                    onTapWardrobe: _openWardrobe,
                    onTapShop: _openShop,
                    onEquip: _equipMascot,
                    onSpeciesChanged: (s) async {
                      setState(() => _store.stats.mascotSpecies = s);
                      await _store.save();
                    },
                    onColorChanged: (c) async {
                      setState(
                        () => _store.stats.mascotColorArgb = c.toARGB32(),
                      );
                      await _store.save();
                    },
                  );
                final naukaList = ListView(
                  padding: EdgeInsets.fromLTRB(hPad, phone ? 12 : 20, hPad, 96),
                  children: [
                    mission,
                    const SizedBox(height: 12),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                trening,
                                const SizedBox(height: 14),
                                akcje,
                                const SizedBox(height: 14),
                                stats,
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: quiz,
                          ),
                        ],
                      )
                    else ...[
                      // Telefon: quiz od razu, potem ustawienia lekcji / akcje
                      quiz,
                      const SizedBox(height: 12),
                      trening,
                      const SizedBox(height: 12),
                      stats,
                      const SizedBox(height: 12),
                      akcje,
                    ],
                  ],
                );
                final mascotList = ListView(
                  padding: EdgeInsets.fromLTRB(hPad, phone ? 12 : 20, hPad, 96),
                  children: [
                    mascotHeader,
                    const SizedBox(height: 8),
                    mascot,
                  ],
                );
                final tabNeedLang = Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.pickLangFirst,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
                return Column(
                  children: [
                    SafeArea(bottom: false, child: xpBar),
                    Expanded(
                      child: IndexedStack(
                        index: _bottomNav.clamp(0, 5),
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxW),
                              child: naukaList,
                            ),
                          ),
                          pack != null && _lang != null
                              ? WordsPage(
                                  lang: _lang!,
                                  pack: pack,
                                  palette: widget.palette,
                                  uiLang: widget.uiLang,
                                  embedded: true,
                                  onChanged: () async {
                                    await _store.save();
                                    setState(() {});
                                  },
                                )
                              : tabNeedLang,
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxW),
                              child: mascotList,
                            ),
                          ),
                          ShopPage(
                            stats: _store.stats,
                            palette: widget.palette,
                            uiLang: widget.uiLang,
                            embedded: true,
                            onChanged: () async {
                              await _store.save();
                              if (mounted) setState(() {});
                            },
                          ),
                          pack != null && _lang != null
                              ? GroupsPage(
                                  lang: _lang!,
                                  pack: pack,
                                  selectedId: _groupId,
                                  palette: widget.palette,
                                  uiLang: widget.uiLang,
                                  embedded: true,
                                  onChanged: () async {
                                    await _store.save();
                                    setState(() {});
                                  },
                                  onSelect: (id) {
                                    setState(() {
                                      _groupId = id;
                                      _bottomNav = 0;
                                    });
                                    _draw();
                                  },
                                )
                              : tabNeedLang,
                          _PhoneSettingsTab(
                            themeMode: widget.themeMode,
                            palette: widget.palette,
                            uiLang: widget.uiLang,
                            audioEnabled: _audioEnabled,
                            playbackRate: _playbackRate,
                            translateDir: _dir,
                            importCtrl: _importCtrl,
                            audioStatusText: () {
                              final miss = _store.missingAudioKeys();
                              return miss.isEmpty
                                  ? l10n.audioComplete(_store.baza.values
                                      .fold<int>(0, (n, p) => n + p.words.length))
                                  : l10n.audioMissing(miss.length);
                            }(),
                            l10n: l10n,
                            onThemeModeChanged: widget.onThemeModeChanged,
                            onPaletteChanged: widget.onPaletteChanged,
                            onUiLangChanged: widget.onUiLangChanged,
                            onTranslateDirChanged: _persistDir,
                            onAudioEnabledChanged: _persistAudioEnabled,
                            onPlaybackRateChanged: _persistRate,
                            onOpenAlbum: _openCuriosityAlbum,
                            onExportDb: () async {
                              final path = await _store.exportToDocuments();
                              _flash(
                                l10n.exported(path),
                                kind: FeedbackKind.info,
                                ms: 4000,
                              );
                            },
                            onImportDb: () async {
                              final err = await _store
                                  .importFromPath(_importCtrl.text.trim());
                              if (err != null) {
                                _flash(err, kind: FeedbackKind.fail, ms: 3000);
                              } else {
                                setState(() {});
                                _draw();
                                _flash(
                                  l10n.importedDb,
                                  kind: FeedbackKind.success,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_banner != null)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final maxW = c.maxWidth >= 980 ? c.maxWidth : 720.0;
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: Material(
                            type: MaterialType.transparency,
                            child: AnimatedFeedbackBanner(
                              message: _banner!,
                              kind: _bannerKind,
                              visible: _bannerVisible,
                              onDismiss: () => setState(() {
                                _bannerVisible = false;
                                _banner = null;
                              }),
                            ),
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

/// Pasek EXP / LVL na górze — jak pasek postępu w Duolingo (telefon i komputer).
class _PlayerXpBar extends StatelessWidget {
  const _PlayerXpBar({
    required this.level,
    required this.xp,
    required this.progress,
    required this.xpToNext,
    required this.paws,
    required this.title,
    required this.audioEnabled,
    required this.onToggleAudio,
    required this.onTapAlbum,
    required this.l10n,
    this.desktop = false,
    this.versionLabel,
  });

  final int level;
  final int xp;
  final double progress;
  final int xpToNext;
  final int paws;
  final String title;
  final bool audioEnabled;
  final VoidCallback onToggleAudio;
  final VoidCallback onTapAlbum;
  final L10n l10n;
  final bool desktop;
  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lvlBadge = InkWell(
      onTap: onTapAlbum,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 14 : 10,
          vertical: desktop ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.military_tech_rounded,
                size: desktop ? 22 : 18, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              '${l10n.levelShort} $level',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
                fontSize: desktop ? 15 : 13,
              ),
            ),
          ],
        ),
      ),
    );
    final xpColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: desktop ? 14 : null,
                    ),
              ),
            ),
            Text(
              '$xp XP',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    fontSize: desktop ? 13 : null,
                  ),
            ),
          ],
        ),
        SizedBox(height: desktop ? 6 : 4),
        SheenProgressBar(
          value: progress.clamp(0.0, 1.0),
          minHeight: desktop ? 10 : 8,
        ),
        const SizedBox(height: 2),
        Text(
          l10n.xpToNext(level + 1, xpToNext),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.55),
                fontSize: desktop ? 11 : 10,
              ),
        ),
      ],
    );
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (versionLabel != null) ...[
          Text(
            versionLabel!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
          const SizedBox(width: 8),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '🐾 $paws',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: desktop ? 16 : null,
                ),
          ),
        ),
        IconButton(
          tooltip: audioEnabled ? l10n.disableNarrator : l10n.enableNarrator,
          onPressed: onToggleAudio,
          icon: Icon(
            audioEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
          ),
        ),
      ],
    );

    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          desktop ? 24 : 14,
          desktop ? 12 : 8,
          desktop ? 16 : 8,
          desktop ? 14 : 10,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 1400 : double.infinity),
          child: desktop
              ? Row(
                  children: [
                    lvlBadge,
                    const SizedBox(width: 16),
                    Expanded(child: xpColumn),
                    const SizedBox(width: 10),
                    trailing,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        lvlBadge,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        trailing,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '$xp XP',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SheenProgressBar(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.xpToNext(level + 1, xpToNext),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.55),
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Zakładka Ustawienia (telefon i komputer).
class _PhoneSettingsTab extends StatefulWidget {
  const _PhoneSettingsTab({
    required this.themeMode,
    required this.palette,
    required this.uiLang,
    required this.audioEnabled,
    required this.playbackRate,
    required this.translateDir,
    required this.importCtrl,
    required this.audioStatusText,
    required this.l10n,
    required this.onThemeModeChanged,
    required this.onPaletteChanged,
    required this.onUiLangChanged,
    required this.onTranslateDirChanged,
    required this.onAudioEnabledChanged,
    required this.onPlaybackRateChanged,
    required this.onOpenAlbum,
    required this.onExportDb,
    required this.onImportDb,
  });

  final ThemeMode themeMode;
  final AppPalette palette;
  final UiLang uiLang;
  final bool audioEnabled;
  final double playbackRate;
  final TranslateDir translateDir;
  final TextEditingController importCtrl;
  final String audioStatusText;
  final L10n l10n;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPalette> onPaletteChanged;
  final ValueChanged<UiLang> onUiLangChanged;
  final ValueChanged<TranslateDir> onTranslateDirChanged;
  final ValueChanged<bool> onAudioEnabledChanged;
  final ValueChanged<double> onPlaybackRateChanged;
  final VoidCallback onOpenAlbum;
  final Future<void> Function() onExportDb;
  final Future<void> Function() onImportDb;

  @override
  State<_PhoneSettingsTab> createState() => _PhoneSettingsTabState();
}

class _PhoneSettingsTabState extends State<_PhoneSettingsTab> {
  final _ollamaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadOllamaHostPref().then((host) {
      if (mounted) _ollamaCtrl.text = host;
    });
  }

  @override
  void dispose() {
    _ollamaCtrl.dispose();
    super.dispose();
  }

  L10n get l10n => widget.l10n;

  @override
  Widget build(BuildContext context) {
    final dirHint = switch (widget.translateDir) {
      TranslateDir.plToForeign => l10n.dirHintPlToForeign,
      TranslateDir.foreignToPl => l10n.dirHintForeignToPl,
      TranslateDir.mixed => l10n.dirHintMixed,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(l10n.settings, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(l10n.appLanguage, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ul in UiLang.values)
              ChoiceChip(
                label: Text(ul.nativeLabel),
                selected: widget.uiLang == ul,
                onSelected: (_) => widget.onUiLangChanged(ul),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.theme, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.themeSystem),
              selected: widget.themeMode == ThemeMode.system,
              onSelected: (_) => widget.onThemeModeChanged(ThemeMode.system),
            ),
            ChoiceChip(
              label: Text(l10n.themeLight),
              selected: widget.themeMode == ThemeMode.light,
              onSelected: (_) => widget.onThemeModeChanged(ThemeMode.light),
            ),
            ChoiceChip(
              label: Text(l10n.themeDark),
              selected: widget.themeMode == ThemeMode.dark,
              onSelected: (_) => widget.onThemeModeChanged(ThemeMode.dark),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.colors, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in AppPalette.values)
              FilterChip(
                avatar: CircleAvatar(backgroundColor: p.seed),
                label: Text(l10n.paletteLabel(p.name)),
                selected: widget.palette == p,
                onSelected: (_) => widget.onPaletteChanged(p),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.translateDir, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.dirPlToForeign),
              selected: widget.translateDir == TranslateDir.plToForeign,
              onSelected: (_) =>
                  widget.onTranslateDirChanged(TranslateDir.plToForeign),
            ),
            ChoiceChip(
              label: Text(l10n.dirForeignToPl),
              selected: widget.translateDir == TranslateDir.foreignToPl,
              onSelected: (_) =>
                  widget.onTranslateDirChanged(TranslateDir.foreignToPl),
            ),
            ChoiceChip(
              label: Text(l10n.dirMixed),
              selected: widget.translateDir == TranslateDir.mixed,
              onSelected: (_) =>
                  widget.onTranslateDirChanged(TranslateDir.mixed),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(dirHint, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 16),
        Text(l10n.narrator, style: Theme.of(context).textTheme.titleSmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.enableNarrator),
          subtitle: Text(
            widget.audioEnabled ? l10n.narratorOnSub : l10n.narratorOffSub,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: widget.audioEnabled,
          onChanged: widget.onAudioEnabledChanged,
        ),
        Text(l10n.audioTempo, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final r in [0.75, 1.0, 1.25])
              ChoiceChip(
                label: Text('${r}x'),
                selected: (widget.playbackRate - r).abs() < 0.01,
                onSelected: widget.audioEnabled
                    ? (_) => widget.onPlaybackRateChanged(r)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_stories_rounded),
          title: Text(l10n.album),
          onTap: widget.onOpenAlbum,
        ),
        const SizedBox(height: 8),
        Text(l10n.onDeviceAi, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(l10n.onDeviceAiBlurb, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        TextField(
          controller: _ollamaCtrl,
          decoration: InputDecoration(
            labelText: l10n.ollamaAddress,
            hintText: 'http://127.0.0.1:11434',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () async {
            await saveOllamaHostPref(_ollamaCtrl.text);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.aiAddressSaved)),
            );
          },
          child: Text(l10n.saveAiAddress),
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () => widget.onExportDb(),
          child: Text(l10n.exportDb),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.importCtrl,
          decoration: InputDecoration(
            labelText: l10n.importJsonPath,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => widget.onImportDb(),
          child: Text(l10n.importFromFile),
        ),
        const SizedBox(height: 12),
        Text(
          widget.audioStatusText,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          _appVersionLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
              ),
        ),
      ],
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
    required this.uiLang,
    required this.onChanged,
    required this.onSelect,
    this.openCreateOnStart = false,
    this.embedded = false,
  });

  final String lang;
  final LangPack pack;
  final String selectedId;
  final AppPalette palette;
  final UiLang uiLang;
  final VoidCallback onChanged;
  final ValueChanged<String> onSelect;
  final bool openCreateOnStart;
  final bool embedded;

  L10n get l10n => L10n(uiLang);

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
    if (widget.openCreateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _createGroup();
      });
    }
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
                      decoration: InputDecoration(
                        labelText: widget.l10n.poolName,
                        hintText: widget.l10n.poolNameHint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: filterCtrl,
                      onChanged: (v) => setLocal(() => query = v),
                      decoration: InputDecoration(
                        labelText: widget.l10n.searchWord,
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
                      widget.l10n.selectedVisible(selected.length, filtered.length),
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.l10n.selectWordsHint,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SoftPanel(
                        margin: EdgeInsets.zero,
                        padding: EdgeInsets.zero,
                        child: filtered.isEmpty
                            ? Center(child: Text(widget.l10n.noWords))
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
                              child: Text(widget.l10n.deletePool),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(widget.l10n.save),
                            ),
                          ),
                        ],
                      )
                    else
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          selected.isEmpty
                              ? widget.l10n.createPoolPick
                              : widget.l10n.createPoolN(selected.length),
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
      title: widget.l10n.newWordPool,
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
        SnackBar(content: Text(widget.l10n.enterPoolName)),
      );
      return;
    }
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.selectAtLeastOne)),
      );
      return;
    }
    final id = 'g-${DateTime.now().millisecondsSinceEpoch}';
    widget.pack.groups.add(
      WordGroup(
        id: id,
        name: name,
        wordIds: selected.toList(),
      ),
    );
    _selected = id;
    widget.onSelect(id);
    widget.onChanged();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.poolCreated(name))),
      );
    }
  }

  Future<void> _editGroup(WordGroup g) async {
    final selected = g.wordIds.toSet();
    final nameCtrl = TextEditingController(text: g.name);
    _editingGroupId = g.id;
    final ok = await _pickWords(
      title: widget.l10n.editPool,
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
    final body = GradientScaffoldBody(
        palette: widget.palette,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                widget.l10n.poolsIntro,
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
                      widget.l10n.quickPick,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  _tile(
                    id: '__all__',
                    title: widget.l10n.poolAll,
                    subtitle: widget.l10n.wordsCountShort(widget.pack.words.length),
                    preview: _previewFor(
                      widget.pack.words.take(6).map((w) => w.id).toList(),
                    ),
                  ),
                  const Divider(height: 1),
                  _tile(
                    id: '__unlearned__',
                    title: widget.l10n.poolUnlearned,
                    subtitle: widget.l10n.wordsCountShort(
                        widget.pack.words.where((w) => w.level < 3).length),
                  ),
                  const Divider(height: 1),
                  _tile(
                    id: '__hard__',
                    title: widget.l10n.poolHard,
                    subtitle: widget.l10n.wordsCountShort(
                        widget.pack.words.where((w) => w.hard || w.level <= 1).length),
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
                          ? widget.l10n.yourPoolsEmpty
                          : widget.l10n.yourPoolsN(widget.pack.groups.length),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (widget.pack.groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Text(widget.l10n.yourPoolsHint),
                    )
                  else
                    for (final g in widget.pack.groups) ...[
                      _tile(
                        id: g.id,
                        title: g.name,
                        subtitle: widget.l10n.wordsCountShort(g.wordIds.length),
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
      );
    final fab = FloatingActionButton.extended(
      onPressed: _createGroup,
      icon: const Icon(Icons.add),
      label: Text(widget.l10n.newPool),
    );
    if (widget.embedded) {
      return Stack(
        children: [
          body,
          Positioned(right: 16, bottom: 16, child: fab),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.l10n.wordPoolsTitle(widget.lang)),
        actions: [
          IconButton(
            onPressed: _createGroup,
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: widget.l10n.newPool,
          ),
        ],
      ),
      floatingActionButton: fab,
      body: body,
    );
  }
}

class WordsPage extends StatefulWidget {
  const WordsPage({
    super.key,
    required this.lang,
    required this.pack,
    required this.palette,
    required this.uiLang,
    required this.onChanged,
    this.embedded = false,
  });

  final String lang;
  final LangPack pack;
  final AppPalette palette;
  final UiLang uiLang;
  final VoidCallback onChanged;
  final bool embedded;

  L10n get l10n => L10n(uiLang);

  @override
  State<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends State<WordsPage> {
  final _filterCtrl = TextEditingController();
  final _categoryScroll = ScrollController();
  String _query = '';
  String? _categoryFilter; // null = wszystkie
  bool _canScrollCategoriesLeft = false;
  bool _canScrollCategoriesRight = false;

  @override
  void initState() {
    super.initState();
    _categoryScroll.addListener(_updateCategoryArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCategoryArrows());
  }

  void _updateCategoryArrows() {
    if (!_categoryScroll.hasClients) return;
    final max = _categoryScroll.position.maxScrollExtent;
    final offset = _categoryScroll.offset;
    final canLeft = max > 8 && offset > 8;
    final canRight = max > 8 && offset < max - 8;
    if (canLeft != _canScrollCategoriesLeft ||
        canRight != _canScrollCategoriesRight) {
      setState(() {
        _canScrollCategoriesLeft = canLeft;
        _canScrollCategoriesRight = canRight;
      });
    }
  }

  void _scrollCategoriesBy(double delta) {
    if (!_categoryScroll.hasClients) return;
    final next = (_categoryScroll.offset + delta)
        .clamp(0.0, _categoryScroll.position.maxScrollExtent);
    _categoryScroll.animateTo(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _categoryArrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 16),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _categoryScroll.removeListener(_updateCategoryArrows);
    _categoryScroll.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteWord(Word w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.l10n.deleteWordConfirm),
        content: Text('${w.pl} → ${w.obcy}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.l10n.delete),
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
              Text(widget.l10n.editWord, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: plCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: widget.l10n.inPolish),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: obcyCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: widget.l10n.translation),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(widget.l10n.save),
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
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(widget.l10n.wordsTitle(widget.lang)),
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
                  labelText: widget.l10n.search,
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
            if (widget.pack.groups.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  widget.l10n.category,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    // Strzałki przy pierwszej karcie — w lewo i w prawo.
                    if (_canScrollCategoriesLeft || _canScrollCategoriesRight)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_canScrollCategoriesLeft)
                              _categoryArrowButton(
                                icon: Icons.arrow_back_ios_new,
                                onTap: () => _scrollCategoriesBy(-140),
                              ),
                            if (_canScrollCategoriesRight)
                              _categoryArrowButton(
                                icon: Icons.arrow_forward_ios,
                                onTap: () => _scrollCategoriesBy(140),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: NotificationListener<ScrollMetricsNotification>(
                        onNotification: (_) {
                          _updateCategoryArrows();
                          return false;
                        },
                        child: ListView(
                          controller: _categoryScroll,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 8, right: 12),
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(widget.l10n.all),
                                selected: _categoryFilter == null,
                                onSelected: (_) =>
                                    setState(() => _categoryFilter = null),
                              ),
                            ),
                            for (final g in widget.pack.groups)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FilterChip(
                                  label: Text(g.name),
                                  selected: _categoryFilter == g.id,
                                  onSelected: (_) => setState(
                                    () => _categoryFilter =
                                        _categoryFilter == g.id
                                            ? null
                                            : g.id,
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
            ],
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
                    ? Center(child: Text(widget.l10n.noWords))
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
                                    tooltip: widget.l10n.edit,
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editWord(w),
                                  ),
                                  IconButton(
                                    tooltip: widget.l10n.delete,
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

/// Sklep Kici — ekskluzywne ubranka + miski, posłanie (złote łapki).
class ShopPage extends StatefulWidget {
  const ShopPage({
    super.key,
    required this.stats,
    required this.palette,
    required this.uiLang,
    required this.onChanged,
    this.embedded = false,
  });

  final AppStats stats;
  final AppPalette palette;
  final UiLang uiLang;
  final VoidCallback onChanged;
  final bool embedded;

  L10n get l10n => L10n(uiLang);

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _buyOutfit(MascotItem item) async {
    final err = widget.stats.buyOutfit(item);
    if (err != null) {
      _toast(err);
      return;
    }
    widget.onChanged();
    setState(() {});
    _toast(widget.l10n.bought(item.name));
  }

  Future<void> _buyHome(HomeItem item) async {
    final err = widget.stats.buyHomeItem(item);
    if (err != null) {
      _toast(err);
      return;
    }
    widget.onChanged();
    setState(() {});
    _toast(widget.l10n.bought(item.name));
  }

  @override
  Widget build(BuildContext context) {
    final outfits = shopExclusiveOutfits();
    final paws = widget.stats.goldenPaws;
    final petName = widget.l10n.petName(
      widget.stats.mascotSpecies == MascotSpecies.dog,
    );
    final tabBar = TabBar(
      controller: _tabs,
      tabs: [
        Tab(text: widget.l10n.clothesTab, icon: const Icon(Icons.checkroom_outlined)),
        Tab(text: widget.l10n.roomTab, icon: const Icon(Icons.home_outlined)),
      ],
    );
    final content = Column(
          children: [
            if (widget.embedded) ...[
              Material(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.9),
                child: tabBar,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '🐾 $paws',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SoftPanel(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    Mascot3dOrFallback(
                      isDog: widget.stats.mascotSpecies == MascotSpecies.dog,
                      size: 150,
                      fallback: DressedKicia(
                        equipped: widget.stats.equippedMascot,
                        placedHome: widget.stats.placedHome,
                        species: widget.stats.mascotSpecies,
                        furColor: Color(widget.stats.mascotColorArgb),
                        size: 150,
                      ),
                      onTapOpenPreview: () {
                        final id = mascotGlbId(
                          isDog:
                              widget.stats.mascotSpecies == MascotSpecies.dog,
                        );
                        final path = glbAssetForId(id);
                        if (path == null) return;
                        openModel3dPreview(
                          context,
                          assetPath: path,
                          title: petName,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.l10n.shopBlurbFull(
                        perCorrect: pawsPerCorrect,
                        feedBonus: pawsFeedBonus,
                        pet: petName,
                        perLevel: pawsPerLevelUp,
                        dailyChat: pawsDailyChat,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: outfits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final item = outfits[i];
                      final owned =
                          widget.stats.unlockedMascotIds.contains(item.id);
                      final price = item.shopPrice ?? 0;
                      final equipped =
                          widget.stats.equippedMascot[item.slot.name] ==
                              item.id;
                      return SoftPanel(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              OutfitThumb(item: item, size: 56),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: widget.l10n.preview3d,
                                onPressed: () {
                                  final path = glbAssetForId(item.id);
                                  if (path == null) return;
                                  openModel3dPreview(
                                    context,
                                    assetPath: path,
                                    title: item.name,
                                  );
                                },
                                icon: const Icon(Icons.view_in_ar_outlined),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${slotLabel(item.slot)} · ${item.blurb}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              owned
                                  ? FilledButton.tonal(
                                      onPressed: () async {
                                        widget.stats.toggleEquipMascot(item);
                                        widget.onChanged();
                                        setState(() {});
                                      },
                                      child: Text(equipped ? widget.l10n.unequip : widget.l10n.equip),
                                    )
                                  : FilledButton(
                                      onPressed: paws >= price
                                          ? () => _buyOutfit(item)
                                          : null,
                                      child: Text('$price 🐾'),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: mascotHomeShop.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final item = mascotHomeShop[i];
                      final owned =
                          widget.stats.ownedHomeIds.contains(item.id);
                      final placed =
                          widget.stats.placedHome[item.slot.name] == item.id;
                      return SoftPanel(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: HomeItemArt(item: item, size: 52),
                                ),
                              ),
                              IconButton(
                                tooltip: widget.l10n.preview3d,
                                onPressed: () {
                                  final path = glbAssetForId(item.id);
                                  if (path == null) return;
                                  openModel3dPreview(
                                    context,
                                    assetPath: path,
                                    title: item.name,
                                  );
                                },
                                icon: const Icon(Icons.view_in_ar_outlined),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${homeSlotLabel(item.slot)} · ${item.blurb}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              owned
                                  ? FilledButton.tonal(
                                      onPressed: () {
                                        widget.stats.togglePlaceHome(item);
                                        widget.onChanged();
                                        setState(() {});
                                      },
                                      child: Text(placed ? widget.l10n.hideItem : widget.l10n.showItem),
                                    )
                                  : FilledButton(
                                      onPressed: paws >= item.price
                                          ? () => _buyHome(item)
                                          : null,
                                      child: Text('${item.price} 🐾'),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
    final wrapped = GradientScaffoldBody(
      palette: widget.palette,
      child: content,
    );
    if (widget.embedded) return wrapped;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.l10n.shopTitle(petName)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '🐾 $paws',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: tabBar.preferredSize,
          child: tabBar,
        ),
      ),
      body: wrapped,
    );
  }
}

/// Mały chip ze statystyką na ekranie głównym.
class _HomeStatChip extends StatelessWidget {
  const _HomeStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.95),
            scheme.tertiaryContainer.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}
