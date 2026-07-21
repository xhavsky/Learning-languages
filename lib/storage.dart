import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mascot.dart';
import 'models.dart';

/// XP potrzebne, żeby przejść z [fromLevel] na fromLevel+1.
/// Im wyższy poziom, tym stromiej (kwadratowo).
int xpNeededForLevel(int fromLevel) {
  final lv = fromLevel < 1 ? 1 : fromLevel;
  return 55 + lv * 40 + lv * lv * 8;
}

class AppStats {
  AppStats({
    this.streakDays = 0,
    this.lastPlayDay = '',
    this.sessionCorrect = 0,
    this.sessionTotal = 0,
    this.lifetimeCorrect = 0,
    this.lifetimeTotal = 0,
    this.xp = 0,
    this.lastChatDay = '',
    this.sessionXp = 0,
    this.rewardedLevel = 1,
    this.wordsToday = 0,
    this.wordsDay = '',
    this.goldenPaws = 0,
    this.mascotSpecies = MascotSpecies.cat,
    this.mascotColorArgb = defaultMascotColorArgb,
    List<String>? unlockedMascotIds,
    Map<String, String>? equippedMascot,
    List<String>? ownedHomeIds,
    Map<String, String>? placedHome,
  })  : unlockedMascotIds = List<String>.from(unlockedMascotIds ?? const []),
        equippedMascot = Map<String, String>.from(equippedMascot ?? const {}),
        ownedHomeIds = List<String>.from(ownedHomeIds ?? const []),
        placedHome = Map<String, String>.from(placedHome ?? const {});

  int streakDays;
  String lastPlayDay; // yyyy-MM-dd
  int sessionCorrect;
  int sessionTotal;
  int lifetimeCorrect;
  int lifetimeTotal;

  /// Punkty doświadczenia (trwałe).
  int xp;

  /// Ostatni dzień ukończonej rozmowy AI (yyyy-MM-dd).
  String lastChatDay;

  /// XP zdobyte w tej sesji aplikacji (nie zapisywane).
  int sessionXp;

  /// Najwyższy poziom, za który już pokazano nagrodę (ciekawostkę).
  int rewardedLevel;

  /// Ile słówek „nakarmiło” kotka dziś (poprawne odpowiedzi).
  int wordsToday;

  /// Dzień licznika karmienia (yyyy-MM-dd).
  String wordsDay;

  /// Waluta sklepu — złote łapki 🐾
  int goldenPaws;

  /// Odblokowane ubranka (id z [mascotWardrobe]).
  List<String> unlockedMascotIds;

  /// Założone ubranka: slot.name → itemId.
  Map<String, String> equippedMascot;

  /// Kupione rzeczy do pokoiku (miski, posłanie…).
  List<String> ownedHomeIds;

  /// Ustawione w pokoiku: HomeSlot.name → homeItemId.
  Map<String, String> placedHome;

  /// Kot albo pies.
  MascotSpecies mascotSpecies;

  /// Kolor futerka (ARGB).
  int mascotColorArgb;

  double get sessionAccuracy =>
      sessionTotal == 0 ? 0 : sessionCorrect / sessionTotal;

  /// Poziom gracza z XP (1, 2, 3…).
  int get playerLevel {
    var level = 1;
    var left = xp;
    var need = xpNeededForLevel(level);
    while (left >= need) {
      left -= need;
      level++;
      need = xpNeededForLevel(level);
    }
    return level;
  }

  /// Postęp do kolejnego poziomu 0.0–1.0.
  double get levelProgress {
    var left = xp;
    var level = 1;
    var need = xpNeededForLevel(level);
    while (left >= need) {
      left -= need;
      level++;
      need = xpNeededForLevel(level);
    }
    return need == 0 ? 1 : (left / need).clamp(0.0, 1.0);
  }

  /// Ile XP brakuje do kolejnego poziomu.
  int get xpToNextLevel {
    var left = xp;
    var level = 1;
    var need = xpNeededForLevel(level);
    while (left >= need) {
      left -= need;
      level++;
      need = xpNeededForLevel(level);
    }
    return (need - left).clamp(0, need);
  }

