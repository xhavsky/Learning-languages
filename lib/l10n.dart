/// Prosty język interfejsu aplikacji (nie mylić z językiem nauki).
enum UiLang {
  pl,
  en,
  es,
  ru;

  String get code => name;

  String get nativeLabel => switch (this) {
        UiLang.pl => 'Polski',
        UiLang.en => 'English',
        UiLang.es => 'Español',
        UiLang.ru => 'Русский',
      };

  static UiLang fromCode(String? raw) {
    return switch (raw) {
      'en' => UiLang.en,
      'es' => UiLang.es,
      'ru' => UiLang.ru,
      _ => UiLang.pl,
    };
  }
}

/// Tłumaczenia UI — krótkie etykiety ekranu głównego / nawigacji / ustawień.
class L10n {
  const L10n(this.lang);

  final UiLang lang;

  static const L10n pl = L10n(UiLang.pl);

  String get appTitle => switch (lang) {
        UiLang.pl => 'Trener Językowy',
        UiLang.en => 'Language Trainer',
        UiLang.es => 'Entrenador de idiomas',
        UiLang.ru => 'Языковой тренер',
      };

  String get tabLearn => switch (lang) {
        UiLang.pl => 'Nauka',
        UiLang.en => 'Learn',
        UiLang.es => 'Aprender',
        UiLang.ru => 'Учёба',
      };

  String get tabWords => switch (lang) {
        UiLang.pl => 'Słówka',
        UiLang.en => 'Words',
        UiLang.es => 'Palabras',
        UiLang.ru => 'Слова',
      };

  String get tabShop => switch (lang) {
        UiLang.pl => 'Sklep',
        UiLang.en => 'Shop',
        UiLang.es => 'Tienda',
        UiLang.ru => 'Магазин',
      };

  String get tabPools => switch (lang) {
        UiLang.pl => 'Pule',
        UiLang.en => 'Pools',
        UiLang.es => 'Listas',
        UiLang.ru => 'Наборы',
      };

  String get tabSettings => switch (lang) {
        UiLang.pl => 'Ustawienia',
        UiLang.en => 'Settings',
        UiLang.es => 'Ajustes',
        UiLang.ru => 'Настройки',
      };

  String get training => switch (lang) {
        UiLang.pl => 'Trening',
        UiLang.en => 'Practice',
        UiLang.es => 'Práctica',
        UiLang.ru => 'Тренировка',
      };

  String get trainingSubtitle => switch (lang) {
        UiLang.pl => 'Wybierz język, pulę i metodę',
        UiLang.en => 'Pick language, pool and method',
        UiLang.es => 'Elige idioma, lista y método',
        UiLang.ru => 'Выбери язык, набор и метод',
      };

  String get language => switch (lang) {
        UiLang.pl => 'Język nauki',
        UiLang.en => 'Learning language',
        UiLang.es => 'Idioma de estudio',
        UiLang.ru => 'Язык обучения',
      };

  String get appLanguage => switch (lang) {
        UiLang.pl => 'Język aplikacji',
        UiLang.en => 'App language',
        UiLang.es => 'Idioma de la app',
        UiLang.ru => 'Язык приложения',
      };

  String get methodAbc => switch (lang) {
        UiLang.pl => 'ABC',
        UiLang.en => 'ABC',
        UiLang.es => 'ABC',
        UiLang.ru => 'ABC',
      };

  String get methodTyping => switch (lang) {
        UiLang.pl => 'Pisanie',
        UiLang.en => 'Typing',
        UiLang.es => 'Escritura',
        UiLang.ru => 'Письмо',
      };

  String get methodSentences => switch (lang) {
        UiLang.pl => 'Zdania',
        UiLang.en => 'Sentences',
        UiLang.es => 'Frases',
        UiLang.ru => 'Предложения',
      };

  String get methodLabel => switch (lang) {
        UiLang.pl => 'Metoda nauki',
        UiLang.en => 'Study method',
        UiLang.es => 'Método',
        UiLang.ru => 'Метод',
      };

  String get poolWordsHint => switch (lang) {
        UiLang.pl => 'Pula słówek (przesuń → albo utwórz własną)',
        UiLang.en => 'Word pool (swipe → or create your own)',
        UiLang.es => 'Lista de palabras (desliza → o crea una)',
        UiLang.ru => 'Набор слов (листай → или создай свой)',
      };

  String get poolAll => switch (lang) {
        UiLang.pl => 'Cała baza',
        UiLang.en => 'All words',
        UiLang.es => 'Toda la base',
        UiLang.ru => 'Вся база',
      };

  String get poolUnlearned => switch (lang) {
        UiLang.pl => 'Nieopanowane',
        UiLang.en => 'Not mastered',
        UiLang.es => 'Sin dominar',
        UiLang.ru => 'Невыученные',
      };

  String get poolHard => switch (lang) {
        UiLang.pl => 'Trudne',
        UiLang.en => 'Hard',
        UiLang.es => 'Difíciles',
        UiLang.ru => 'Сложные',
      };

