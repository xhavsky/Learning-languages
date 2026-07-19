import 'models.dart';

/// Wynik parsowania CSV / tekstu ze słówkami.
class WordImportResult {
  const WordImportResult({
    required this.added,
    required this.skippedDuplicates,
    required this.skippedBadLines,
  });

  final int added;
  final int skippedDuplicates;
  final int skippedBadLines;

  String get summary {
    final parts = <String>['Dodano $added'];
    if (skippedDuplicates > 0) {
      parts.add('pominięto duplikaty: $skippedDuplicates');
    }
    if (skippedBadLines > 0) {
      parts.add('złe linie: $skippedBadLines');
    }
    return parts.join(' · ');
  }
}

/// Para PL / obcy z linii tekstu.
class ParsedPair {
  const ParsedPair(this.pl, this.obcy);
  final String pl;
  final String obcy;
}

/// Rozpoznaje: `pl,obcy` · `pl;obcy` · tab · `pl - obcy` · `pl → obcy`.
List<ParsedPair> parseWordText(String raw) {
  final out = <ParsedPair>[];
  for (var line in raw.split(RegExp(r'\r?\n'))) {
    line = line.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;

    final lower = line.toLowerCase();
    if (out.isEmpty &&
        (lower.contains('polsk') ||
            lower == 'pl,obcy' ||
            lower == 'pl;obcy' ||
            lower.startsWith('pl,') ||
            lower.startsWith('polish'))) {
      continue; // nagłówek
    }

    final pair = _splitLine(line);
    if (pair == null) continue;
    final pl = capitalizePhrase(pair.$1);
    final obcy = capitalizePhrase(pair.$2);
    if (pl.isEmpty || obcy.isEmpty) continue;
    out.add(ParsedPair(pl, obcy));
  }
  return out;
}

(String, String)? _splitLine(String line) {
  // CSV z cudzysłowami: "kot, mały","cat"
  final csv = _csvTwoFields(line);
  if (csv != null) return csv;

  for (final sep in [';', ';', '\t', '|']) {
    final i = line.indexOf(sep);
    if (i > 0 && i < line.length - 1) {
      final a = line.substring(0, i).trim();
      final b = line.substring(i + 1).trim();
      if (a.isNotEmpty && b.isNotEmpty && !b.contains('\n')) {
        return (a, b);
      }
    }
  }

  final arrow = RegExp(r'^(.+?)\s*(?:→|->|—|–|-)\s*(.+)$');
  final m = arrow.firstMatch(line);
  if (m != null) {
    return (m.group(1)!.trim(), m.group(2)!.trim());
  }
  return null;
}

(String, String)? _csvTwoFields(String line) {
  final fields = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if ((c == ',' || c == ';') && !inQuotes) {
      fields.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  fields.add(buf.toString().trim());
  if (fields.length >= 2 && fields[0].isNotEmpty && fields[1].isNotEmpty) {
    return (fields[0], fields[1]);
  }
  return null;
}

/// Dodaje sparsowane pary do [pack]; pomija istniejące id.
WordImportResult importPairsIntoPack(LangPack pack, List<ParsedPair> pairs) {
  final have = {for (final w in pack.words) w.id};
  var added = 0;
  var dup = 0;
  for (final p in pairs) {
    final w = Word.fromJson({'pl': p.pl, 'obcy': p.obcy});
    if (have.contains(w.id)) {
      dup++;
      continue;
    }
    pack.words.add(w);
    have.add(w.id);
    added++;
  }
  return WordImportResult(
    added: added,
    skippedDuplicates: dup,
    skippedBadLines: 0,
  );
}

/// Pełny import z surowego tekstu (zlicza też nieparsowalne linie).
WordImportResult importWordText(LangPack pack, String raw) {
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();
  final pairs = parseWordText(raw);
  final result = importPairsIntoPack(pack, pairs);
  // linie które wyglądały na dane, ale nie dały pary
  var bad = 0;
  for (final line in lines) {
    final lower = line.toLowerCase();
    if (lower.contains('polsk') ||
        lower == 'pl,obcy' ||
        lower.startsWith('pl,')) {
      continue;
    }
    if (_splitLine(line) == null) bad++;
  }
  return WordImportResult(
    added: result.added,
    skippedDuplicates: result.skippedDuplicates,
    skippedBadLines: bad,
  );
}