  bool get chatDoneToday => lastChatDay == _dayKey(DateTime.now());

  /// Minimum słówek dziennie = kotek najedzony.
  static const dailyFeedGoal = mascotDailyFeedGoal;

  bool get mascotFedToday {
    _rollFeedDay();
    return wordsToday >= dailyFeedGoal;
  }

  void _rollFeedDay() {
    final today = _dayKey(DateTime.now());
    if (wordsDay != today) {
      wordsDay = today;
      wordsToday = 0;
    }
  }

  /// Liczy poprawną odpowiedź jako karmę dla maskotki. Zwraca true gdy właśnie osiągnęła cel.
  bool feedMascotOnCorrect() {
    _rollFeedDay();
    final before = wordsToday;
    wordsToday++;
    return before < dailyFeedGoal && wordsToday >= dailyFeedGoal;
  }

  /// Odblokowuje ubranko i zakłada je (jeśli slot wolny albo [forceEquip]).
  void unlockMascotItem(String id, {bool forceEquip = true}) {
    if (!unlockedMascotIds.contains(id)) {
      unlockedMascotIds.add(id);
    }
    final item = mascotItemById(id);
    if (item == null) return;
    final slot = item.slot.name;
    if (forceEquip || !equippedMascot.containsKey(slot)) {
      equippedMascot[slot] = id;
    }
  }

  /// Zakłada / zdejmuje ubranko (toggle w tym samym slocie).
  void toggleEquipMascot(MascotItem item) {
    if (!unlockedMascotIds.contains(item.id)) return;
    final slot = item.slot.name;
    if (equippedMascot[slot] == item.id) {
      equippedMascot.remove(slot);
    } else {
      equippedMascot[slot] = item.id;
    }
  }

  void addGoldenPaws(int amount) {
    if (amount <= 0) return;
    goldenPaws += amount;
  }

  /// Kupuje ekskluzywne ubranko. Zwraca null przy sukcesie, inaczej komunikat.
  String? buyOutfit(MascotItem item) {
    final price = item.shopPrice;
    if (price == null) return 'To ubranko nie jest w sklepie';
    if (unlockedMascotIds.contains(item.id)) return 'Już masz to ubranko';
    if (goldenPaws < price) {
      return 'Za mało złotych łapek (potrzeba $price 🐾)';
    }
    goldenPaws -= price;
    unlockMascotItem(item.id);
    return null;
  }

  /// Kupuje miskę / posłanie. Zwraca null przy sukcesie.
  String? buyHomeItem(HomeItem item) {
    if (ownedHomeIds.contains(item.id)) return 'Już masz tę rzecz';
    if (goldenPaws < item.price) {
      return 'Za mało złotych łapek (potrzeba ${item.price} 🐾)';
    }
    goldenPaws -= item.price;
    ownedHomeIds.add(item.id);
    placedHome[item.slot.name] = item.id;
    return null;
  }

  /// Wystawia / chowa rzecz w pokoiku (toggle).
  void togglePlaceHome(HomeItem item) {
    if (!ownedHomeIds.contains(item.id)) return;
    final slot = item.slot.name;
    if (placedHome[slot] == item.id) {
      placedHome.remove(slot);
    } else {
      placedHome[slot] = item.id;
    }
  }

  /// Stare zapisy bez listy ubranek → migracja po legacyUnlockLevel.
  void ensureMascotMigration() {
    if (unlockedMascotIds.isNotEmpty) return;
    final migrated = migrateUnlockedFromLevel(playerLevel);
    if (migrated.isEmpty) return;
    unlockedMascotIds = migrated;
    for (final id in migrated) {
      final item = mascotItemById(id);
      if (item != null && !equippedMascot.containsKey(item.slot.name)) {
        equippedMascot[item.slot.name] = id;
      }
    }
  }

