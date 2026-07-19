import 'dart:math';

/// Ciekawostka językowa odblokowana przy awansie poziomu.
class LanguageCuriosity {
  const LanguageCuriosity({
    required this.id,
    required this.title,
    required this.text,
    this.tip,
    this.lang,
  });

  final String id;
  final String title;
  final String text;

  /// Mini-wyzwanie / „spróbuj dziś” — motywacja do dalszej nauki.
  final String? tip;

  /// null = uniwersalna; inaczej nazwa języka z bazy.
  final String? lang;
}

/// Tytuł gracza odblokowywany od danego poziomu.
class PlayerTitle {
  const PlayerTitle({
    required this.minLevel,
    required this.title,
    required this.blurb,
  });

  final int minLevel;
  final String title;
  final String blurb;
}

const playerTitles = <PlayerTitle>[
  PlayerTitle(
    minLevel: 1,
    title: 'Nowicjuszka',
    blurb: 'Pierwsze kroki — każdy mistrz tu zaczynał.',
  ),
  PlayerTitle(
    minLevel: 2,
    title: 'Łowczyni słówek',
    blurb: 'Zbierasz słowa jak skarby!',
  ),
  PlayerTitle(
    minLevel: 4,
    title: 'Powtórkowa bohaterka',
    blurb: 'Wiesz, że powtórka > zapominanie.',
  ),
  PlayerTitle(
    minLevel: 6,
    title: 'Rozmówczyni',
    blurb: 'Nie boisz się gadać po obcemu.',
  ),
  PlayerTitle(
    minLevel: 8,
    title: 'Poliglotka junior',
    blurb: 'Mózg już przełącza języki jak kanały TV.',
  ),
  PlayerTitle(
    minLevel: 10,
    title: 'Mistrzyni passy',
    blurb: 'Codzienna nauka to Twój superpower.',
  ),
  PlayerTitle(
    minLevel: 12,
    title: 'Strażniczka słownika',
    blurb: 'Setki słów? Spokojnie — dasz radę.',
  ),
  PlayerTitle(
    minLevel: 15,
    title: 'Gwiazda języka',
    blurb: 'Świecisz przykładem — i XP!',
  ),
  PlayerTitle(
    minLevel: 20,
    title: 'Legenda Treningu',
    blurb: 'Anielka level MAX — język drży ze strachu.',
  ),
];

/// Aktualny tytuł dla poziomu gracza.
PlayerTitle titleForLevel(int level) {
  PlayerTitle best = playerTitles.first;
  for (final t in playerTitles) {
    if (level >= t.minLevel) best = t;
  }
  return best;
}

/// Czy przy tym poziomie odblokowano NOWY tytuł (nie tylko ciekawostkę).
PlayerTitle? newTitleAtLevel(int level) {
  for (final t in playerTitles) {
    if (t.minLevel == level && level > 1) return t;
  }
  return null;
}