  String get quickActions => switch (lang) {
        UiLang.pl => 'Szybkie akcje',
        UiLang.en => 'Quick actions',
        UiLang.es => 'Acciones rápidas',
        UiLang.ru => 'Быстрые действия',
      };

  String get quickActionsSubtitle => switch (lang) {
        UiLang.pl => 'Dodawaj, ćwicz i gaduś z AI',
        UiLang.en => 'Add, practice and chat with AI',
        UiLang.es => 'Añade, practica y habla con la IA',
        UiLang.ru => 'Добавляй, учись и болтай с ИИ',
      };

  String get addWord => switch (lang) {
        UiLang.pl => 'Słowo',
        UiLang.en => 'Word',
        UiLang.es => 'Palabra',
        UiLang.ru => 'Слово',
      };

  String get importCsv => switch (lang) {
        UiLang.pl => 'Import CSV',
        UiLang.en => 'Import CSV',
        UiLang.es => 'Importar CSV',
        UiLang.ru => 'Импорт CSV',
      };

  String get list => switch (lang) {
        UiLang.pl => 'Lista',
        UiLang.en => 'List',
        UiLang.es => 'Lista',
        UiLang.ru => 'Список',
      };

  String get aiChat => switch (lang) {
        UiLang.pl => 'AI na urządzeniu',
        UiLang.en => 'On-device AI',
        UiLang.es => 'IA en el dispositivo',
        UiLang.ru => 'ИИ на устройстве',
      };

  String get aiChatDone => switch (lang) {
        UiLang.pl => 'Rozmowa ✓',
        UiLang.en => 'Chat ✓',
        UiLang.es => 'Charla ✓',
        UiLang.ru => 'Чат ✓',
      };

  String get poolLearn => switch (lang) {
        UiLang.pl => 'Pula: Nauka',
        UiLang.en => 'Pool: Learn',
        UiLang.es => 'Lista: Aprender',
        UiLang.ru => 'Набор: Учёба',
      };

  String get poolReview => switch (lang) {
        UiLang.pl => 'Pula: Powtórka',
        UiLang.en => 'Pool: Review',
        UiLang.es => 'Lista: Repaso',
        UiLang.ru => 'Набор: Повтор',
      };

  String get hardOn => switch (lang) {
        UiLang.pl => 'Trudne ★',
        UiLang.en => 'Hard ★',
        UiLang.es => 'Difícil ★',
        UiLang.ru => 'Сложное ★',
      };

  String get hardOff => switch (lang) {
        UiLang.pl => 'Trudne?',
        UiLang.en => 'Hard?',
        UiLang.es => '¿Difícil?',
        UiLang.ru => 'Сложное?',
      };

  String get noSentencesLearn => switch (lang) {
        UiLang.pl => 'Brak zdań do nauki.',
        UiLang.en => 'No sentences to learn.',
        UiLang.es => 'No hay frases para aprender.',
        UiLang.ru => 'Нет предложений для учёбы.',
      };

  String get noSentencesReview => switch (lang) {
        UiLang.pl => 'Brak opanowanych zdań.',
        UiLang.en => 'No mastered sentences.',
        UiLang.es => 'No hay frases dominadas.',
        UiLang.ru => 'Нет выученных предложений.',
      };

  String get noWordsLearn => switch (lang) {
        UiLang.pl =>
          'Brak słówek do nauki w tej puli.\nDodaj słowa lub wybierz inną pulę.',
        UiLang.en =>
          'No words to learn in this pool.\nAdd words or pick another pool.',
        UiLang.es =>
          'No hay palabras en esta lista.\nAñade palabras u elige otra lista.',
        UiLang.ru =>
          'Нет слов для учёбы в этом наборе.\nДобавь слова или выбери другой.',
      };

  String get noWordsReview => switch (lang) {
        UiLang.pl => 'Brak opanowanych w tej puli.',
        UiLang.en => 'No mastered words in this pool.',
        UiLang.es => 'No hay palabras dominadas en esta lista.',
        UiLang.ru => 'Нет выученных слов в этом наборе.',
      };

  String promptTranslateSentenceForeign(String langName) => switch (lang) {
        UiLang.pl => 'Przetłumacz zdanie na język obcy:',
        UiLang.en => 'Translate the sentence into the foreign language:',
        UiLang.es => 'Traduce la frase al idioma extranjero:',
        UiLang.ru => 'Переведи предложение на иностранный язык:',
      };

  String get promptTranslateSentencePl => switch (lang) {
        UiLang.pl => 'Jak po polsku znaczy to zdanie:',
        UiLang.en => 'What does this sentence mean in Polish:',
        UiLang.es => '¿Qué significa esta frase en polaco:',
        UiLang.ru => 'Как по-польски значит это предложение:',
      };

  String get promptTranslateForeign => switch (lang) {
        UiLang.pl => 'Przetłumacz na język obcy:',
        UiLang.en => 'Translate into the foreign language:',
        UiLang.es => 'Traduce al idioma extranjero:',
        UiLang.ru => 'Переведи на иностранный язык:',
      };