  Map<String, dynamic> toJson() {
    _rollFeedDay();
    return {
      'streakDays': streakDays,
      'lastPlayDay': lastPlayDay,
      'lifetimeCorrect': lifetimeCorrect,
      'lifetimeTotal': lifetimeTotal,
      'xp': xp,
      'lastChatDay': lastChatDay,
      'rewardedLevel': rewardedLevel,
      'wordsToday': wordsToday,
      'wordsDay': wordsDay,
      'goldenPaws': goldenPaws,
      'unlockedMascotIds': unlockedMascotIds,
      'equippedMascot': equippedMascot,
      'ownedHomeIds': ownedHomeIds,
      'placedHome': placedHome,
      'mascotSpecies': mascotSpecies.name,
      'mascotColorArgb': mascotColorArgb,
    };
  }

  factory AppStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AppStats();
    final xp = json['xp'] as int? ?? 0;
    final tmp = AppStats(xp: xp);
    final rawUnlocked = json['unlockedMascotIds'];
    final unlocked = <String>[];
    if (rawUnlocked is List) {
      for (final e in rawUnlocked) {
        if (e is String) unlocked.add(e);
      }
    }
    final rawEquip = json['equippedMascot'];
    final equipped = <String, String>{};
    if (rawEquip is Map) {
      rawEquip.forEach((k, v) {
        if (k is String && v is String) equipped[k] = v;
      });
    }
    final rawHome = json['ownedHomeIds'];
    final ownedHome = <String>[];
    if (rawHome is List) {
      for (final e in rawHome) {
        if (e is String) ownedHome.add(e);
      }
    }
    final rawPlaced = json['placedHome'];
    final placed = <String, String>{};
    if (rawPlaced is Map) {
      rawPlaced.forEach((k, v) {
        if (k is String && v is String) placed[k] = v;
      });
    }
    final speciesRaw = json['mascotSpecies'] as String? ?? 'cat';
    final species = speciesRaw == 'dog' ? MascotSpecies.dog : MascotSpecies.cat;
    final colorArgb =
        json['mascotColorArgb'] as int? ?? defaultMascotColorArgb;
    final s = AppStats(
      streakDays: json['streakDays'] as int? ?? 0,
      lastPlayDay: json['lastPlayDay'] as String? ?? '',
      lifetimeCorrect: json['lifetimeCorrect'] as int? ?? 0,
      lifetimeTotal: json['lifetimeTotal'] as int? ?? 0,
      xp: xp,
      lastChatDay: json['lastChatDay'] as String? ?? '',
      // Stare zapisy bez pola: nie spamuj nagrodami za minione poziomy.
      rewardedLevel: json['rewardedLevel'] as int? ?? tmp.playerLevel,
      wordsToday: json['wordsToday'] as int? ?? 0,
      wordsDay: json['wordsDay'] as String? ?? '',
      goldenPaws: json['goldenPaws'] as int? ?? 0,
      mascotSpecies: species,
      mascotColorArgb: colorArgb,
      unlockedMascotIds: unlocked,
      equippedMascot: equipped,
      ownedHomeIds: ownedHome,
      placedHome: placed,
    );
    s._rollFeedDay();
    s.ensureMascotMigration();
    return s;
  }

  void addXp(int amount) {
    if (amount <= 0) return;
    xp += amount;
    sessionXp += amount;
  }

  /// Poziomy, za które należy pokazać nagrodę (po [addXp]).
  List<int> pendingRewardLevels() {
    final now = playerLevel;
    if (now <= rewardedLevel) return const [];
    return [for (var lv = rewardedLevel + 1; lv <= now; lv++) lv];
  }

  /// Oznacza poziomy jako nagrodzone (po pokazaniu ciekawostek).
  void markRewardsClaimed(Iterable<int> levels) {
    for (final lv in levels) {
      if (lv > rewardedLevel) rewardedLevel = lv;
    }
  }

  /// Zwraca true, jeśli poprawna odpowiedź właśnie najadła kotka (cel dnia).
  bool recordAnswer(bool correct) {
    sessionTotal++;
    lifetimeTotal++;
    var justFed = false;
    if (correct) {
      sessionCorrect++;
      lifetimeCorrect++;
      addXp(10);
      addGoldenPaws(pawsPerCorrect);
      justFed = feedMascotOnCorrect();
      if (justFed) addGoldenPaws(pawsFeedBonus);
    } else {
      addXp(2);
    }
    final today = _dayKey(DateTime.now());
    if (lastPlayDay != today) {
      final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
      streakDays = (lastPlayDay == yesterday) ? streakDays + 1 : 1;
      lastPlayDay = today;
      if (streakDays >= 2) addXp(5); // bonus za kontynuację passy
    }
    return justFed;
  }

  /// Nagroda za codzienną rozmowę (raz dziennie). Zwraca XP lub 0.
  int completeDailyChat({int reward = 40}) {
    final today = _dayKey(DateTime.now());
    if (lastChatDay == today) return 0;
    lastChatDay = today;
    addXp(reward);
    addGoldenPaws(pawsDailyChat);
    return reward;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class BazaStore {
  Map<String, LangPack> baza = {};
  Map<String, dynamic> manifest = {};
  AppStats stats = AppStats();

  /// Ustawiane w testach screenshotów (nie zależy od dart-define / env izolatu).
  static bool forceScreenshotFixture = false;

  Future<void> load() async {
    final screenshotMode = forceScreenshotFixture ||
        const bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false) ||
            Platform.environment['SCREENSHOT_MODE'] == '1' ||
            Platform.environment['SCREENSHOT_MODE'] == 'true';
    if (screenshotMode) {
      final seed =
          await rootBundle.loadString('assets/data/baza_screenshot.json');
      baza = parseBaza(jsonDecode(seed) as Map<String, dynamic>);
      final now = DateTime.now();
      final day =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      stats = AppStats(
        xp: 420,
        goldenPaws: 48,
        streakDays: 3,
        wordsToday: 4,
        wordsDay: day,
        sessionCorrect: 2,
        sessionTotal: 3,
      );
      manifest = {};
      return;
    }
    try {
      await _loadImpl();
    } catch (e) {
      // Awaryjnie: sama baza z assetów, bez pliku użytkownika.
      // ignore: avoid_print
      print('BazaStore.load failed, falling back to seed: $e');
      final seed = await rootBundle.loadString('assets/data/baza.json');
      baza = parseBaza(jsonDecode(seed) as Map<String, dynamic>);
      stats = AppStats();
      try {
        final m = await rootBundle.loadString('assets/audio/manifest.json');
        if (m.trim().isNotEmpty) {
          manifest = jsonDecode(m) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
  }

  Future<void> _loadImpl() async {
    final seed = await rootBundle.loadString('assets/data/baza.json');
    final userFile = await _userBazaFile();
    var raw = seed;
    if (await userFile.exists()) {
      final existing = await userFile.readAsString();
      if (existing.trim().isNotEmpty) raw = existing;
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

    baza = parseBaza(decoded);
    // Merge new words/groups from seed assets; refresh display text.
    final seedPack = parseBaza(jsonDecode(seed) as Map<String, dynamic>);
    for (final e in seedPack.entries) {
      final pack = baza.putIfAbsent(
        e.key,
        () => LangPack(words: [], groups: []),
      );
      final byId = {for (final w in pack.words) w.id: w};
      for (final w in e.value.words) {
        final existing = byId[w.id];
        if (existing == null) {
          pack.words.add(w);
          byId[w.id] = w;
        } else {
          // Keep progress; refresh spelling/capitalization from seed.
          final i = pack.words.indexOf(existing);
          pack.words[i] = Word(
            id: existing.id,
            pl: w.pl,
            obcy: w.obcy,
            level: existing.level,
            hard: existing.hard,
            nextDue: existing.nextDue,
            correctStreak: existing.correctStreak,
          );
        }
      }
      // Zestawy wbudowane (z seeda) synchronizujemy; użytkownika (g-…) zostawiamy.
      final seedIds = e.value.groups.map((g) => g.id).toSet();
      final seedAssigned = <String>{
        for (final g in e.value.groups) ...g.wordIds,
      };
      pack.groups.removeWhere(
        (g) => !g.id.startsWith('g-') && !seedIds.contains(g.id),
      );
      for (final g in e.value.groups) {
        final existing = pack.groups.where((x) => x.id == g.id).firstOrNull;
        if (existing == null) {
          pack.groups.add(
            WordGroup(
              id: g.id,
              name: g.name,
              wordIds: List.of(g.wordIds),
            ),
          );
        } else {
          existing.name = g.name;
          // Seed ustawia kategorie słów z bazy; własne słowa usera zostają.
          final keptUser = existing.wordIds
              .where((id) => !seedAssigned.contains(id) && pack.byId(id) != null);
          existing.wordIds = [...g.wordIds, ...keptUser];
        }
      }
      // Zdania z seeda — jak słówka: dodaj nowe, zachowaj postęp.
      final bySentId = {for (final w in pack.sentences) w.id: w};
      for (final w in e.value.sentences) {
        final existing = bySentId[w.id];
        if (existing == null) {
          pack.sentences.add(w);
          bySentId[w.id] = w;
        } else {
          final i = pack.sentences.indexOf(existing);
          pack.sentences[i] = Word(
            id: existing.id,
            pl: w.pl,
            obcy: w.obcy,
            level: existing.level,
            hard: existing.hard,
            nextDue: existing.nextDue,
            correctStreak: existing.correctStreak,
          );
        }
      }
    }

    try {
      final m = await rootBundle.loadString('assets/audio/manifest.json');
      if (m.trim().isNotEmpty) {
        manifest = jsonDecode(m) as Map<String, dynamic>;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('stats');
    if (s != null) {
      try {
        stats = AppStats.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    stats.sessionCorrect = 0;
    stats.sessionTotal = 0;
  }

  Future<void> save() async {
    final file = await _userBazaFile();
    await file.writeAsString(prettyBaza(baza));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stats', jsonEncode(stats.toJson()));
  }

  Future<File> _userBazaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/baza.json');
  }

  Future<String> exportToDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    final name =
        'dialectium_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
    final f = File('${dir.path}/$name');
    final payload = {
      'baza': encodeBaza(baza),
      'stats': stats.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return f.path;
  }

  Future<String?> importFromPath(String path) async {
    final f = File(path);
    if (!await f.exists()) return 'Plik nie istnieje';
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final bazaRaw = (raw['baza'] ?? raw) as Map<String, dynamic>;
      baza = parseBaza(bazaRaw);
      if (raw['stats'] is Map<String, dynamic>) {
        stats = AppStats.fromJson(raw['stats'] as Map<String, dynamic>);
      }
      await save();
      return null;
    } catch (e) {
      return 'Błąd importu: $e';
    }
  }

  String? audioAsset(String lang, String obcy) {
    final entries = manifest['entries'];
    if (entries is! Map) return null;
    final want = '$lang|$obcy';
    var entry = entries[want];
    if (entry is! Map) {
      final wantFold = want.toLowerCase();
      for (final e in entries.entries) {
        if (e.key.toString().toLowerCase() == wantFold) {
          entry = e.value;
          break;
        }
      }
    }
    if (entry is Map && entry['file'] is String) {
      return 'audio/${entry['file']}';
    }
    return null;
  }

  bool hasAudio(String lang, String obcy) => audioAsset(lang, obcy) != null;

  List<String> missingAudioKeys() {
    final missing = <String>[];
    for (final e in baza.entries) {
      for (final w in e.value.words) {
        if (!hasAudio(e.key, w.obcy)) missing.add('${e.key}|${w.obcy}');
      }
      for (final w in e.value.sentences) {
        if (!hasAudio(e.key, w.obcy)) missing.add('${e.key}|${w.obcy}');
      }
    }
    return missing;
  }
}
