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
  });

  int streakDays;
  String lastPlayDay; // yyyy-MM-dd
  int sessionCorrect;
  int sessionTotal;
  int lifetimeCorrect;
  int lifetimeTotal;

  double get sessionAccuracy =>
      sessionTotal == 0 ? 0 : sessionCorrect / sessionTotal;

  Map<String, dynamic> toJson() => {
        'streakDays': streakDays,
        'lastPlayDay': lastPlayDay,
        'lifetimeCorrect': lifetimeCorrect,
        'lifetimeTotal': lifetimeTotal,
      };

  factory AppStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AppStats();
    return AppStats(
      streakDays: json['streakDays'] as int? ?? 0,
      lastPlayDay: json['lastPlayDay'] as String? ?? '',
      lifetimeCorrect: json['lifetimeCorrect'] as int? ?? 0,
      lifetimeTotal: json['lifetimeTotal'] as int? ?? 0,
    );
  }

  void recordAnswer(bool correct) {
    sessionTotal++;
    lifetimeTotal++;
    if (correct) {
      sessionCorrect++;
      lifetimeCorrect++;
    }
    final today = _dayKey(DateTime.now());
    if (lastPlayDay != today) {
      final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
      streakDays = (lastPlayDay == yesterday) ? streakDays + 1 : 1;
      lastPlayDay = today;
    }
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
      final gHave = pack.groups.map((g) => g.id).toSet();
      for (final g in e.value.groups) {
        if (!gHave.contains(g.id)) {
          pack.groups.add(g);
          gHave.add(g.id);
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
