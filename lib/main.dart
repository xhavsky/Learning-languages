import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_chat.dart';
import 'curiosities.dart';
import 'import_csv.dart';
import 'mascot.dart';
import 'model3d_viewer.dart';
import 'models.dart';
import 'portal.dart';
import 'storage.dart';
import 'theme.dart';
import 'ui_fx.dart';

void _bootLog(String msg) {
  try {
    final home = Platform.environment['HOME'] ?? '';
    final f = File('$home/Dokumenty/trener-boot.log');
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
  AppPalette _palette = AppPalette.mint;

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
  String _loadingMsg = 'Startuję…';
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
    _bootLog('_boot start');
    try {
      if (!mounted) return;
      setState(() {
        _bootError = null;
        _loadingMsg = 'Ładuję ustawienia…';
      });
      _bootLog('_boot: loading portal');
      final portal = await PortalInfo.load().timeout(
        const Duration(seconds: 8),
        onTimeout: () => PortalInfo.fallback,
      );
      _bootLog('_boot: portal ok');
      if (!mounted) return;
      setState(() => _loadingMsg = 'Ładuję bazę słówek i postępy…');
      _bootLog('_boot: loading baza');
      await _store.load().timeout(const Duration(seconds: 20));
      _bootLog('_boot: baza ok keys=${_store.baza.keys.length}');
      final lang = _store.baza.containsKey('Angielski')
          ? 'Angielski'
          : (_store.baza.keys.isNotEmpty ? _store.baza.keys.first : null);
      if (!mounted) return;
      setState(() {
        _portal = portal;
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
        _loadingMsg = 'Nie udało się uruchomić';
      });
    }
  }

  Future<void> _retryBoot() async {
    setState(() {
      _loading = true;
      _bootError = null;
      _loadingMsg = 'Ponawiam start…';
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
      setState(() => _audioHint = 'Audio niedostępne: $e');
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
    final justFed = _store.stats.recordAnswer(ok);
    await _store.save();
    if (ok) {
      var msg = w.nauczone
          ? 'Nauczone! ✓ (3× z rzędu)'
          : 'Brawo! ✓ (${w.correctStreak}/3)';
      if (justFed) {
        msg = '$msg · Kicia najedzona! 🐱 +$pawsFeedBonus 🐾';
      } else {
        msg = '$msg · +$pawsPerCorrect 🐾';
      }
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

  /// Po awansie poziomu: tytuł + ciekawostka + ubranko Kici + bonus XP.
  Future<void> _maybeShowLevelRewards() async {
    final pending = _store.stats.pendingRewardLevels();
    if (pending.isEmpty) return;
    var bonusTotal = 0;
    for (final lv in pending) {
      final fact = curiosityForLevel(lv, lang: _lang);
      final bonus = levelUpBonusXpFor(lv);
      final unlockedTitle = newTitleAtLevel(lv);
      final rank = titleForLevel(lv);
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
                  'Nagroda: +$bonus XP · +$pawsPerLevelUp 🐾',
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
                              'Losowe ubranko: ${outfit.name}!',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(outfit.blurb),
                            Text(
                              'Załóż je w garderobie 👗',
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopPage(
          stats: _store.stats,
          palette: widget.palette,
          onChanged: () async {
            await _store.save();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    if (mounted) setState(() {});
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
                      'Garderoba ${mascotName(_store.stats.mascotSpecies)}',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Za każdy poziom losujesz nowe ubranko. '
                      'Ekskluzywne ciuchy, miski i posłanie — w sklepie za złote łapki 🐾. '
                      'Stuknij, żeby ubrać (1 rzecz na slot). '
                      'Nakarm min. $mascotDailyFeedGoal słówkami dziennie!',
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
                                        ? '🛒 Tylko w sklepie · ${item.shopPrice} 🐾'
                                        : '🔒 Jeszcze nie wylosowane',
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
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Jeszcze nic nie odblokowano — ćwicz do poziomu 2!',
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

  Future<void> _openGroups({bool openCreate = false}) async {
    final pack = _pack;
    if (pack == null || _lang == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupsPage(
          lang: _lang!,
          pack: pack,
          selectedId: _groupId,
          palette: widget.palette,
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
                      'Lektor (audio)',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Włącz lektora'),
                      subtitle: Text(
                        _audioEnabled
                            ? 'Słówka są odczytywane na głos.'
                            : 'Audio wyłączone — ćwiczysz w ciszy.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      value: _audioEnabled,
                      onChanged: (v) async {
                        await _persistAudioEnabled(v);
                        setSheet(() {});
                      },
                    ),
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
                            onSelected: _audioEnabled
                                ? (_) async {
                                    await _persistRate(r);
                                    setSheet(() {});
                                  }
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI na urządzeniu',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Czat: na PC pełny Bielik 11B v3 (Ollama w paczce lub systemowa), '
                      'na telefonie Bielik 1.5B v3 (GGUF). Bez portalu i chmury. '
                      'Host Ollamy — zwykle pusto (127.0.0.1).',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ollamaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Adres Ollamy (opcjonalnie)',
                        hintText: 'http://127.0.0.1:11434',
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
                const Text(
                  'Nie udało się wczytać aplikacji',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                const Text(
                  'Częsty powód: stara wersja apki + nowy plik bazy.\n'
                  'Spróbuj ponowić albo zaktualizuj pakiet (nrs / flutter run).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _retryBoot,
                  child: const Text('Spróbuj ponownie'),
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
        backgroundColor: const Color(0xFF1A1A22),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFB8F27A)),
                const SizedBox(height: 20),
                const Text(
                  'Startuję Trener Językowy…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadingMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
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

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Trener Językowy'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: Text(
                'v0.0.17',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                    ),
              ),
            ),
          ),
          ToolbarIconButton(
            tooltip: _audioEnabled ? 'Wyłącz lektora' : 'Włącz lektora',
            onPressed: () => _persistAudioEnabled(!_audioEnabled),
            active: _audioEnabled,
            icon: _audioEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
          ),
          ToolbarIconButton(
            tooltip: 'Sklep',
            onPressed: _openShop,
            icon: Icons.storefront_rounded,
          ),
          ToolbarIconButton(
            tooltip: 'Pule słówek',
            onPressed: _openGroups,
            icon: Icons.folder_special_rounded,
          ),
          ToolbarIconButton(
            tooltip: 'Słówka',
            onPressed: _openWords,
            icon: Icons.menu_book_rounded,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ToolbarIconButton(
              tooltip: 'Ustawienia',
              onPressed: _openSettings,
              icon: Icons.palette_rounded,
            ),
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
                    // —— NAUKA NA GÓRZE ——
                    DailyMissionBanner(
                      wordsToday: _store.stats.wordsToday,
                      dailyGoal: mascotDailyFeedGoal,
                      streakDays: _store.stats.streakDays,
                      palette: widget.palette,
                      title: _store.stats.mascotSpecies == MascotSpecies.dog
                          ? 'Czas na naukę z Pieskiem!'
                          : 'Czas na naukę z Kicią!',
                      subtitle: _store.stats.mascotSpecies == MascotSpecies.dog
                          ? 'Każde słówko karmi Twojego Pieska'
                          : 'Każde słówko karmi Twoją Kicię',
                    ),
                    SoftPanel(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HomeStatChip(
                            icon: Icons.military_tech_rounded,
                            label: 'Poziom ${_store.stats.playerLevel}',
                          ),
                          _HomeStatChip(
                            icon: Icons.pets_rounded,
                            label: '${_store.stats.goldenPaws} łapek',
                          ),
                          _HomeStatChip(
                            icon: Icons.menu_book_rounded,
                            label: '${_pack?.words.length ?? 0} słówek',
                          ),
                          _HomeStatChip(
                            icon: Icons.bolt_rounded,
                            label:
                                'Sesja ${_store.stats.sessionCorrect}/${_store.stats.sessionTotal}',
                          ),
                        ],
                      ),
                    ),
                    SoftPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(
                            title: 'Trening',
                            subtitle: 'Wybierz język, pulę i metodę',
                            icon: Icons.school_rounded,
                          ),
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
                            'Pula słówek (przesuń → albo utwórz własną)',
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
                                    label: const Text('Cała baza'),
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
                                    label: const Text('Nieopanowane'),
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
                                    label: const Text('Trudne'),
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
                                    label: const Text('Nowa pula'),
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
                    SoftPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(
                            title: 'Szybkie akcje',
                            subtitle: 'Dodawaj, ćwicz i gaduś z AI',
                            icon: Icons.bolt_rounded,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _addWord,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Słowo'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _importWordsSheet,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Import CSV'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _openWords,
                                icon: const Icon(Icons.edit_note_rounded),
                                label: const Text('Lista'),
                              ),
                              FilledButton.icon(
                                onPressed: _openDailyChat,
                                icon: Icon(
                                  _store.stats.chatDoneToday
                                      ? Icons.chat_bubble_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                ),
                                label: Text(
                                  _store.stats.chatDoneToday
                                      ? 'Rozmowa ✓'
                                      : 'AI na urządzeniu',
                                ),
                              ),
                              FilterChip(
                                selected: _method == GameMethod.abc,
                                avatar: Icon(
                                  _method == GameMethod.abc
                                      ? Icons.abc_rounded
                                      : Icons.keyboard_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _method == GameMethod.abc
                                      ? 'Metoda: ABC'
                                      : 'Metoda: Pisanie',
                                ),
                                onSelected: (_) async {
                                  setState(() {
                                    _method = _method == GameMethod.abc
                                        ? GameMethod.typing
                                        : GameMethod.abc;
                                  });
                                  await _persistMethod();
                                  _draw();
                                },
                              ),
                              FilterChip(
                                selected: !_poolReview,
                                avatar: Icon(
                                  _poolReview
                                      ? Icons.replay_rounded
                                      : Icons.school_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _poolReview ? 'Pula: Powtórka' : 'Pula: Nauka',
                                ),
                                onSelected: (_) {
                                  setState(() => _poolReview = !_poolReview);
                                  _draw();
                                },
                              ),
                              if (_current != null)
                                FilterChip(
                                  selected: _current!.hard,
                                  avatar: Icon(
                                    _current!.hard
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _current!.hard ? 'Trudne ★' : 'Trudne?',
                                  ),
                                  onSelected: (_) async {
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
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_current == null)
                      SoftPanel(
                        child: Text(
                          pool.isEmpty && _poolReview
                              ? 'Brak opanowanych w tej puli.'
                              : 'Brak słówek do nauki w tej puli.\nDodaj słowa lub wybierz inną pulę.',
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
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton.filledTonal(
                                      tooltip: _audioEnabled
                                          ? 'Posłuchaj'
                                          : 'Lektor wyłączony',
                                      onPressed: _audioEnabled
                                          ? () => _playText(_current!.obcy)
                                          : null,
                                      iconSize: 32,
                                      icon: Icon(
                                        _audioEnabled
                                            ? Icons.volume_up_rounded
                                            : Icons.volume_off_rounded,
                                      ),
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
                    const SizedBox(height: 12),
                    SoftPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(
                            title: 'Twój poziom',
                            subtitle: 'XP za poprawne odpowiedzi',
                            icon: Icons.military_tech_rounded,
                          ),
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
                    // —— MASKOTKA I RESZTA NA DOLE ——
                    const SizedBox(height: 8),
                    SoftPanel(
                      margin: const EdgeInsets.only(bottom: 8, top: 4),
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
                              'Twój zwierzak — garderoba i kolory',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MascotCard(
                      playerLevel: _store.stats.playerLevel,
                      wordsToday: _store.stats.wordsToday,
                      fedToday: _store.stats.mascotFedToday,
                      unlockedIds: _store.stats.unlockedMascotIds,
                      equipped: _store.stats.equippedMascot,
                      placedHome: _store.stats.placedHome,
                      goldenPaws: _store.stats.goldenPaws,
                      species: _store.stats.mascotSpecies,
                      furColor: Color(_store.stats.mascotColorArgb),
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
                    ),
                    SoftPanel(
                      margin: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(
                            title: 'Portal współpracy',
                            subtitle: 'Twój projekt — wspólna praca z tatą',
                            icon: Icons.favorite_rounded,
                          ),
                          SelectableText(
                            _portal.url,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'PIN: ${_portal.pin}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
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
                  ],
                ),
              ),
            ),
            if (_banner != null)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
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
    this.openCreateOnStart = false,
  });

  final String lang;
  final LangPack pack;
  final String selectedId;
  final AppPalette palette;
  final VoidCallback onChanged;
  final ValueChanged<String> onSelect;
  final bool openCreateOnStart;

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
                      decoration: const InputDecoration(
                        labelText: 'Nazwa puli',
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
                      'Zaznacz słowa do puli (możesz szukać po polsku lub obcym).',
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
                              child: const Text('Usuń pulę'),
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
                              : 'Utwórz pulę (${selected.length})',
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
      title: 'Nowa pula słówek',
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
        const SnackBar(content: Text('Podaj nazwę puli')),
      );
      return;
    }
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaznacz przynajmniej jedno słówko')),
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
        SnackBar(content: Text('Utworzono pulę „$name” — ćwiczysz z niej')),
      );
    }
  }

  Future<void> _editGroup(WordGroup g) async {
    final selected = g.wordIds.toSet();
    final nameCtrl = TextEditingController(text: g.name);
    _editingGroupId = g.id;
    final ok = await _pickWords(
      title: 'Edytuj pulę',
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
        title: Text('Pule słówek — ${widget.lang}'),
        actions: [
          IconButton(
            onPressed: _createGroup,
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Nowa pula',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.add),
        label: const Text('Nowa pula'),
      ),
      body: GradientScaffoldBody(
        palette: widget.palette,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Wybierz pulę do ćwiczeń albo utwórz własną: nazwa + zaznaczone słówka.',
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
                          ? 'Twoje pule (pusto — dodaj pierwszą)'
                          : 'Twoje pule (${widget.pack.groups.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (widget.pack.groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Text(
                        'Kliknij „Nowa pula”, wpisz nazwę i zaznacz słówka.',
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
            if (widget.pack.groups.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  'Kategoria',
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
                                label: const Text('Wszystkie'),
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

/// Sklep Kici — ekskluzywne ubranka + miski, posłanie (złote łapki).
class ShopPage extends StatefulWidget {
  const ShopPage({
    super.key,
    required this.stats,
    required this.palette,
    required this.onChanged,
  });

  final AppStats stats;
  final AppPalette palette;
  final VoidCallback onChanged;

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
    _toast('Kupiono: ${item.name}! 🐾');
  }

  Future<void> _buyHome(HomeItem item) async {
    final err = widget.stats.buyHomeItem(item);
    if (err != null) {
      _toast(err);
      return;
    }
    widget.onChanged();
    setState(() {});
    _toast('Kupiono: ${item.name}! 🐾');
  }

  @override
  Widget build(BuildContext context) {
    final outfits = shopExclusiveOutfits();
    final paws = widget.stats.goldenPaws;
    final petName = mascotName(widget.stats.mascotSpecies);
    return Scaffold(
      appBar: AppBar(
        title: Text('Sklep $petName'),
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
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Ubranka', icon: Icon(Icons.checkroom_outlined)),
            Tab(text: 'Pokoik', icon: Icon(Icons.home_outlined)),
          ],
        ),
      ),
      body: GradientScaffoldBody(
        palette: widget.palette,
        child: Column(
          children: [
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
                      'Złote łapki: +$pawsPerCorrect za poprawną odpowiedź, '
                      '+$pawsFeedBonus gdy $petName najedzona, '
                      '+$pawsPerLevelUp za poziom, '
                      '+$pawsDailyChat za rozmowę AI.',
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
                                tooltip: 'Podgląd 3D',
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
                                      child: Text(equipped ? 'Zdjęte' : 'Ubierz'),
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
                                tooltip: 'Podgląd 3D',
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
                                      child: Text(placed ? 'Schowaj' : 'Wystaw'),
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
        ),
      ),
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
