import 'dart:math';

/// Ciekawostka językowa odblokowana przy awansie poziomu.
class LanguageCuriosity {
  const LanguageCuriosity({
    required this.id,
    required this.title,
    required this.text,
    this.lang,
  });

  final String id;
  final String title;
  final String text;

  /// null = uniwersalna; inaczej nazwa języka z bazy.
  final String? lang;
}

const languageCuriosities = <LanguageCuriosity>[
  LanguageCuriosity(
    id: 'polyglot',
    title: 'Mózg lubi języki',
    text:
        'Nauka drugiego języka wzmacnia pamięć i koncentrację — jak siłownia dla mózgu!',
  ),
  LanguageCuriosity(
    id: 'words-day',
    title: 'Kilka słów dziennie',
    text:
        'Wystarczy 5–10 nowych słówek dziennie, żeby w rok znać setki słów. Małe kroki działają.',
  ),
  LanguageCuriosity(
    id: 'cognates',
    title: 'Słowa-przyjaciele',
    text:
        'Wiele słów wygląda podobnie w różnych językach (np. „telefon”). To ułatwia naukę!',
  ),
  LanguageCuriosity(
    id: 'speak-aloud',
    title: 'Głośno = lepiej',
    text:
        'Powtarzanie na głos utrwala słówka mocniej niż samo czytanie w głowie.',
  ),
  LanguageCuriosity(
    id: 'sleep',
    title: 'Sen pomaga',
    text:
        'Po nauce sen „porządkuje” nowe słowa w pamięci. Dlatego powtórka rano bywa łatwiejsza.',
  ),
  LanguageCuriosity(
    id: 'en-th',
    title: 'Angielskie „th”',
    text:
        'Dźwięk „th” (the, think) jest rzadki na świecie — stąd bywa trudny dla Polaków. Ćwiczenie robi mistrza!',
    lang: 'Angielski',
  ),
  LanguageCuriosity(
    id: 'en-most',
    title: 'Najpopularniejszy język',
    text:
        'Angielski jest najczęściej uczonym językiem obcym na świecie — masz towarzystwo milionów osób!',
    lang: 'Angielski',
  ),
  LanguageCuriosity(
    id: 'en-loan',
    title: 'Pożyczki z angielskiego',
    text:
        'Polski wziął z angielskiego sporo słów: komputer, weekend, smartfon. Języki ciągle się mieszają.',
    lang: 'Angielski',
  ),
  LanguageCuriosity(
    id: 'es-rr',
    title: 'Hiszpańskie „rr”',
    text:
        'Podwójne „rr” (perro) to wibrujące „r” — ćwicz jak silniczek: rrrr. Hiszpanie są z tego dumni!',
    lang: 'Hiszpański',
  ),
  LanguageCuriosity(
    id: 'es-gender',
    title: 'El i la',
    text:
        'W hiszpańskim rzeczowniki mają rodzaj: el (męski) i la (żeński). „Casa” to la casa — dom jest „żeński”.',
    lang: 'Hiszpański',
  ),
  LanguageCuriosity(
    id: 'es-speakers',
    title: 'Setki milionów',
    text:
        'Hiszpańskim mówi ponad 500 milionów ludzi — od Hiszpanii po Amerykę Łacińską.',
    lang: 'Hiszpański',
  ),
  LanguageCuriosity(
    id: 'ru-cases',
    title: 'Przypadki',
    text:
        'Rosyjski ma 6 przypadków — końcówki mówią, kto komu co robi. Na start wystarczy rozpoznawać formy!',
    lang: 'Rosyjski',
  ),
  LanguageCuriosity(
    id: 'ru-alphabet',
    title: 'Cyrylica',
    text:
        'Cyrylica wygląda obco, ale wiele liter przypomina łacińskie. Nauczysz się alfabetu szybciej, niż myślisz.',
    lang: 'Rosyjski',
  ),
  LanguageCuriosity(
    id: 'ru-nyet',
    title: '„Niet” i „da”',
    text:
        '„Да” (da) = tak, „Нет” (niet) = nie. Te dwa słowa już otwierają rozmowę!',
    lang: 'Rosyjski',
  ),
  LanguageCuriosity(
    id: 'mistake-ok',
    title: 'Błędy są OK',
    text:
        'Każdy błąd to sygnał dla mózgu: „tu warto powtórzyć”. Bez błędów nie ma nauki.',
  ),
  LanguageCuriosity(
    id: 'music',
    title: 'Piosenki pomagają',
    text:
        'Słuchanie piosenek w obcym języku utrwala rytm i wymowę — nawet gdy nie rozumiesz wszystkiego.',
  ),
  LanguageCuriosity(
    id: 'context',
    title: 'Kontekst > lista',
    text:
        'Słówko w zdaniu zapamiętujesz lepiej niż samotne na liście. Dlatego rozmowa AI też daje XP!',
  ),
  LanguageCuriosity(
    id: 'streak',
    title: 'Passa działa',
    text:
        'Krótka nauka codziennie bije długi maraton raz w tygodniu. Passa to Twój superpower.',
  ),
];

/// Bonus XP przy każdym awansie poziomu.
const levelUpBonusXp = 15;

/// Ciekawostka na dany poziom (deterministyczna + dopasowanie do języka).
LanguageCuriosity curiosityForLevel(int level, {String? lang}) {
  final pool = languageCuriosities
      .where((c) => c.lang == null || c.lang == lang)
      .toList();
  if (pool.isEmpty) return languageCuriosities.first;
  final idx = (level - 2).clamp(0, 1 << 20) % pool.length;
  return pool[idx];
}

/// Losowa ciekawostka (np. do przeglądania odblokowanych).
LanguageCuriosity randomCuriosity({String? lang, Random? rng}) {
  final pool = languageCuriosities
      .where((c) => c.lang == null || c.lang == lang)
      .toList();
  final r = rng ?? Random();
  return pool[r.nextInt(pool.length)];
}
