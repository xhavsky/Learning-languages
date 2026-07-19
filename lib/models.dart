import 'dart:convert';
import 'dart:math';

/// SRS levels: 0=new, 1–2=learning, 3=mastered (3 poprawne z rzędu).
class Word {
  Word({
    required this.id,
    required this.pl,
    required this.obcy,
    this.level = 0,
    this.hard = false,
    this.nextDue,
    this.correctStreak = 0,
  });

  final String id;
  final String pl;
  final String obcy;
  int level;
  bool hard;
  DateTime? nextDue;

  /// Ile dobrych odpowiedzi z rzędu (reset przy błędzie).
  int correctStreak;

  bool get nauczone => level >= 3;

  factory Word.fromJson(Map<String, dynamic> json) {
    final pl = capitalizePhrase(json['pl'] as String? ?? '');
    final obcy = capitalizePhrase(json['obcy'] as String? ?? '');
    var id = json['id'] as String?;
    id ??= _stableId(pl, obcy);
    var level = json['level'] as int?;
    level ??= (json['nauczone'] as bool? ?? false) ? 3 : 0;
    DateTime? due;
    final rawDue = json['nextDue'];
    if (rawDue is String && rawDue.isNotEmpty) {
      due = DateTime.tryParse(rawDue);
    }
    final streak = json['correctStreak'] as int? ?? (level >= 3 ? 3 : 0);
    return Word(
      id: id,
      pl: pl,
      obcy: obcy,
      level: level.clamp(0, 3),
      hard: json['hard'] as bool? ?? false,
      nextDue: due,
      correctStreak: streak.clamp(0, 99),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pl': pl,
        'obcy': obcy,
        'level': level,
        'nauczone': nauczone,
        'hard': hard,
        'nextDue': nextDue?.toIso8601String(),
        'correctStreak': correctStreak,
      };

  static String _stableId(String pl, String obcy) {
    // Simple stable id without crypto package (case-insensitive).
    final s = '${pl.toLowerCase()}|${obcy.toLowerCase()}';
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

/// Pierwsza litera z dużej — ładniejszy wygląd listy.
String capitalizePhrase(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

class WordGroup {
  WordGroup({
    required this.id,
    required this.name,
    required this.wordIds,
  });

  final String id;
  String name;
  List<String> wordIds;

  factory WordGroup.fromJson(Map<String, dynamic> json) => WordGroup(
        id: json['id'] as String? ??
            Word._stableId('g', '${Random().nextInt(1 << 20)}'),
        name: json['name'] as String? ?? 'Zestaw',
        wordIds: (json['wordIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'wordIds': wordIds,
      };
}

class LangPack {
  LangPack({required this.words, required this.groups});

  final List<Word> words;
  final List<WordGroup> groups;

  Word? byId(String id) {
    for (final w in words) {
      if (w.id == id) return w;
    }
    return null;
  }

  List<Word> wordsForGroup(String? groupId) {
    if (groupId == null || groupId == '__all__') return List.of(words);
    if (groupId == '__unlearned__') {
      return words.where((w) => w.level < 3).toList();
    }
    if (groupId == '__hard__') {
      return words.where((w) => w.hard || w.level <= 1).toList();
    }
    final g = groups.where((x) => x.id == groupId).firstOrNull;
    if (g == null) return List.of(words);
    return g.wordIds.map(byId).whereType<Word>().toList();
  }

  /// Nazwy kategorii (zestawów), do których należy słówko.
  List<String> categoriesFor(String wordId) {
    return groups
        .where((g) => g.wordIds.contains(wordId))
        .map((g) => g.name)
        .toList();
  }

  /// Usuwa słowo z bazy i ze wszystkich zestawów.
  bool removeWord(String wordId) {
    final before = words.length;
    words.removeWhere((w) => w.id == wordId);
    for (final g in groups) {
      g.wordIds.removeWhere((id) => id == wordId);
    }
    return words.length < before;
  }

  Map<String, dynamic> toJson() => {
        'words': words.map((w) => w.toJson()).toList(),
        'groups': groups.map((g) => g.toJson()).toList(),
      };
}

/// Migrates legacy `{ "Lang": [ {...} ] }` and new `{ "Lang": { words, groups } }`.
Map<String, LangPack> parseBaza(Map<String, dynamic> raw) {
  final out = <String, LangPack>{};
  for (final e in raw.entries) {
    final v = e.value;
    if (v is Map<String, dynamic> && v['words'] is List) {
      final words = (v['words'] as List)
          .map((w) => Word.fromJson(w as Map<String, dynamic>))
          .toList();
      final groups = (v['groups'] as List? ?? [])
          .map((g) => WordGroup.fromJson(g as Map<String, dynamic>))
          .toList();
      out[e.key] = LangPack(words: words, groups: groups);
    } else if (v is List) {
      final words =
          v.map((w) => Word.fromJson(w as Map<String, dynamic>)).toList();
      out[e.key] = LangPack(words: words, groups: []);
    }
  }
  return out;
}

Map<String, dynamic> encodeBaza(Map<String, LangPack> baza) => {
      for (final e in baza.entries) e.key: e.value.toJson(),
    };

String prettyBaza(Map<String, LangPack> baza) =>
    const JsonEncoder.withIndent('  ').convert(encodeBaza(baza));

/// Nauczone dopiero po 3 dobrych odpowiedziach z rzędu.
void applySrs(Word w, {required bool correct}) {
  final now = DateTime.now();
  if (correct) {
    w.correctStreak = (w.correctStreak + 1).clamp(0, 99);
    if (w.correctStreak >= 3) {
      w.level = 3;
      w.hard = false;
      w.nextDue = now.add(const Duration(days: 7));
    } else {
      w.level = w.correctStreak.clamp(0, 2);
      if (w.level >= 2) w.hard = false;
      w.nextDue = now.add(Duration(days: switch (w.level) {
        1 => 1,
        2 => 3,
        _ => 0,
      }));
    }
  } else {
    w.correctStreak = 0;
    w.level = 0;
    w.hard = true;
    w.nextDue = now; // due immediately
  }
}

extension FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
