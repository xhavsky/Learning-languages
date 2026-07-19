import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

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
  });

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

  double get sessionAccuracy =>
      sessionTotal == 0 ? 0 : sessionCorrect / sessionTotal;

  /// Poziom gracza z XP (1, 2, 3…).
  int get playerLevel {
    var level = 1;
    var need = 50;
    var left = xp;
    while (left >= need) {
      left -= need;
      level++;
      need = 40 + level * 25;
    }
    return level;
  }

  /// Postęp do kolejnego poziomu 0.0–1.0.
  double get levelProgress {
    var need = 50;
    var left = xp;
    var level = 1;
    while (left >= need) {
      left -= need;
      level++;
      need = 40 + level * 25;
    }
    return need == 0 ? 1 : (left / need).clamp(0.0, 1.0);
  }

  /// Ile XP brakuje do kolejnego poziomu.
  int get xpToNextLevel {
    var need = 50;
    var left = xp;
    var level = 1;
    while (left >= need) {
      left -= need;
      level++;
      need = 40 + level * 25;
    }
    return (need - left).clamp(0, need);
  }

  bool get chatDoneToday => lastChatDay == _dayKey(DateTime.now());

  Map<String, dynamic> toJson() => {
        'streakDays': streakDays,
        'lastPlayDay': lastPlayDay,
        'lifetimeCorrect': lifetimeCorrect,
        'lifetimeTotal': lifetimeTotal,
        'xp': xp,
        'lastChatDay': lastChatDay,
        'rewardedLevel': rewardedLevel,
      };

  factory AppStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AppStats();
    final xp = json['xp'] as int? ?? 0;
    final tmp = AppStats(xp: xp);
    return AppStats(
      streakDays: json['streakDays'] as int? ?? 0,
      lastPlayDay: json['lastPlayDay'] as String? ?? '',
      lifetimeCorrect: json['lifetimeCorrect'] as int? ?? 0,
      lifetimeTotal: json['lifetimeTotal'] as int? ?? 0,
      xp: xp,
      lastChatDay: json['lastChatDay'] as String? ?? '',
      // Stare zapisy bez pola: nie spamuj nagrodami za minione poziomy.
      rewardedLevel: json['rewardedLevel'] as int? ?? tmp.playerLevel,
    );
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

  void recordAnswer(bool correct) {
    sessionTotal++;
    lifetimeTotal++;
    if (correct) {
      sessionCorrect++;
      lifetimeCorrect++;
      addXp(10);
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
  }

  /// Nagroda za codzienną rozmowę (raz dziennie). Zwraca XP lub 0.
  int completeDailyChat({int reward = 40}) {
    final today = _dayKey(DateTime.now());
    if (lastChatDay == today) return 0;
    lastChatDay = today;
    addXp(reward);
    return reward;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class BazaStore {
  Map<String, LangPack> baza = {};
  Map<String, dynamic> manifest = {};
  AppStats stats = AppStats();

  Future<void> load() async {
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
        'trener_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
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
    final entry = entries['$lang|$obcy'];
    if (entry is Map && entry['file'] is String) {
      return 'audio/${entry['file']}';
    }
    return null;
  }

  List<String> missingAudioKeys() {
    final missing = <String>[];
    final entries = manifest['entries'];
    final map = entries is Map ? entries : {};
    for (final e in baza.entries) {
      for (final w in e.value.words) {
        final key = '${e.key}|${w.obcy}';
        if (!map.containsKey(key)) missing.add(key);
      }
    }
    return missing;
  }
}