const languageCuriosities = <LanguageCuriosity>[
  LanguageCuriosity(
    id: 'polyglot',
    title: 'Mózg lubi języki',
    text:
        'Nauka drugiego języka wzmacnia pamięć i koncentrację — jak siłownia dla mózgu!',
    tip: 'Dziś: 5 słówek na głos, nie tylko w głowie.',
  ),
  LanguageCuriosity(
    id: 'words-day',
    title: 'Kilka słów dziennie',
    text:
        'Wystarczy 5–10 nowych słówek dziennie, żeby w rok znać setki słów. Małe kroki działają.',
    tip: 'Cel na dziś: 7 nowych lub 7 powtórek.',
  ),
  LanguageCuriosity(
    id: 'cognates',
    title: 'Słowa-przyjaciele',
    text:
        'Wiele słów wygląda podobnie w różnych językach (np. „telefon”). To ułatwia naukę!',
    tip: 'Znajdź w bazie 3 słowa, które brzmią jak polskie.',
  ),
  LanguageCuriosity(
    id: 'speak-aloud',
    title: 'Głośno = lepiej',
    text:
        'Powtarzanie na głos utrwala słówka mocniej niż samo czytanie w głowie.',
    tip: 'Włącz 🔊 i powtórz każde słowo 2 razy.',
  ),
  LanguageCuriosity(
    id: 'sleep',
    title: 'Sen pomaga',
    text:
        'Po nauce sen „porządkuje” nowe słowa w pamięci. Dlatego powtórka rano bywa łatwiejsza.',
    tip: 'Krótka powtórka przed snem = bonus dla mózgu.',
  ),
  LanguageCuriosity(
    id: 'en-th',
    title: 'Angielskie „th”',
    text:
        'Dźwięk „th” (the, think) jest rzadki na świecie — stąd bywa trudny dla Polaków. Ćwiczenie robi mistrza!',
    tip: 'Powiedz: the · think · that · this — wolno.',
    lang: 'Angielski',
  ),
  LanguageCuriosity(
    id: 'en-most',
    title: 'Najpopularniejszy język',
    text:
        'Angielski jest najczęściej uczonym językiem obcym na świecie — masz towarzystwo milionów osób!',
    tip: 'Napisz 1 zdanie o sobie po angielsku w rozmowie AI.',
    lang: 'Angielski',
  ),
  LanguageCuriosity(
    id: 'en-loan',
    title: 'Pożyczki z angielskiego',
    text:
        'Polski wziął z angielskiego sporo słów: komputer, weekend, smartfon. Języki ciągle się mieszają.',
    tip: 'Wypisz 5 angielskich słów, których używasz po polsku.',
    lang: 'Angielski',
  ),
  LanguageCuriosity(
    id: 'en-silent',
    title: 'Ciche litery',
    text:
        'W angielskim czasem nie wymawia się litery (knife, write, listen). Pisownia i wymowa to dwa światy!',
    tip: 'Posłuchaj audio do „write” / „night” jeśli masz w bazie.',
    lang: 'Angielski',
  ),
  LanguageCuriosity(
    id: 'es-rr',
    title: 'Hiszpańskie „rr”',
    text:
        'Podwójne „rr” (perro) to wibrujące „r” — ćwicz jak silniczek: rrrr. Hiszpanie są z tego dumni!',
    tip: 'Ćwicz: perro · carro · rojo — 10 sekund.',
    lang: 'Hiszpański',
  ),
  LanguageCuriosity(
    id: 'es-gender',
    title: 'El i la',
    text:
        'W hiszpańskim rzeczowniki mają rodzaj: el (męski) i la (żeński). „Casa” to la casa — dom jest „żeński”.',
    tip: 'Przy 3 słówkach dodaj el/la na głos.',
    lang: 'Hiszpański',
  ),
  LanguageCuriosity(
    id: 'es-speakers',
    title: 'Setki milionów',
    text:
        'Hiszpańskim mówi ponad 500 milionów ludzi — od Hiszpanii po Amerykę Łacińską.',
    tip: 'Powiedz „hola” i „gracias” z uśmiechem 😊',
    lang: 'Hiszpański',
  ),
  LanguageCuriosity(
    id: 'es-ñ',
    title: 'Litera ñ',
    text:
        'Ñ (eñe) to dźwięk jak w polskim „ń”. Bez niej „año” (rok) stałoby się „ano” — zupełnie inne znaczenie!',
    tip: 'Znajdź w bazie słowo z ñ albo użyj klawiatury áéñ.',
    lang: 'Hiszpański',
  ),
  LanguageCuriosity(
    id: 'ru-cases',
    title: 'Przypadki',
    text:
        'Rosyjski ma 6 przypadków — końcówki mówią, kto komu co robi. Na start wystarczy rozpoznawać formy!',
    tip: 'Nie stresuj się przypadkami — najpierw łap całe zwroty.',
    lang: 'Rosyjski',
  ),
  LanguageCuriosity(
    id: 'ru-alphabet',
    title: 'Cyrylica',
    text:
        'Cyrylica wygląda obco, ale wiele liter przypomina łacińskie. Nauczysz się alfabetu szybciej, niż myślisz.',
    tip: 'Otwórz klawiaturę cyrylicy i napisz „привет”.',
    lang: 'Rosyjski',
  ),
  LanguageCuriosity(
    id: 'ru-nyet',
    title: '„Niet” i „da”',
    text:
        '„Да” (da) = tak, „Нет” (niet) = nie. Te dwa słowa już otwierają rozmowę!',
    tip: 'Odpowiedz AI raz „да” i raz „нет” w rozmowie.',
    lang: 'Rosyjski',
  ),
  LanguageCuriosity(
    id: 'ru-false',
    title: 'Fałszywi przyjaciele',
    text:
        'Rosyjskie „магазин” to sklep (nie magazyn!). Podobne słowa potrafią zaskoczyć.',
    tip: 'Zapamiętaj: магазин = sklep 🛒',
    lang: 'Rosyjski',
  ),
  LanguageCuriosity(
    id: 'mistake-ok',
    title: 'Błędy są OK',
    text:
        'Każdy błąd to sygnał dla mózgu: „tu warto powtórzyć”. Bez błędów nie ma nauki.',
    tip: 'Po błędzie od razu powtórz to samo słówko jeszcze raz.',
  ),
  LanguageCuriosity(
    id: 'music',
    title: 'Piosenki pomagają',
    text:
        'Słuchanie piosenek w obcym języku utrwala rytm i wymowę — nawet gdy nie rozumiesz wszystkiego.',
    tip: 'Dziś: 1 piosenka w języku, którego się uczysz.',
  ),
  LanguageCuriosity(
    id: 'context',
    title: 'Kontekst > lista',
    text:
        'Słówko w zdaniu zapamiętujesz lepiej niż samotne na liście. Dlatego rozmowa AI też daje XP!',
    tip: 'Zrób rozmowę AI i użyj 1 słowa z dzisiejszej sesji.',
  ),
  LanguageCuriosity(
    id: 'streak',
    title: 'Passa działa',
    text:
        'Krótka nauka codziennie bije długi maraton raz w tygodniu. Passa to Twój superpower.',
    tip: 'Nie zrywaj passy — nawet 3 minuty się liczą.',
  ),
  LanguageCuriosity(
    id: 'labels',
    title: 'Etykietki w domu',
    text:
        'Naklejki na przedmiotach (drzwi, lampa, kubek) sprawiają, że język „żyje” wokół Ciebie.',
    tip: 'Nazwij po obcemu 3 rzeczy na biurku.',
  ),
  LanguageCuriosity(
    id: 'emotion',
    title: 'Emocja = pamięć',
    text:
        'Słowa powiązane z emocją (śmiech, zdziwienie, ulubione jedzenie) zapamiętujesz szybciej.',
    tip: 'Naucz się słowa na coś, co naprawdę lubisz.',
  ),
  LanguageCuriosity(
    id: 'shadow',
    title: 'Shadowing',
    text:
        'Powtarzanie natychmiast po usłyszeniu (jak echo) trenują wymowę i płynność.',
    tip: 'Po audio powiedz słowo w tej samej sekundzie.',
  ),
  LanguageCuriosity(
    id: 'hard-mode',
    title: 'Trudne = skarb',
    text:
        'Słówka oznaczone jako trudne wracają częściej — to nie kara, tylko trening mistrzowski.',
    tip: 'Oznacz 1 słówko jako trudne i pokonaj je jutro.',
  ),
];

/// Bonus XP przy awansie — trochę rośnie z poziomem (więcej chęci iść dalej).
int levelUpBonusXpFor(int level) => 12 + (level * 3).clamp(3, 60);

/// @Deprecated — użyj [levelUpBonusXpFor]; zostawione dla starych testów.
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

/// Wszystkie ciekawostki odblokowane do danego poziomu (album).
List<LanguageCuriosity> unlockedCuriosities({
  required int rewardedLevel,
  String? lang,
}) {
  if (rewardedLevel < 2) return const [];
  final seen = <String>{};
  final out = <LanguageCuriosity>[];
  for (var lv = 2; lv <= rewardedLevel; lv++) {
    final c = curiosityForLevel(lv, lang: lang);
    if (seen.add(c.id)) out.add(c);
  }
  return out;
}

/// Losowa ciekawostka (np. do przeglądania odblokowanych).
LanguageCuriosity randomCuriosity({String? lang, Random? rng}) {
  final pool = languageCuriosities
      .where((c) => c.lang == null || c.lang == lang)
      .toList();
  final r = rng ?? Random();
  return pool[r.nextInt(pool.length)];
}
