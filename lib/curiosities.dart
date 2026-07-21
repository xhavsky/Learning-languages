import 'dart:math';

import 'l10n.dart';

/// Tekst w 4 językach UI (PL / EN / ES / RU).
class I18nStr {
  const I18nStr({
    required this.pl,
    required this.en,
    required this.es,
    required this.ru,
  });

  final String pl;
  final String en;
  final String es;
  final String ru;

  String of(UiLang lang) => switch (lang) {
        UiLang.pl => pl,
        UiLang.en => en,
        UiLang.es => es,
        UiLang.ru => ru,
      };
}

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

class _CuriosityDef {
  const _CuriosityDef({
    required this.id,
    required this.title,
    required this.text,
    this.tip,
    this.lang,
  });

  final String id;
  final I18nStr title;
  final I18nStr text;
  final I18nStr? tip;
  final String? lang;

  LanguageCuriosity resolve(UiLang ui) => LanguageCuriosity(
        id: id,
        title: title.of(ui),
        text: text.of(ui),
        tip: tip?.of(ui),
        lang: lang,
      );
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

class _TitleDef {
  const _TitleDef({
    required this.minLevel,
    required this.title,
    required this.blurb,
  });

  final int minLevel;
  final I18nStr title;
  final I18nStr blurb;

  PlayerTitle resolve(UiLang ui) => PlayerTitle(
        minLevel: minLevel,
        title: title.of(ui),
        blurb: blurb.of(ui),
      );
}

const _playerTitleDefs = <_TitleDef>[
  _TitleDef(
    minLevel: 1,
    title: I18nStr(
      pl: 'Nowicjuszka',
      en: 'Newbie',
      es: 'Novata',
      ru: 'Новичок',
    ),
    blurb: I18nStr(
      pl: 'Pierwsze kroki — każdy mistrz tu zaczynał.',
      en: 'First steps — every master started here.',
      es: 'Primeros pasos — todo maestro empezó aquí.',
      ru: 'Первые шаги — каждый мастер начинал здесь.',
    ),
  ),
  _TitleDef(
    minLevel: 2,
    title: I18nStr(
      pl: 'Łowczyni słówek',
      en: 'Word hunter',
      es: 'Cazadora de palabras',
      ru: 'Охотница за словами',
    ),
    blurb: I18nStr(
      pl: 'Zbierasz słowa jak skarby!',
      en: 'You collect words like treasures!',
      es: '¡Coleccionas palabras como tesoros!',
      ru: 'Собираешь слова как сокровища!',
    ),
  ),
  _TitleDef(
    minLevel: 4,
    title: I18nStr(
      pl: 'Powtórkowa bohaterka',
      en: 'Review heroine',
      es: 'Heroína del repaso',
      ru: 'Героиня повторений',
    ),
    blurb: I18nStr(
      pl: 'Wiesz, że powtórka > zapominanie.',
      en: 'You know review beats forgetting.',
      es: 'Sabes que repasar > olvidar.',
      ru: 'Знаешь: повторение > забывание.',
    ),
  ),
  _TitleDef(
    minLevel: 6,
    title: I18nStr(
      pl: 'Rozmówczyni',
      en: 'Conversationalist',
      es: 'Conversadora',
      ru: 'Собеседница',
    ),
    blurb: I18nStr(
      pl: 'Nie boisz się gadać po obcemu.',
      en: 'You’re not afraid to chat in a foreign language.',
      es: 'No temes hablar en otro idioma.',
      ru: 'Не боишься болтать на чужом языке.',
    ),
  ),
  _TitleDef(
    minLevel: 8,
    title: I18nStr(
      pl: 'Poliglotka junior',
      en: 'Junior polyglot',
      es: 'Políglota junior',
      ru: 'Полиглот-джуниор',
    ),
    blurb: I18nStr(
      pl: 'Mózg już przełącza języki jak kanały TV.',
      en: 'Your brain flips languages like TV channels.',
      es: 'Tu cerebro cambia de idioma como de canal.',
      ru: 'Мозг переключает языки как каналы ТВ.',
    ),
  ),
  _TitleDef(
    minLevel: 10,
    title: I18nStr(
      pl: 'Mistrzyni passy',
      en: 'Streak master',
      es: 'Maestra de la racha',
      ru: 'Мастер серии',
    ),
    blurb: I18nStr(
      pl: 'Codzienna nauka to Twój superpower.',
      en: 'Daily practice is your superpower.',
      es: 'Practicar cada día es tu superpoder.',
      ru: 'Ежедневная учёба — твой суперсила.',
    ),
  ),
  _TitleDef(
    minLevel: 12,
    title: I18nStr(
      pl: 'Strażniczka słownika',
      en: 'Dictionary guardian',
      es: 'Guardiana del diccionario',
      ru: 'Хранительница словаря',
    ),
    blurb: I18nStr(
      pl: 'Setki słów? Spokojnie — dasz radę.',
      en: 'Hundreds of words? You’ve got this.',
      es: '¿Cientos de palabras? Tú puedes.',
      ru: 'Сотни слов? Спокойно — справишься.',
    ),
  ),
  _TitleDef(
    minLevel: 15,
    title: I18nStr(
      pl: 'Gwiazda języka',
      en: 'Language star',
      es: 'Estrella del idioma',
      ru: 'Звезда языка',
    ),
    blurb: I18nStr(
      pl: 'Świecisz przykładem — i XP!',
      en: 'You shine by example — and XP!',
      es: '¡Brillas con el ejemplo — y XP!',
      ru: 'Сияешь примером — и XP!',
    ),
  ),
  _TitleDef(
    minLevel: 20,
    title: I18nStr(
      pl: 'Legenda Treningu',
      en: 'Training legend',
      es: 'Leyenda del entrenamiento',
      ru: 'Легенда тренировки',
    ),
    blurb: I18nStr(
      pl: 'Poziom MAX — język drży ze strachu.',
      en: 'Level MAX — the language shakes in fear.',
      es: 'Nivel MAX — el idioma tiembla.',
      ru: 'Уровень MAX — язык дрожит от страха.',
    ),
  ),
];

/// Lista tytułów (po polsku) — kompatybilność ze starymi testami.
List<PlayerTitle> get playerTitles =>
    _playerTitleDefs.map((t) => t.resolve(UiLang.pl)).toList();

/// Aktualny tytuł dla poziomu gracza.
PlayerTitle titleForLevel(int level, {UiLang uiLang = UiLang.pl}) {
  var best = _playerTitleDefs.first;
  for (final t in _playerTitleDefs) {
    if (level >= t.minLevel) best = t;
  }
  return best.resolve(uiLang);
}

/// Czy przy tym poziomie odblokowano NOWY tytuł (nie tylko ciekawostkę).
PlayerTitle? newTitleAtLevel(int level, {UiLang uiLang = UiLang.pl}) {
  for (final t in _playerTitleDefs) {
    if (t.minLevel == level && level > 1) return t.resolve(uiLang);
  }
  return null;
}

const _curiosityDefs = <_CuriosityDef>[
  _CuriosityDef(
    id: 'polyglot',
    title: I18nStr(
      pl: 'Mózg lubi języki',
      en: 'The brain loves languages',
      es: 'El cerebro ama los idiomas',
      ru: 'Мозг любит языки',
    ),
    text: I18nStr(
      pl: 'Nauka drugiego języka wzmacnia pamięć i koncentrację — jak siłownia dla mózgu!',
      en: 'Learning a second language boosts memory and focus — like a gym for your brain!',
      es: 'Aprender un segundo idioma fortalece la memoria y la concentración — ¡como un gimnasio para el cerebro!',
      ru: 'Изучение второго языка укрепляет память и внимание — как спортзал для мозга!',
    ),
    tip: I18nStr(
      pl: 'Dziś: 5 słówek na głos, nie tylko w głowie.',
      en: 'Today: say 5 words out loud, not just in your head.',
      es: 'Hoy: di 5 palabras en voz alta, no solo en la mente.',
      ru: 'Сегодня: 5 слов вслух, не только в голове.',
    ),
  ),
  _CuriosityDef(
    id: 'words-day',
    title: I18nStr(
      pl: 'Kilka słów dziennie',
      en: 'A few words a day',
      es: 'Unas palabras al día',
      ru: 'Несколько слов в день',
    ),
    text: I18nStr(
      pl: 'Wystarczy 5–10 nowych słówek dziennie, żeby w rok znać setki słów. Małe kroki działają.',
      en: 'Just 5–10 new words a day and in a year you’ll know hundreds. Small steps work.',
      es: 'Con 5–10 palabras nuevas al día, en un año sabrás cientos. Los pasos pequeños funcionan.',
      ru: 'Достаточно 5–10 новых слов в день — за год узнаешь сотни. Маленькие шаги работают.',
    ),
    tip: I18nStr(
      pl: 'Cel na dziś: 7 nowych lub 7 powtórek.',
      en: 'Goal today: 7 new words or 7 reviews.',
      es: 'Meta de hoy: 7 nuevas o 7 repasos.',
      ru: 'Цель на сегодня: 7 новых или 7 повторений.',
    ),
  ),
  _CuriosityDef(
    id: 'cognates',
    title: I18nStr(
      pl: 'Słowa-przyjaciele',
      en: 'Friend words',
      es: 'Palabras amigas',
      ru: 'Слова-друзья',
    ),
    text: I18nStr(
      pl: 'Wiele słów wygląda podobnie w różnych językach (np. „telefon”). To ułatwia naukę!',
      en: 'Many words look alike across languages (e.g. “telephone”). That makes learning easier!',
      es: 'Muchas palabras se parecen en distintos idiomas (p. ej. «teléfono»). ¡Eso facilita aprender!',
      ru: 'Многие слова похожи в разных языках (напр. «телефон»). Это облегчает учёбу!',
    ),
    tip: I18nStr(
      pl: 'Znajdź w bazie 3 słowa, które brzmią jak polskie.',
      en: 'Find 3 words in your list that sound like Polish ones.',
      es: 'Encuentra en la base 3 palabras que suenen como en polaco.',
      ru: 'Найди в базе 3 слова, похожие на польские.',
    ),
  ),
  _CuriosityDef(
    id: 'speak-aloud',
    title: I18nStr(
      pl: 'Głośno = lepiej',
      en: 'Out loud = better',
      es: 'En voz alta = mejor',
      ru: 'Вслух = лучше',
    ),
    text: I18nStr(
      pl: 'Powtarzanie na głos utrwala słówka mocniej niż samo czytanie w głowie.',
      en: 'Saying words out loud sticks better than only reading them silently.',
      es: 'Repetir en voz alta fija las palabras mejor que solo leerlas en silencio.',
      ru: 'Повторение вслух закрепляет слова сильнее, чем чтение про себя.',
    ),
    tip: I18nStr(
      pl: 'Włącz 🔊 i powtórz każde słowo 2 razy.',
      en: 'Turn on 🔊 and repeat each word twice.',
      es: 'Activa 🔊 y repite cada palabra 2 veces.',
      ru: 'Включи 🔊 и повтори каждое слово 2 раза.',
    ),
  ),
  _CuriosityDef(
    id: 'sleep',
    title: I18nStr(
      pl: 'Sen pomaga',
      en: 'Sleep helps',
      es: 'Dormir ayuda',
      ru: 'Сон помогает',
    ),
    text: I18nStr(
      pl: 'Po nauce sen „porządkuje” nowe słowa w pamięci. Dlatego powtórka rano bywa łatwiejsza.',
      en: 'After studying, sleep “sorts” new words in memory. That’s why morning review often feels easier.',
      es: 'Tras estudiar, el sueño «ordena» las palabras nuevas. Por eso el repaso de la mañana suele ser más fácil.',
      ru: 'После учёбы сон «раскладывает» новые слова в памяти. Поэтому утреннее повторение часто легче.',
    ),
    tip: I18nStr(
      pl: 'Krótka powtórka przed snem = bonus dla mózgu.',
      en: 'A short review before bed = a bonus for your brain.',
      es: 'Un repaso corto antes de dormir = bonus para el cerebro.',
      ru: 'Короткое повторение перед сном = бонус для мозга.',
    ),
  ),
  _CuriosityDef(
    id: 'en-th',
    title: I18nStr(
      pl: 'Angielskie „th”',
      en: 'English “th”',
      es: 'La “th” inglesa',
      ru: 'Английская «th»',
    ),
    text: I18nStr(
      pl: 'Dźwięk „th” (the, think) jest rzadki na świecie — stąd bywa trudny dla Polaków. Ćwiczenie robi mistrza!',
      en: 'The “th” sound (the, think) is rare worldwide — that’s why it can be tricky. Practice makes perfect!',
      es: 'El sonido «th» (the, think) es raro en el mundo — por eso puede costar. ¡La práctica hace al maestro!',
      ru: 'Звук «th» (the, think) редкий в мире — поэтому бывает трудным. Практика творит чудеса!',
    ),
    tip: I18nStr(
      pl: 'Powiedz: the · think · that · this — wolno.',
      en: 'Say: the · think · that · this — slowly.',
      es: 'Di: the · think · that · this — despacio.',
      ru: 'Скажи: the · think · that · this — медленно.',
    ),
    lang: 'Angielski',
  ),
  _CuriosityDef(
    id: 'en-most',
    title: I18nStr(
      pl: 'Najpopularniejszy język',
      en: 'The most popular language',
      es: 'El idioma más popular',
      ru: 'Самый популярный язык',
    ),
    text: I18nStr(
      pl: 'Angielski jest najczęściej uczonym językiem obcym na świecie — masz towarzystwo milionów osób!',
      en: 'English is the most studied foreign language in the world — you’re in the company of millions!',
      es: 'El inglés es el idioma extranjero más estudiado del mundo — ¡tienes compañía de millones!',
      ru: 'Английский — самый изучаемый иностранный язык в мире — ты в компании миллионов!',
    ),
    tip: I18nStr(
      pl: 'Napisz 1 zdanie o sobie po angielsku w rozmowie AI.',
      en: 'Write 1 sentence about yourself in English in the AI chat.',
      es: 'Escribe 1 frase sobre ti en inglés en el chat de IA.',
      ru: 'Напиши 1 предложение о себе по-английски в чате ИИ.',
    ),
    lang: 'Angielski',
  ),
  _CuriosityDef(
    id: 'en-loan',
    title: I18nStr(
      pl: 'Pożyczki z angielskiego',
      en: 'Loanwords from English',
      es: 'Préstamos del inglés',
      ru: 'Заимствования из английского',
    ),
    text: I18nStr(
      pl: 'Polski wziął z angielskiego sporo słów: komputer, weekend, smartfon. Języki ciągle się mieszają.',
      en: 'Polish borrowed many words from English: komputer, weekend, smartfon. Languages keep mixing.',
      es: 'El polaco tomó muchas palabras del inglés: komputer, weekend, smartfon. Los idiomas se mezclan.',
      ru: 'Польский взял из английского много слов: komputer, weekend, smartfon. Языки постоянно смешиваются.',
    ),
    tip: I18nStr(
      pl: 'Wypisz 5 angielskich słów, których używasz po polsku.',
      en: 'List 5 English words you use in Polish.',
      es: 'Anota 5 palabras inglesas que usas en polaco.',
      ru: 'Выпиши 5 английских слов, которые используешь по-польски.',
    ),
    lang: 'Angielski',
  ),
  _CuriosityDef(
    id: 'en-silent',
    title: I18nStr(
      pl: 'Ciche litery',
      en: 'Silent letters',
      es: 'Letras mudas',
      ru: 'Непроизносимые буквы',
    ),
    text: I18nStr(
      pl: 'W angielskim czasem nie wymawia się litery (knife, write, listen). Pisownia i wymowa to dwa światy!',
      en: 'In English some letters are silent (knife, write, listen). Spelling and pronunciation are two worlds!',
      es: 'En inglés a veces no se pronuncian letras (knife, write, listen). ¡Ortografía y pronunciación son dos mundos!',
      ru: 'В английском иногда буквы не произносятся (knife, write, listen). Написание и произношение — два мира!',
    ),
    tip: I18nStr(
      pl: 'Posłuchaj audio do „write” / „night” jeśli masz w bazie.',
      en: 'Listen to audio for “write” / “night” if you have them.',
      es: 'Escucha el audio de «write» / «night» si los tienes.',
      ru: 'Послушай аудио к «write» / «night», если есть в базе.',
    ),
    lang: 'Angielski',
  ),
  _CuriosityDef(
    id: 'es-rr',
    title: I18nStr(
      pl: 'Hiszpańskie „rr”',
      en: 'Spanish “rr”',
      es: 'La «rr» española',
      ru: 'Испанская «rr»',
    ),
    text: I18nStr(
      pl: 'Podwójne „rr” (perro) to wibrujące „r” — ćwicz jak silniczek: rrrr. Hiszpanie są z tego dumni!',
      en: 'Double “rr” (perro) is a rolled r — practice like a little motor: rrrr. Spaniards are proud of it!',
      es: 'La «rr» doble (perro) es una r vibrante — practícala como un motorcito: rrrr. ¡Los hispanohablantes están orgullosos!',
      ru: 'Двойная «rr» (perro) — раскатистое «r». Тренируй как моторчик: rrrr. Испанцы этим гордятся!',
    ),
    tip: I18nStr(
      pl: 'Ćwicz: perro · carro · rojo — 10 sekund.',
      en: 'Practice: perro · carro · rojo — 10 seconds.',
      es: 'Practica: perro · carro · rojo — 10 segundos.',
      ru: 'Тренируй: perro · carro · rojo — 10 секунд.',
    ),
    lang: 'Hiszpański',
  ),
  _CuriosityDef(
    id: 'es-gender',
    title: I18nStr(
      pl: 'El i la',
      en: 'El and la',
      es: 'El y la',
      ru: 'El и la',
    ),
    text: I18nStr(
      pl: 'W hiszpańskim rzeczowniki mają rodzaj: el (męski) i la (żeński). „Casa” to la casa — dom jest „żeński”.',
      en: 'In Spanish nouns have gender: el (masculine) and la (feminine). “Casa” is la casa — the house is “feminine”.',
      es: 'En español los sustantivos tienen género: el (masculino) y la (femenino). «Casa» es la casa.',
      ru: 'В испанском у существительных есть род: el (мужской) и la (женский). «Casa» — la casa.',
    ),
    tip: I18nStr(
      pl: 'Przy 3 słówkach dodaj el/la na głos.',
      en: 'For 3 words, say el/la out loud.',
      es: 'Con 3 palabras di el/la en voz alta.',
      ru: 'К 3 словам добавь el/la вслух.',
    ),
    lang: 'Hiszpański',
  ),
  _CuriosityDef(
    id: 'es-speakers',
    title: I18nStr(
      pl: 'Setki milionów',
      en: 'Hundreds of millions',
      es: 'Cientos de millones',
      ru: 'Сотни миллионов',
    ),
    text: I18nStr(
      pl: 'Hiszpańskim mówi ponad 500 milionów ludzi — od Hiszpanii po Amerykę Łacińską.',
      en: 'Spanish is spoken by over 500 million people — from Spain to Latin America.',
      es: 'El español lo hablan más de 500 millones de personas — de España a América Latina.',
      ru: 'На испанском говорят более 500 миллионов людей — от Испании до Латинской Америки.',
    ),
    tip: I18nStr(
      pl: 'Powiedz „hola” i „gracias” z uśmiechem 😊',
      en: 'Say “hola” and “gracias” with a smile 😊',
      es: 'Di «hola» y «gracias» con una sonrisa 😊',
      ru: 'Скажи «hola» и «gracias» с улыбкой 😊',
    ),
    lang: 'Hiszpański',
  ),
  _CuriosityDef(
    id: 'es-ñ',
    title: I18nStr(
      pl: 'Litera ñ',
      en: 'The letter ñ',
      es: 'La letra ñ',
      ru: 'Буква ñ',
    ),
    text: I18nStr(
      pl: 'Ñ (eñe) to dźwięk jak w polskim „ń”. Bez niej „año” (rok) stałoby się „ano” — zupełnie inne znaczenie!',
      en: 'Ñ (eñe) sounds like Polish “ń”. Without it, “año” (year) becomes “ano” — a totally different meaning!',
      es: 'Ñ (eñe) suena como la «ń» polaca. Sin ella, «año» se vuelve «ano» — ¡otro significado!',
      ru: 'Ñ (eñe) звучит как польская «ń». Без неё «año» (год) станет «ano» — совсем другое значение!',
    ),
    tip: I18nStr(
      pl: 'Znajdź w bazie słowo z ñ albo użyj klawiatury áéñ.',
      en: 'Find a word with ñ in your list or use the áéñ keyboard.',
      es: 'Busca una palabra con ñ o usa el teclado áéñ.',
      ru: 'Найди в базе слово с ñ или используй клавиатуру áéñ.',
    ),
    lang: 'Hiszpański',
  ),
  _CuriosityDef(
    id: 'ru-cases',
    title: I18nStr(
      pl: 'Przypadki',
      en: 'Cases',
      es: 'Casos',
      ru: 'Падежи',
    ),
    text: I18nStr(
      pl: 'Rosyjski ma 6 przypadków — końcówki mówią, kto komu co robi. Na start wystarczy rozpoznawać formy!',
      en: 'Russian has 6 cases — endings show who does what to whom. At first, just recognizing forms is enough!',
      es: 'El ruso tiene 6 casos — las terminaciones dicen quién hace qué a quién. ¡Al inicio basta reconocer formas!',
      ru: 'В русском 6 падежей — окончания показывают, кто кому что делает. На старте достаточно узнавать формы!',
    ),
    tip: I18nStr(
      pl: 'Nie stresuj się przypadkami — najpierw łap całe zwroty.',
      en: 'Don’t stress about cases — first catch whole phrases.',
      es: 'No te estreses con los casos — primero atrapa frases enteras.',
      ru: 'Не волнуйся из‑за падежей — сначала лови целые фразы.',
    ),
    lang: 'Rosyjski',
  ),
  _CuriosityDef(
    id: 'ru-alphabet',
    title: I18nStr(
      pl: 'Cyrylica',
      en: 'Cyrillic',
      es: 'Cirílico',
      ru: 'Кириллица',
    ),
    text: I18nStr(
      pl: 'Cyrylica wygląda obco, ale wiele liter przypomina łacińskie. Nauczysz się alfabetu szybciej, niż myślisz.',
      en: 'Cyrillic looks foreign, but many letters resemble Latin ones. You’ll learn the alphabet faster than you think.',
      es: 'El cirílico parece raro, pero muchas letras recuerdan al latino. Aprenderás el alfabeto más rápido de lo que crees.',
      ru: 'Кириллица кажется чужой, но многие буквы похожи на латинские. Алфавит выучишь быстрее, чем думаешь.',
    ),
    tip: I18nStr(
      pl: 'Otwórz klawiaturę cyrylicy i napisz „привет”.',
      en: 'Open the Cyrillic keyboard and type “привет”.',
      es: 'Abre el teclado cirílico y escribe «привет».',
      ru: 'Открой кириллическую клавиатуру и напиши «привет».',
    ),
    lang: 'Rosyjski',
  ),
  _CuriosityDef(
    id: 'ru-nyet',
    title: I18nStr(
      pl: '„Niet” i „da”',
      en: '“Nyet” and “da”',
      es: '«Niet» y «da»',
      ru: '«Нет» и «да»',
    ),
    text: I18nStr(
      pl: '„Да” (da) = tak, „Нет” (niet) = nie. Te dwa słowa już otwierają rozmowę!',
      en: '“Да” (da) = yes, “Нет” (nyet) = no. These two words already open a chat!',
      es: '«Да» (da) = sí, «Нет» (niet) = no. ¡Estas dos palabras ya abren una conversación!',
      ru: '«Да» = yes, «Нет» = no. Эти два слова уже открывают разговор!',
    ),
    tip: I18nStr(
      pl: 'Odpowiedz AI raz „да” i raz „нет” w rozmowie.',
      en: 'Answer the AI once with “да” and once with “нет”.',
      es: 'Responde a la IA una vez «да» y una vez «нет».',
      ru: 'Ответь ИИ один раз «да» и один раз «нет».',
    ),
    lang: 'Rosyjski',
  ),
  _CuriosityDef(
    id: 'ru-false',
    title: I18nStr(
      pl: 'Fałszywi przyjaciele',
      en: 'False friends',
      es: 'Falsos amigos',
      ru: 'Ложные друзья',
    ),
    text: I18nStr(
      pl: 'Rosyjskie „магазин” to sklep (nie magazyn!). Podobne słowa potrafią zaskoczyć.',
      en: 'Russian “магазин” means shop (not “magazine”!). Similar words can surprise you.',
      es: 'El ruso «магазин» es tienda (¡no almacén!). Las palabras parecidas pueden sorprender.',
      ru: 'Русское «магазин» — это shop (не «magazine»!). Похожие слова умеют удивлять.',
    ),
    tip: I18nStr(
      pl: 'Zapamiętaj: магазин = sklep 🛒',
      en: 'Remember: магазин = shop 🛒',
      es: 'Recuerda: магазин = tienda 🛒',
      ru: 'Запомни: магазин = shop 🛒',
    ),
    lang: 'Rosyjski',
  ),
  _CuriosityDef(
    id: 'mistake-ok',
    title: I18nStr(
      pl: 'Błędy są OK',
      en: 'Mistakes are OK',
      es: 'Los errores están bien',
      ru: 'Ошибки — это ОК',
    ),
    text: I18nStr(
      pl: 'Każdy błąd to sygnał dla mózgu: „tu warto powtórzyć”. Bez błędów nie ma nauki.',
      en: 'Every mistake tells your brain: “worth reviewing here.” No mistakes, no learning.',
      es: 'Cada error es una señal para el cerebro: «aquí conviene repasar». Sin errores no hay aprendizaje.',
      ru: 'Каждая ошибка — сигнал мозгу: «здесь стоит повторить». Без ошибок нет учёбы.',
    ),
    tip: I18nStr(
      pl: 'Po błędzie od razu powtórz to samo słówko jeszcze raz.',
      en: 'After a mistake, repeat the same word right away.',
      es: 'Tras un error, repite la misma palabra de inmediato.',
      ru: 'После ошибки сразу повтори то же слово ещё раз.',
    ),
  ),
  _CuriosityDef(
    id: 'music',
    title: I18nStr(
      pl: 'Piosenki pomagają',
      en: 'Songs help',
      es: 'Las canciones ayudan',
      ru: 'Песни помогают',
    ),
    text: I18nStr(
      pl: 'Słuchanie piosenek w obcym języku utrwala rytm i wymowę — nawet gdy nie rozumiesz wszystkiego.',
      en: 'Listening to songs in a foreign language trains rhythm and pronunciation — even if you don’t understand everything.',
      es: 'Escuchar canciones en otro idioma fija el ritmo y la pronunciación — aunque no lo entiendas todo.',
      ru: 'Слушание песен на чужом языке закрепляет ритм и произношение — даже если не всё понятно.',
    ),
    tip: I18nStr(
      pl: 'Dziś: 1 piosenka w języku, którego się uczysz.',
      en: 'Today: 1 song in the language you’re learning.',
      es: 'Hoy: 1 canción en el idioma que estás aprendiendo.',
      ru: 'Сегодня: 1 песня на языке, который учишь.',
    ),
  ),
  _CuriosityDef(
    id: 'context',
    title: I18nStr(
      pl: 'Kontekst > lista',
      en: 'Context > list',
      es: 'Contexto > lista',
      ru: 'Контекст > список',
    ),
    text: I18nStr(
      pl: 'Słówko w zdaniu zapamiętujesz lepiej niż samotne na liście. Dlatego rozmowa AI też daje XP!',
      en: 'A word in a sentence sticks better than alone on a list. That’s why AI chat also gives XP!',
      es: 'Una palabra en una frase se recuerda mejor que sola en una lista. ¡Por eso el chat de IA también da XP!',
      ru: 'Слово в предложении запоминается лучше, чем одно в списке. Поэтому чат с ИИ тоже даёт XP!',
    ),
    tip: I18nStr(
      pl: 'Zrób rozmowę AI i użyj 1 słowa z dzisiejszej sesji.',
      en: 'Do an AI chat and use 1 word from today’s session.',
      es: 'Haz un chat con la IA y usa 1 palabra de la sesión de hoy.',
      ru: 'Сделай чат с ИИ и используй 1 слово из сегодняшней сессии.',
    ),
  ),
  _CuriosityDef(
    id: 'streak',
    title: I18nStr(
      pl: 'Passa działa',
      en: 'Streaks work',
      es: 'Las rachas funcionan',
      ru: 'Серия работает',
    ),
    text: I18nStr(
      pl: 'Krótka nauka codziennie bije długi maraton raz w tygodniu. Passa to Twój superpower.',
      en: 'Short daily practice beats a long marathon once a week. Your streak is your superpower.',
      es: 'Estudiar un poco cada día gana a un maratón semanal. La racha es tu superpoder.',
      ru: 'Короткая учёба каждый день бьёт длинный марафон раз в неделю. Серия — твоя суперсила.',
    ),
    tip: I18nStr(
      pl: 'Nie zrywaj passy — nawet 3 minuty się liczą.',
      en: 'Don’t break the streak — even 3 minutes count.',
      es: 'No rompas la racha — incluso 3 minutos cuentan.',
      ru: 'Не срывай серию — даже 3 минуты считаются.',
    ),
  ),
  _CuriosityDef(
    id: 'labels',
    title: I18nStr(
      pl: 'Etykietki w domu',
      en: 'Labels at home',
      es: 'Etiquetas en casa',
      ru: 'Наклейки дома',
    ),
    text: I18nStr(
      pl: 'Naklejki na przedmiotach (drzwi, lampa, kubek) sprawiają, że język „żyje” wokół Ciebie.',
      en: 'Stickers on objects (door, lamp, mug) make the language “live” around you.',
      es: 'Pegatinas en objetos (puerta, lámpara, taza) hacen que el idioma «viva» a tu alrededor.',
      ru: 'Наклейки на предметах (дверь, лампа, кружка) делают язык «живым» вокруг тебя.',
    ),
    tip: I18nStr(
      pl: 'Nazwij po obcemu 3 rzeczy na biurku.',
      en: 'Name 3 things on your desk in the foreign language.',
      es: 'Nombra 3 cosas del escritorio en el idioma extranjero.',
      ru: 'Назови по-иностранному 3 вещи на столе.',
    ),
  ),
  _CuriosityDef(
    id: 'emotion',
    title: I18nStr(
      pl: 'Emocja = pamięć',
      en: 'Emotion = memory',
      es: 'Emoción = memoria',
      ru: 'Эмоция = память',
    ),
    text: I18nStr(
      pl: 'Słowa powiązane z emocją (śmiech, zdziwienie, ulubione jedzenie) zapamiętujesz szybciej.',
      en: 'Words linked to emotion (laughter, surprise, favorite food) stick faster.',
      es: 'Las palabras ligadas a una emoción (risa, sorpresa, comida favorita) se recuerdan antes.',
      ru: 'Слова, связанные с эмоцией (смех, удивление, любимая еда), запоминаются быстрее.',
    ),
    tip: I18nStr(
      pl: 'Naucz się słowa na coś, co naprawdę lubisz.',
      en: 'Learn a word for something you really like.',
      es: 'Aprende una palabra de algo que de verdad te gusta.',
      ru: 'Выучи слово для чего‑то, что тебе правда нравится.',
    ),
  ),
  _CuriosityDef(
    id: 'shadow',
    title: I18nStr(
      pl: 'Shadowing',
      en: 'Shadowing',
      es: 'Shadowing',
      ru: 'Shadowing',
    ),
    text: I18nStr(
      pl: 'Powtarzanie natychmiast po usłyszeniu (jak echo) trenują wymowę i płynność.',
      en: 'Repeating right after you hear it (like an echo) trains pronunciation and fluency.',
      es: 'Repetir justo después de oírlo (como un eco) entrena la pronunciación y la fluidez.',
      ru: 'Повторение сразу после услышанного (как эхо) тренирует произношение и беглость.',
    ),
    tip: I18nStr(
      pl: 'Po audio powiedz słowo w tej samej sekundzie.',
      en: 'After the audio, say the word in the same second.',
      es: 'Tras el audio, di la palabra en el mismo segundo.',
      ru: 'После аудио скажи слово в ту же секунду.',
    ),
  ),
  _CuriosityDef(
    id: 'hard-mode',
    title: I18nStr(
      pl: 'Trudne = skarb',
      en: 'Hard = treasure',
      es: 'Difícil = tesoro',
      ru: 'Сложное = сокровище',
    ),
    text: I18nStr(
      pl: 'Słówka oznaczone jako trudne wracają częściej — to nie kara, tylko trening mistrzowski.',
      en: 'Words marked hard come back more often — not a punishment, just master training.',
      es: 'Las palabras marcadas como difíciles vuelven más — no es castigo, es entrenamiento de maestra.',
      ru: 'Слова, отмеченные как сложные, возвращаются чаще — это не наказание, а мастерская тренировка.',
    ),
    tip: I18nStr(
      pl: 'Oznacz 1 słówko jako trudne i pokonaj je jutro.',
      en: 'Mark 1 word as hard and beat it tomorrow.',
      es: 'Marca 1 palabra como difícil y véncela mañana.',
      ru: 'Отметь 1 слово как сложное и победи его завтра.',
    ),
  ),
];

/// Lista ciekawostek (po polsku) — kompatybilność ze starymi testami.
List<LanguageCuriosity> get languageCuriosities =>
    _curiosityDefs.map((c) => c.resolve(UiLang.pl)).toList();

/// Bonus XP przy awansie — trochę rośnie z poziomem (więcej chęci iść dalej).
int levelUpBonusXpFor(int level) => 12 + (level * 3).clamp(3, 60);

/// @Deprecated — użyj [levelUpBonusXpFor]; zostawione dla starych testów.
const levelUpBonusXp = 15;

/// Ciekawostka na dany poziom (deterministyczna + dopasowanie do języka nauki).
LanguageCuriosity curiosityForLevel(
  int level, {
  String? lang,
  UiLang uiLang = UiLang.pl,
}) {
  final pool = _curiosityDefs
      .where((c) => c.lang == null || c.lang == lang)
      .toList();
  if (pool.isEmpty) return _curiosityDefs.first.resolve(uiLang);
  final idx = (level - 2).clamp(0, 1 << 20) % pool.length;
  return pool[idx].resolve(uiLang);
}

/// Wszystkie ciekawostki odblokowane do danego poziomu (album).
List<LanguageCuriosity> unlockedCuriosities({
  required int rewardedLevel,
  String? lang,
  UiLang uiLang = UiLang.pl,
}) {
  if (rewardedLevel < 2) return const [];
  final seen = <String>{};
  final out = <LanguageCuriosity>[];
  for (var lv = 2; lv <= rewardedLevel; lv++) {
    final c = curiosityForLevel(lv, lang: lang, uiLang: uiLang);
    if (seen.add(c.id)) out.add(c);
  }
  return out;
}

/// Losowa ciekawostka (np. do przeglądania odblokowanych).
LanguageCuriosity randomCuriosity({
  String? lang,
  UiLang uiLang = UiLang.pl,
  Random? rng,
}) {
  final pool = _curiosityDefs
      .where((c) => c.lang == null || c.lang == lang)
      .toList();
  final r = rng ?? Random();
  return pool[r.nextInt(pool.length)].resolve(uiLang);
}