  String get promptTranslatePl => switch (lang) {
        UiLang.pl => 'Jak po polsku:',
        UiLang.en => 'In Polish:',
        UiLang.es => 'En polaco:',
        UiLang.ru => 'По-польски:',
      };

  String get sentenceHint => switch (lang) {
        UiLang.pl => 'Napisz całe zdanie — samo zaliczy, gdy będzie dobrze',
        UiLang.en => 'Type the whole sentence — it checks itself when correct',
        UiLang.es => 'Escribe toda la frase — se valida sola si está bien',
        UiLang.ru => 'Напиши всё предложение — засчитается само, если верно',
      };

  String get wordHint => switch (lang) {
        UiLang.pl => 'Wpisz tłumaczenie — samo zaliczy',
        UiLang.en => 'Type the translation — auto-checks',
        UiLang.es => 'Escribe la traducción — se valida sola',
        UiLang.ru => 'Введи перевод — засчитается само',
      };

  String get settings => switch (lang) {
        UiLang.pl => 'Ustawienia',
        UiLang.en => 'Settings',
        UiLang.es => 'Ajustes',
        UiLang.ru => 'Настройки',
      };

  String get theme => switch (lang) {
        UiLang.pl => 'Motyw',
        UiLang.en => 'Theme',
        UiLang.es => 'Tema',
        UiLang.ru => 'Тема',
      };

  String get themeSystem => switch (lang) {
        UiLang.pl => 'System',
        UiLang.en => 'System',
        UiLang.es => 'Sistema',
        UiLang.ru => 'Система',
      };

  String get themeLight => switch (lang) {
        UiLang.pl => 'Jasny',
        UiLang.en => 'Light',
        UiLang.es => 'Claro',
        UiLang.ru => 'Светлая',
      };

  String get themeDark => switch (lang) {
        UiLang.pl => 'Ciemny',
        UiLang.en => 'Dark',
        UiLang.es => 'Oscuro',
        UiLang.ru => 'Тёмная',
      };

  String get colors => switch (lang) {
        UiLang.pl => 'Kolorystyka',
        UiLang.en => 'Colors',
        UiLang.es => 'Colores',
        UiLang.ru => 'Цвета',
      };

  String get narrator => switch (lang) {
        UiLang.pl => 'Lektor (audio)',
        UiLang.en => 'Narrator (audio)',
        UiLang.es => 'Narrador (audio)',
        UiLang.ru => 'Диктор (аудио)',
      };

  String get album => switch (lang) {
        UiLang.pl => 'Album nagród / ciekawostki',
        UiLang.en => 'Rewards album / facts',
        UiLang.es => 'Álbum de premios / curiosidades',
        UiLang.ru => 'Альбом наград / факты',
      };

  String get moreSettings => switch (lang) {
        UiLang.pl => 'Więcej ustawień',
        UiLang.en => 'More settings',
        UiLang.es => 'Más ajustes',
        UiLang.ru => 'Ещё настройки',
      };

  String get moreSettingsSubtitle => switch (lang) {
        UiLang.pl => 'Kierunek tłumaczenia, AI, eksport…',
        UiLang.en => 'Translate direction, AI, export…',
        UiLang.es => 'Dirección, IA, exportar…',
        UiLang.ru => 'Направление, ИИ, экспорт…',
      };

  String get pickLangFirst => switch (lang) {
        UiLang.pl => 'Najpierw wybierz język w zakładce Nauka.',
        UiLang.en => 'First pick a learning language in Learn.',
        UiLang.es => 'Primero elige un idioma en Aprender.',
        UiLang.ru => 'Сначала выбери язык во вкладке Учёба.',
      };

  String get levelShort => switch (lang) {
        UiLang.pl => 'LVL',
        UiLang.en => 'LVL',
        UiLang.es => 'NVL',
        UiLang.ru => 'УР',
      };

  String xpToNext(int nextLevel, int xp) => switch (lang) {
        UiLang.pl => 'Do LVL $nextLevel: $xp XP',
        UiLang.en => 'To LVL $nextLevel: $xp XP',
        UiLang.es => 'Hasta NVL $nextLevel: $xp XP',
        UiLang.ru => 'До УР $nextLevel: $xp XP',
      };

  String get mascotHeader => switch (lang) {
        UiLang.pl => 'Twój zwierzak — garderoba i kolory',
        UiLang.en => 'Your pet — wardrobe and colors',
        UiLang.es => 'Tu mascota — vestuario y colores',
        UiLang.ru => 'Твой питомец — гардероб и цвета',
      };

  String get starting => switch (lang) {
        UiLang.pl => 'Startuję Trener Językowy…',
        UiLang.en => 'Starting Language Trainer…',
        UiLang.es => 'Iniciando Entrenador…',
        UiLang.ru => 'Запуск Языкового тренера…',
      };
}
