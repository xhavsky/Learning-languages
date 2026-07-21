/// Porównywanie odpowiedzi: bez „to”, bez akcentów, ze skrótami EN (I'm ≈ I am).
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

/// Skróty angielskie → pełna forma (i'm → i am). Dłuższe najpierw.
const _contractionToFull = <String, String>{
  "won't": 'will not',
  "can't": 'cannot',
  "shan't": 'shall not',
  "mustn't": 'must not',
  "needn't": 'need not',
  "wouldn't": 'would not',
  "shouldn't": 'should not',
  "couldn't": 'could not',
  "mightn't": 'might not',
  "isn't": 'is not',
  "aren't": 'are not',
  "wasn't": 'was not',
  "weren't": 'were not',
  "don't": 'do not',
  "doesn't": 'does not',
  "didn't": 'did not',
  "haven't": 'have not',
  "hasn't": 'has not',
  "hadn't": 'had not',
  "i'm": 'i am',
  "you're": 'you are',
  "we're": 'we are',
  "they're": 'they are',
  "he's": 'he is',
  "she's": 'she is',
  "it's": 'it is',
  "that's": 'that is',
  "there's": 'there is',
  "here's": 'here is',
  "what's": 'what is',
  "who's": 'who is',
  "where's": 'where is',
  "how's": 'how is',
  "let's": 'let us',
  "i'll": 'i will',
  "you'll": 'you will',
  "he'll": 'he will',
  "she'll": 'she will',
  "we'll": 'we will',
  "they'll": 'they will',
  "it'll": 'it will',
  "that'll": 'that will',
  "i've": 'i have',
  "you've": 'you have',
  "we've": 'we have',
  "they've": 'they have',
  "i'd": 'i would',
  "you'd": 'you would',
  "he'd": 'he would',
  "she'd": 'she would',
  "we'd": 'we would',
  "they'd": 'they would',
};

/// Pełna forma → skrót (i am → i'm). Dłuższe najpierw.
final _fullToContraction = Map<String, String>.fromEntries(
  _contractionToFull.entries.map((e) => MapEntry(e.value, e.key)),
)..addAll(const {
    'can not': "can't",
  });

String _replacePhraseMap(String s, Map<String, String> map) {
  if (s.isEmpty || map.isEmpty) return s;
  final keys = map.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  var out = s;
  for (final key in keys) {
    final re = RegExp(
      r'(^|[^a-z0-9])' + RegExp.escape(key) + r'(?=[^a-z0-9]|$)',
    );
    out = out.replaceAllMapped(re, (m) => '${m[1]}${map[key]}');
  }
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Rozwija skróty: "i'm happy" → "i am happy".
String expandContractions(String s) =>
    _replacePhraseMap(s, _contractionToFull);

/// Skraca pełne formy: "i am happy" → "i'm happy".
String contractExpansions(String s) {
  var out = s;
  // „cannot” i „can not” → can't
  out = _replacePhraseMap(out, const {'can not': "can't", 'cannot': "can't"});
  out = _replacePhraseMap(out, _fullToContraction);
  return out;
}

void _addFolded(Set<String> out, Iterable<String> forms) {
  for (final f in forms) {
    final n = normalizeAnswer(f);
    if (n.isEmpty) continue;
    out.add(n);
    out.add(stripDiacritics(n));
  }
}

/// Akceptowane warianty [expected] — ta sama forma + skróty EN + bez „to” / akcentów.
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
  final forms = <String>{
    e0,
    base,
    expandContractions(e0),
    expandContractions(base),
    contractExpansions(e0),
    contractExpansions(base),
  };
  // Jeszcze raz w obie strony (np. expected już skrócone → expand → contract).
  for (final f in [...forms]) {
    forms.add(expandContractions(f));
    forms.add(contractExpansions(f));
  }
  _addFolded(out, forms);
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
  final candidates = <String>{
    u,
    stripDiacritics(u),
    stripInfinitiveParticle(u),
    stripDiacritics(stripInfinitiveParticle(u)),
    expandContractions(u),
    contractExpansions(u),
    expandContractions(stripInfinitiveParticle(u)),
    contractExpansions(stripInfinitiveParticle(u)),
  };
  for (final c in candidates) {
    if (variants.contains(c) || variants.contains(stripDiacritics(c))) {
      return true;
    }
  }
  return false;
}
