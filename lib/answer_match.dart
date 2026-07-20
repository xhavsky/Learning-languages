/// Porównywanie odpowiedzi: bez „to”, bez akcentów.
/// Odmian NIE zalicza — dodaj je jako osobne słówka.
library;

String normalizeAnswer(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return s;
  s = s
      .replaceAll('’', "'")
      .replaceAll('`', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.!?,:;¡¿«»""„"]'), '');
  return s.trim();
}

/// Usuwa znaki diakrytyczne (café → cafe, mañana → manana).
String stripDiacritics(String s) {
  const map = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
    'ё': 'е',
  };
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

/// „to swim” → „swim” — nie trzeba wpisywać „to”.
String stripInfinitiveParticle(String s) {
  if (s.startsWith('to ') && s.length > 3) return s.substring(3).trim();
  return s;
}

void _addFolded(Set<String> out, Iterable<String> forms) {
  for (final f in forms) {
    final n = normalizeAnswer(f);
    if (n.isEmpty) continue;
    out.add(n);
    out.add(stripDiacritics(n));
  }
}

/// Akceptowane warianty [expected] — tylko ta sama forma (+ bez „to” / akcentów).
/// [lang] / [expectPolish] zostawione dla kompatybilności API (odmian nie ma).
Set<String> acceptedVariants(
  String expected, {
  String? lang,
  bool expectPolish = false,
}) {
  final e0 = normalizeAnswer(expected);
  if (e0.isEmpty) return {};
  final out = <String>{};
  final base = stripInfinitiveParticle(e0);
  _addFolded(out, [e0, base]);
  return out;
}

/// Czy odpowiedź użytkownika zalicza się (bez odmian).
bool answersMatch(
  String user,
  String expected, {
  String? lang,
  bool expectPolish = false,
}) {
  final u = normalizeAnswer(user);
  if (u.isEmpty) return false;
  final variants = acceptedVariants(
    expected,
    lang: lang,
    expectPolish: expectPolish,
  );
  final uFold = stripDiacritics(u);
  final uBase = stripInfinitiveParticle(u);
  return variants.contains(u) ||
      variants.contains(uFold) ||
      variants.contains(uBase) ||
      variants.contains(stripDiacritics(uBase));
}
