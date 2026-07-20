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

  String get tabMascot => switch (lang) {
        UiLang.pl => 'Maskotka',
        UiLang.en => 'Pet',
        UiLang.es => 'Mascota',
        UiLang.ru => 'Питомец',
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

  String levelUpCongrats(int level) => switch (lang) {
        UiLang.pl => 'Poziom $level! 🎉',
        UiLang.en => 'Level $level! 🎉',
        UiLang.es => '¡Nivel $level! 🎉',
        UiLang.ru => 'Уровень $level! 🎉',
      };

  String titleLabel(String title) => switch (lang) {
        UiLang.pl => 'Tytuł: $title',
        UiLang.en => 'Title: $title',
        UiLang.es => 'Título: $title',
        UiLang.ru => 'Титул: $title',
      };

  String get newTitleUnlocked => switch (lang) {
        UiLang.pl => '✨ Nowy tytuł odblokowany!',
        UiLang.en => '✨ New title unlocked!',
        UiLang.es => '✨ ¡Nuevo título desbloqueado!',
        UiLang.ru => '✨ Новый титул открыт!',
      };

  String rewardXpPaws(int bonus, int paws) => switch (lang) {
        UiLang.pl => 'Nagroda: +$bonus XP · +$paws 🐾',
        UiLang.en => 'Reward: +$bonus XP · +$paws 🐾',
        UiLang.es => 'Premio: +$bonus XP · +$paws 🐾',
        UiLang.ru => 'Награда: +$bonus XP · +$paws 🐾',
      };

  String challengeTip(String tip) => switch (lang) {
        UiLang.pl => '🎯 Wyzwanie: $tip',
        UiLang.en => '🎯 Challenge: $tip',
        UiLang.es => '🎯 Reto: $tip',
        UiLang.ru => '🎯 Вызов: $tip',
      };

  String get superOk => switch (lang) {
        UiLang.pl => 'Super!',
        UiLang.en => 'Awesome!',
        UiLang.es => '¡Genial!',
        UiLang.ru => 'Супер!',
      };

  String get albumRewards => switch (lang) {
        UiLang.pl => 'Album nagród',
        UiLang.en => 'Rewards album',
        UiLang.es => 'Álbum de premios',
        UiLang.ru => 'Альбом наград',
      };

  String levelAndTitle(int level, String title) => switch (lang) {
        UiLang.pl => 'Poziom $level · $title',
        UiLang.en => 'Level $level · $title',
        UiLang.es => 'Nivel $level · $title',
        UiLang.ru => 'Уровень $level · $title',
      };

  String get unlockFirstCuriosity => switch (lang) {
        UiLang.pl =>
          'Awansuj na poziom 2, żeby odblokować pierwszą ciekawostkę!',
        UiLang.en => 'Reach level 2 to unlock your first fun fact!',
        UiLang.es => '¡Sube al nivel 2 para desbloquear la primera curiosidad!',
        UiLang.ru => 'Дойди до уровня 2, чтобы открыть первый факт!',
      };

  String get yourLevel => switch (lang) {
        UiLang.pl => 'Twój poziom',
        UiLang.en => 'Your level',
        UiLang.es => 'Tu nivel',
        UiLang.ru => 'Твой уровень',
      };

  String get yourLevelSubtitle => switch (lang) {
        UiLang.pl => 'XP za poprawne odpowiedzi',
        UiLang.en => 'XP for correct answers',
        UiLang.es => 'XP por respuestas correctas',
        UiLang.ru => 'XP за правильные ответы',
      };

  String levelShortNum(int level) => switch (lang) {
        UiLang.pl => 'Poz. $level',
        UiLang.en => 'Lv. $level',
        UiLang.es => 'Niv. $level',
        UiLang.ru => 'Ур. $level',
      };

  String toNextLevel(int xp, {int sessionXp = 0}) {
    final base = switch (lang) {
      UiLang.pl => 'Do kolejnego poziomu: $xp XP',
      UiLang.en => 'To next level: $xp XP',
      UiLang.es => 'Hasta el siguiente nivel: $xp XP',
      UiLang.ru => 'До следующего уровня: $xp XP',
    };
    if (sessionXp <= 0) return base;
    return '$base · +$sessionXp ${switch (lang) {
      UiLang.pl => 'dziś',
      UiLang.en => 'today',
      UiLang.es => 'hoy',
      UiLang.ru => 'сегодня',
    }}';
  }

  String get learnedStreak => switch (lang) {
        UiLang.pl => 'Nauczone! ✓ (3× z rzędu)',
        UiLang.en => 'Learned! ✓ (3× in a row)',
        UiLang.es => '¡Aprendido! ✓ (3× seguidas)',
        UiLang.ru => 'Выучено! ✓ (3× подряд)',
      };

  String bravoStreak(int streak) => switch (lang) {
        UiLang.pl => 'Brawo! ✓ ($streak/3)',
        UiLang.en => 'Nice! ✓ ($streak/3)',
        UiLang.es => '¡Bien! ✓ ($streak/3)',
        UiLang.ru => 'Молодец! ✓ ($streak/3)',
      };

  String fedBonus(String pet, int paws) => switch (lang) {
        UiLang.pl => '$pet najedzona! 🐱 +$paws 🐾',
        UiLang.en => '$pet is full! 🐱 +$paws 🐾',
        UiLang.es => '¡$pet está llena! 🐱 +$paws 🐾',
        UiLang.ru => '$pet сыта! 🐱 +$paws 🐾',
      };

  String pawsPlus(int paws) => '+$paws 🐾';

  String correctWas(String expected) => switch (lang) {
        UiLang.pl => 'Poprawnie: $expected',
        UiLang.en => 'Correct: $expected',
        UiLang.es => 'Correcto: $expected',
        UiLang.ru => 'Правильно: $expected',
      };

  String get pickLanguage => switch (lang) {
        UiLang.pl => 'Wybierz język',
        UiLang.en => 'Pick a language',
        UiLang.es => 'Elige un idioma',
        UiLang.ru => 'Выбери язык',
      };

  String get fillBothFields => switch (lang) {
        UiLang.pl => 'Wypełnij oba pola',
        UiLang.en => 'Fill both fields',
        UiLang.es => 'Rellena ambos campos',
        UiLang.ru => 'Заполни оба поля',
      };

  String addedWord(String pl, String foreign) => switch (lang) {
        UiLang.pl => 'Dodano: $pl → $foreign',
        UiLang.en => 'Added: $pl → $foreign',
        UiLang.es => 'Añadido: $pl → $foreign',
        UiLang.ru => 'Добавлено: $pl → $foreign',
      };

  String learnWithPet(bool dog) => switch (lang) {
        UiLang.pl => dog ? 'Czas na naukę z Pieskiem!' : 'Czas na naukę z Kicią!',
        UiLang.en => dog ? 'Time to learn with Puppy!' : 'Time to learn with Kitty!',
        UiLang.es => dog ? '¡Hora de aprender con Perrito!' : '¡Hora de aprender con Michi!',
        UiLang.ru => dog ? 'Пора учиться с Пёсиком!' : 'Пора учиться с Кисой!',
      };

  String feedPetSubtitle(bool dog) => switch (lang) {
        UiLang.pl => dog
            ? 'Każde słówko karmi Twojego Pieska'
            : 'Każde słówko karmi Twoją Kicię',
        UiLang.en => dog
            ? 'Every word feeds your Puppy'
            : 'Every word feeds your Kitty',
        UiLang.es => dog
            ? 'Cada palabra alimenta a tu Perrito'
            : 'Cada palabra alimenta a tu Michi',
        UiLang.ru => dog
            ? 'Каждое слово кормит твоего Пёсика'
            : 'Каждое слово кормит твою Кису',
      };

  String levelChip(int level) => switch (lang) {
        UiLang.pl => 'Poziom $level',
        UiLang.en => 'Level $level',
        UiLang.es => 'Nivel $level',
        UiLang.ru => 'Уровень $level',
      };

  String pawsChip(int n) => switch (lang) {
        UiLang.pl => '$n łapek',
        UiLang.en => '$n paws',
        UiLang.es => '$n patitas',
        UiLang.ru => '$n лапок',
      };

  String wordsChip(int n) => switch (lang) {
        UiLang.pl => '$n słówek',
        UiLang.en => '$n words',
        UiLang.es => '$n palabras',
        UiLang.ru => '$n слов',
      };

  String sessionChip(int correct, int total) => switch (lang) {
        UiLang.pl => 'Sesja $correct/$total',
        UiLang.en => 'Session $correct/$total',
        UiLang.es => 'Sesión $correct/$total',
        UiLang.ru => 'Сессия $correct/$total',
      };

  String get newPool => switch (lang) {
        UiLang.pl => 'Nowa pula',
        UiLang.en => 'New pool',
        UiLang.es => 'Nueva lista',
        UiLang.ru => 'Новый набор',
      };

  String get hint => switch (lang) {
        UiLang.pl => 'Podpowiedź',
        UiLang.en => 'Hint',
        UiLang.es => 'Pista',
        UiLang.ru => 'Подсказка',
      };

  String get listen => switch (lang) {
        UiLang.pl => 'Posłuchaj',
        UiLang.en => 'Listen',
        UiLang.es => 'Escuchar',
        UiLang.ru => 'Слушать',
      };

  String get narratorOff => switch (lang) {
        UiLang.pl => 'Lektor wyłączony',
        UiLang.en => 'Narrator off',
        UiLang.es => 'Narrador apagado',
        UiLang.ru => 'Диктор выкл.',
      };

  String get check => switch (lang) {
        UiLang.pl => 'Sprawdź',
        UiLang.en => 'Check',
        UiLang.es => 'Comprobar',
        UiLang.ru => 'Проверить',
      };

  String get hardMarked => switch (lang) {
        UiLang.pl => 'Oznaczone jako trudne',
        UiLang.en => 'Marked as hard',
        UiLang.es => 'Marcado como difícil',
        UiLang.ru => 'Отмечено как сложное',
      };

  String get hardCleared => switch (lang) {
        UiLang.pl => 'Trudne wyłączone',
        UiLang.en => 'Hard cleared',
        UiLang.es => 'Difícil desmarcado',
        UiLang.ru => 'Сложное снято',
      };

  String hintFlash(String first, int len) => switch (lang) {
        UiLang.pl => 'Podpowiedź: $first… ($len liter)',
        UiLang.en => 'Hint: $first… ($len letters)',
        UiLang.es => 'Pista: $first… ($len letras)',
        UiLang.ru => 'Подсказка: $first… ($len букв)',
      };

  String get translateDir => switch (lang) {
        UiLang.pl => 'Kierunek',
        UiLang.en => 'Direction',
        UiLang.es => 'Dirección',
        UiLang.ru => 'Направление',
      };

  String get dirPlToForeign => switch (lang) {
        UiLang.pl => 'PL → obcy',
        UiLang.en => 'PL → foreign',
        UiLang.es => 'PL → extranjero',
        UiLang.ru => 'PL → иностр.',
      };

  String get dirForeignToPl => switch (lang) {
        UiLang.pl => 'obcy → PL',
        UiLang.en => 'foreign → PL',
        UiLang.es => 'extranjero → PL',
        UiLang.ru => 'иностр. → PL',
      };

  String get dirMixed => switch (lang) {
        UiLang.pl => 'Mieszany',
        UiLang.en => 'Mixed',
        UiLang.es => 'Mixto',
        UiLang.ru => 'Смешанный',
      };

  String get dirHintPlToForeign => switch (lang) {
        UiLang.pl =>
          'Widzisz polskie — wpisujesz / wybierasz obce. Audio dopiero po odpowiedzi albo po 🔊.',
        UiLang.en =>
          'You see Polish — type / pick the foreign word. Audio after the answer or 🔊.',
        UiLang.es =>
          'Ves polaco — escribes / eliges el extranjero. Audio tras la respuesta o 🔊.',
        UiLang.ru =>
          'Видишь польское — пишешь / выбираешь иностранное. Аудио после ответа или 🔊.',
      };

  String get dirHintForeignToPl => switch (lang) {
        UiLang.pl =>
          'Widzisz obce — odpowiadasz po polsku. Audio startuje od razu.',
        UiLang.en =>
          'You see the foreign word — answer in Polish. Audio starts right away.',
        UiLang.es =>
          'Ves el extranjero — respondes en polaco. El audio empieza al instante.',
        UiLang.ru =>
          'Видишь иностранное — отвечаешь по-польски. Аудио сразу.',
      };

  String get dirHintMixed => switch (lang) {
        UiLang.pl => 'Losowo PL→obcy albo obcy→PL przy każdym słówku.',
        UiLang.en => 'Random PL→foreign or foreign→PL each word.',
        UiLang.es => 'Al azar PL→extranjero o extranjero→PL en cada palabra.',
        UiLang.ru => 'Случайно PL→иностр. или иностр.→PL на каждое слово.',
      };

  String get enableNarrator => switch (lang) {
        UiLang.pl => 'Włącz lektora',
        UiLang.en => 'Enable narrator',
        UiLang.es => 'Activar narrador',
        UiLang.ru => 'Включить диктора',
      };

  String get disableNarrator => switch (lang) {
        UiLang.pl => 'Wyłącz lektora',
        UiLang.en => 'Disable narrator',
        UiLang.es => 'Apagar narrador',
        UiLang.ru => 'Выключить диктора',
      };

  String get narratorOnSub => switch (lang) {
        UiLang.pl => 'Słówka są odczytywane na głos.',
        UiLang.en => 'Words are read aloud.',
        UiLang.es => 'Las palabras se leen en voz alta.',
        UiLang.ru => 'Слова читаются вслух.',
      };

  String get narratorOffSub => switch (lang) {
        UiLang.pl => 'Audio wyłączone — ćwiczysz w ciszy.',
        UiLang.en => 'Audio off — practice in silence.',
        UiLang.es => 'Audio apagado — practicas en silencio.',
        UiLang.ru => 'Аудио выкл. — учишься в тишине.',
      };

  String get audioTempo => switch (lang) {
        UiLang.pl => 'Tempo audio',
        UiLang.en => 'Audio speed',
        UiLang.es => 'Velocidad del audio',
        UiLang.ru => 'Скорость аудио',
      };

  String get onDeviceAi => switch (lang) {
        UiLang.pl => 'AI na urządzeniu',
        UiLang.en => 'On-device AI',
        UiLang.es => 'IA en el dispositivo',
        UiLang.ru => 'ИИ на устройстве',
      };

  String get onDeviceAiBlurb => switch (lang) {
        UiLang.pl =>
          'Czat: na PC pełny Bielik 11B v3 (Ollama w paczce lub systemowa), '
              'na telefonie Bielik 1.5B v3 (GGUF). Bez portalu i chmury. '
              'Host Ollamy — zwykle pusto (127.0.0.1).',
        UiLang.en =>
          'Chat: on PC full Bielik 11B v3 (bundled or system Ollama), '
              'on phone Bielik 1.5B v3 (GGUF). No portal or cloud. '
              'Ollama host — usually empty (127.0.0.1).',
        UiLang.es =>
          'Chat: en PC Bielik 11B v3 completo (Ollama en el paquete o del sistema), '
              'en el teléfono Bielik 1.5B v3 (GGUF). Sin portal ni nube. '
              'Host de Ollama — suele estar vacío (127.0.0.1).',
        UiLang.ru =>
          'Чат: на ПК полный Bielik 11B v3 (Ollama в пакете или системная), '
              'на телефоне Bielik 1.5B v3 (GGUF). Без портала и облака. '
              'Хост Ollama — обычно пусто (127.0.0.1).',
      };

  String get ollamaAddress => switch (lang) {
        UiLang.pl => 'Adres Ollamy (opcjonalnie)',
        UiLang.en => 'Ollama address (optional)',
        UiLang.es => 'Dirección de Ollama (opcional)',
        UiLang.ru => 'Адрес Ollama (необязательно)',
      };

  String get saveAiAddress => switch (lang) {
        UiLang.pl => 'Zapisz adres AI',
        UiLang.en => 'Save AI address',
        UiLang.es => 'Guardar dirección IA',
        UiLang.ru => 'Сохранить адрес ИИ',
      };

  String get aiAddressSaved => switch (lang) {
        UiLang.pl => 'Zapisano adres AI lokalnego',
        UiLang.en => 'Local AI address saved',
        UiLang.es => 'Dirección IA local guardada',
        UiLang.ru => 'Адрес локального ИИ сохранён',
      };

  String get exportDb => switch (lang) {
        UiLang.pl => 'Eksportuj bazę (JSON)',
        UiLang.en => 'Export database (JSON)',
        UiLang.es => 'Exportar base (JSON)',
        UiLang.ru => 'Экспорт базы (JSON)',
      };

  String exported(String path) => switch (lang) {
        UiLang.pl => 'Wyeksportowano:\n$path',
        UiLang.en => 'Exported:\n$path',
        UiLang.es => 'Exportado:\n$path',
        UiLang.ru => 'Экспортировано:\n$path',
      };

  String get importJsonPath => switch (lang) {
        UiLang.pl => 'Ścieżka do importu JSON',
        UiLang.en => 'Path to JSON import',
        UiLang.es => 'Ruta de importación JSON',
        UiLang.ru => 'Путь к импорту JSON',
      };

  String get importFromFile => switch (lang) {
        UiLang.pl => 'Importuj z pliku',
        UiLang.en => 'Import from file',
        UiLang.es => 'Importar desde archivo',
        UiLang.ru => 'Импорт из файла',
      };

  String get importedDb => switch (lang) {
        UiLang.pl => 'Zaimportowano bazę',
        UiLang.en => 'Database imported',
        UiLang.es => 'Base importada',
        UiLang.ru => 'База импортирована',
      };

  String audioComplete(int n) => switch (lang) {
        UiLang.pl => 'Audio: komplet ($n słówek)',
        UiLang.en => 'Audio: complete ($n words)',
        UiLang.es => 'Audio: completo ($n palabras)',
        UiLang.ru => 'Аудио: полный набор ($n слов)',
      };

  String audioMissing(int n) => switch (lang) {
        UiLang.pl =>
          'Brak audio: $n haseł\n(PC: python3 scripts/generate_tts.py)',
        UiLang.en =>
          'Missing audio: $n entries\n(PC: python3 scripts/generate_tts.py)',
        UiLang.es =>
          'Falta audio: $n entradas\n(PC: python3 scripts/generate_tts.py)',
        UiLang.ru =>
          'Нет аудио: $n записей\n(PC: python3 scripts/generate_tts.py)',
      };

  String get forAnielka => switch (lang) {
        UiLang.pl => 'Dla Anielki',
        UiLang.en => 'For Anielka',
        UiLang.es => 'Para Anielka',
        UiLang.ru => 'Для Анельки',
      };

  String get portalWww => switch (lang) {
        UiLang.pl => 'Portal WWW (adres + PIN)',
        UiLang.en => 'Web portal (address + PIN)',
        UiLang.es => 'Portal web (dirección + PIN)',
        UiLang.ru => 'Веб-портал (адрес + PIN)',
      };

  String get publishGithub => switch (lang) {
        UiLang.pl => 'Opublikuj na moje GitHub',
        UiLang.en => 'Publish to my GitHub',
        UiLang.es => 'Publicar en mi GitHub',
        UiLang.ru => 'Опубликовать на мой GitHub',
      };

  String get save => switch (lang) {
        UiLang.pl => 'Zapisz',
        UiLang.en => 'Save',
        UiLang.es => 'Guardar',
        UiLang.ru => 'Сохранить',
      };

  String get cancel => switch (lang) {
        UiLang.pl => 'Anuluj',
        UiLang.en => 'Cancel',
        UiLang.es => 'Cancelar',
        UiLang.ru => 'Отмена',
      };

  String get delete => switch (lang) {
        UiLang.pl => 'Usuń',
        UiLang.en => 'Delete',
        UiLang.es => 'Eliminar',
        UiLang.ru => 'Удалить',
      };

  String get edit => switch (lang) {
        UiLang.pl => 'Edytuj',
        UiLang.en => 'Edit',
        UiLang.es => 'Editar',
        UiLang.ru => 'Изменить',
      };

  String get search => switch (lang) {
        UiLang.pl => 'Szukaj',
        UiLang.en => 'Search',
        UiLang.es => 'Buscar',
        UiLang.ru => 'Поиск',
      };

  String get all => switch (lang) {
        UiLang.pl => 'Wszystkie',
        UiLang.en => 'All',
        UiLang.es => 'Todas',
        UiLang.ru => 'Все',
      };

  String get addWordTitle => switch (lang) {
        UiLang.pl => 'Dodaj słowo',
        UiLang.en => 'Add word',
        UiLang.es => 'Añadir palabra',
        UiLang.ru => 'Добавить слово',
      };

  String get inPolish => switch (lang) {
        UiLang.pl => 'Po polsku',
        UiLang.en => 'In Polish',
        UiLang.es => 'En polaco',
        UiLang.ru => 'По-польски',
      };

  String get translation => switch (lang) {
        UiLang.pl => 'Tłumaczenie',
        UiLang.en => 'Translation',
        UiLang.es => 'Traducción',
        UiLang.ru => 'Перевод',
      };

  String get noCategory => switch (lang) {
        UiLang.pl => 'Bez kategorii',
        UiLang.en => 'No category',
        UiLang.es => 'Sin categoría',
        UiLang.ru => 'Без категории',
      };

  String get category => switch (lang) {
        UiLang.pl => 'Kategoria',
        UiLang.en => 'Category',
        UiLang.es => 'Categoría',
        UiLang.ru => 'Категория',
      };

  String get importWordsTitle => switch (lang) {
        UiLang.pl => 'Import słówek',
        UiLang.en => 'Import words',
        UiLang.es => 'Importar palabras',
        UiLang.ru => 'Импорт слов',
      };

  String get importWordsHelp => switch (lang) {
        UiLang.pl =>
          'Wklej CSV lub tekst: pl,obcy · pl;obcy · pl - obcy\nJedna para w linii.',
        UiLang.en =>
          'Paste CSV or text: pl,foreign · pl;foreign · pl - foreign\nOne pair per line.',
        UiLang.es =>
          'Pega CSV o texto: pl,extranjero · pl;extranjero · pl - extranjero\nUn par por línea.',
        UiLang.ru =>
          'Вставь CSV или текст: pl,иностр. · pl;иностр. · pl - иностр.\nОдна пара в строке.',
      };

  String get importTextLabel => switch (lang) {
        UiLang.pl => 'Tekst / CSV',
        UiLang.en => 'Text / CSV',
        UiLang.es => 'Texto / CSV',
        UiLang.ru => 'Текст / CSV',
      };

  String get importFilePath => switch (lang) {
        UiLang.pl => 'Albo ścieżka do pliku .csv / .txt',
        UiLang.en => 'Or path to .csv / .txt file',
        UiLang.es => 'O ruta a archivo .csv / .txt',
        UiLang.ru => 'Или путь к файлу .csv / .txt',
      };

  String get createCategoryFromImport => switch (lang) {
        UiLang.pl => 'Utwórz kategorię z importu',
        UiLang.en => 'Create category from import',
        UiLang.es => 'Crear categoría del import',
        UiLang.ru => 'Создать категорию из импорта',
      };

  String get importAction => switch (lang) {
        UiLang.pl => 'Importuj',
        UiLang.en => 'Import',
        UiLang.es => 'Importar',
        UiLang.ru => 'Импорт',
      };

  String get spaceKey => switch (lang) {
        UiLang.pl => 'Spacja',
        UiLang.en => 'Space',
        UiLang.es => 'Espacio',
        UiLang.ru => 'Пробел',
      };

  String get backspaceKey => switch (lang) {
        UiLang.pl => 'Cofnij ←',
        UiLang.en => 'Backspace ←',
        UiLang.es => 'Borrar ←',
        UiLang.ru => 'Стереть ←',
      };

  String get russianKeyboard => switch (lang) {
        UiLang.pl => 'Klawiatura rosyjska',
        UiLang.en => 'Russian keyboard',
        UiLang.es => 'Teclado ruso',
        UiLang.ru => 'Русская клавиатура',
      };

  String get spanishChars => switch (lang) {
        UiLang.pl => 'Znaki hiszpańskie',
        UiLang.en => 'Spanish characters',
        UiLang.es => 'Caracteres españoles',
        UiLang.ru => 'Испанские символы',
      };

  String get tryAgain => switch (lang) {
        UiLang.pl => 'Spróbuj ponownie',
        UiLang.en => 'Try again',
        UiLang.es => 'Reintentar',
        UiLang.ru => 'Попробовать снова',
      };

  String get bootFailed => switch (lang) {
        UiLang.pl => 'Nie udało się wczytać aplikacji',
        UiLang.en => 'Could not load the app',
        UiLang.es => 'No se pudo cargar la app',
        UiLang.ru => 'Не удалось загрузить приложение',
      };

  String get bootFailedHint => switch (lang) {
        UiLang.pl =>
          'Częsty powód: stara wersja apki + nowy plik bazy.\n'
              'Spróbuj ponowić albo zaktualizuj pakiet (nrs / flutter run).',
        UiLang.en =>
          'Common cause: old app version + new database file.\n'
              'Retry or update the package (nrs / flutter run).',
        UiLang.es =>
          'Causa frecuente: app vieja + archivo de base nuevo.\n'
              'Reintenta o actualiza el paquete (nrs / flutter run).',
        UiLang.ru =>
          'Частая причина: старая версия приложения + новый файл базы.\n'
              'Повтори или обнови пакет (nrs / flutter run).',
      };

  String get loadingStarting => switch (lang) {
        UiLang.pl => 'Startuję…',
        UiLang.en => 'Starting…',
        UiLang.es => 'Iniciando…',
        UiLang.ru => 'Запуск…',
      };

  String get loadingSettings => switch (lang) {
        UiLang.pl => 'Ładuję ustawienia…',
        UiLang.en => 'Loading settings…',
        UiLang.es => 'Cargando ajustes…',
        UiLang.ru => 'Загрузка настроек…',
      };

  String get loadingWords => switch (lang) {
        UiLang.pl => 'Ładuję bazę słówek i postępy…',
        UiLang.en => 'Loading word base and progress…',
        UiLang.es => 'Cargando base de palabras y progreso…',
        UiLang.ru => 'Загрузка базы слов и прогресса…',
      };

  String get loadingFailed => switch (lang) {
        UiLang.pl => 'Nie udało się uruchomić',
        UiLang.en => 'Failed to start',
        UiLang.es => 'No se pudo iniciar',
        UiLang.ru => 'Не удалось запустить',
      };

  String get loadingRetry => switch (lang) {
        UiLang.pl => 'Ponawiam start…',
        UiLang.en => 'Retrying start…',
        UiLang.es => 'Reintentando inicio…',
        UiLang.ru => 'Повторный запуск…',
      };

  String randomOutfit(String name) => switch (lang) {
        UiLang.pl => 'Losowe ubranko: $name!',
        UiLang.en => 'Random outfit: $name!',
        UiLang.es => '¡Atuendo al azar: $name!',
        UiLang.ru => 'Случайная одежда: $name!',
      };

  String get wearInWardrobe => switch (lang) {
        UiLang.pl => 'Załóż je w garderobie 👗',
        UiLang.en => 'Put it on in the wardrobe 👗',
        UiLang.es => 'Póntelo en el vestuario 👗',
        UiLang.ru => 'Надень в гардеробе 👗',
      };

  String wardrobeTitle(String pet) => switch (lang) {
        UiLang.pl => 'Garderoba $pet',
        UiLang.en => '$pet wardrobe',
        UiLang.es => 'Vestuario de $pet',
        UiLang.ru => 'Гардероб: $pet',
      };

  String wardrobeBlurb(int feedGoal) => switch (lang) {
        UiLang.pl =>
          'Za każdy poziom losujesz nowe ubranko. '
              'Ekskluzywne ciuchy, miski i posłanie — w sklepie za złote łapki 🐾. '
              'Stuknij, żeby ubrać (1 rzecz na slot). '
              'Nakarm min. $feedGoal słówkami dziennie!',
        UiLang.en =>
          'Each level rolls a new outfit. '
              'Exclusive clothes, bowls and beds — in the shop for golden paws 🐾. '
              'Tap to wear (1 item per slot). '
              'Feed at least $feedGoal words a day!',
        UiLang.es =>
          'En cada nivel ganas un atuendo nuevo. '
              'Ropa exclusiva, comederos y camas — en la tienda por patitas doradas 🐾. '
              'Toca para vestir (1 cosa por ranura). '
              '¡Alimenta al menos $feedGoal palabras al día!',
        UiLang.ru =>
          'За каждый уровень — новая одежда. '
              'Эксклюзив, миски и лежанки — в магазине за золотые лапки 🐾. '
              'Нажми, чтобы надеть (1 вещь на слот). '
              'Покорми минимум $feedGoal словами в день!',
      };

  String get shopOnly => switch (lang) {
        UiLang.pl => '🛒 Tylko w sklepie',
        UiLang.en => '🛒 Shop only',
        UiLang.es => '🛒 Solo en la tienda',
        UiLang.ru => '🛒 Только в магазине',
      };

  String get notRolledYet => switch (lang) {
        UiLang.pl => '🔒 Jeszcze nie wylosowane',
        UiLang.en => '🔒 Not rolled yet',
        UiLang.es => '🔒 Aún no sorteado',
        UiLang.ru => '🔒 Ещё не выпало',
      };

  String get nothingUnlockedYet => switch (lang) {
        UiLang.pl => 'Jeszcze nic nie odblokowano — ćwicz do poziomu 2!',
        UiLang.en => 'Nothing unlocked yet — practice to level 2!',
        UiLang.es => '¡Aún no hay nada desbloqueado — practica hasta el nivel 2!',
        UiLang.ru => 'Пока ничего не открыто — учись до уровня 2!',
      };

  String get poolName => switch (lang) {
        UiLang.pl => 'Nazwa puli',
        UiLang.en => 'Pool name',
        UiLang.es => 'Nombre de lista',
        UiLang.ru => 'Название набора',
      };

  String get poolNameHint => switch (lang) {
        UiLang.pl => 'np. Czasowniki na dziś',
        UiLang.en => 'e.g. Verbs for today',
        UiLang.es => 'p. ej. Verbos de hoy',
        UiLang.ru => 'напр. Глаголы на сегодня',
      };

  String get searchWord => switch (lang) {
        UiLang.pl => 'Szukaj słówka',
        UiLang.en => 'Search word',
        UiLang.es => 'Buscar palabra',
        UiLang.ru => 'Искать слово',
      };

  String selectedVisible(int selected, int visible) => switch (lang) {
        UiLang.pl => 'Zaznaczone: $selected · Widoczne: $visible',
        UiLang.en => 'Selected: $selected · Visible: $visible',
        UiLang.es => 'Seleccionadas: $selected · Visibles: $visible',
        UiLang.ru => 'Выбрано: $selected · Видно: $visible',
      };

  String get selectWordsHint => switch (lang) {
        UiLang.pl =>
          'Zaznacz słowa do puli (możesz szukać po polsku lub obcym).',
        UiLang.en =>
          'Select words for the pool (search in Polish or foreign).',
        UiLang.es =>
          'Selecciona palabras para la lista (busca en polaco o extranjero).',
        UiLang.ru =>
          'Выбери слова для набора (поиск по-польски или на иностранном).',
      };

  String get noWords => switch (lang) {
        UiLang.pl => 'Brak słówek',
        UiLang.en => 'No words',
        UiLang.es => 'Sin palabras',
        UiLang.ru => 'Нет слов',
      };

  String get deletePool => switch (lang) {
        UiLang.pl => 'Usuń pulę',
        UiLang.en => 'Delete pool',
        UiLang.es => 'Eliminar lista',
        UiLang.ru => 'Удалить набор',
      };

  String get createPoolPick => switch (lang) {
        UiLang.pl => 'Utwórz (wybierz słowa)',
        UiLang.en => 'Create (pick words)',
        UiLang.es => 'Crear (elige palabras)',
        UiLang.ru => 'Создать (выбери слова)',
      };

  String createPoolN(int n) => switch (lang) {
        UiLang.pl => 'Utwórz pulę ($n)',
        UiLang.en => 'Create pool ($n)',
        UiLang.es => 'Crear lista ($n)',
        UiLang.ru => 'Создать набор ($n)',
      };

  String get newWordPool => switch (lang) {
        UiLang.pl => 'Nowa pula słówek',
        UiLang.en => 'New word pool',
        UiLang.es => 'Nueva lista de palabras',
        UiLang.ru => 'Новый набор слов',
      };

  String get editPool => switch (lang) {
        UiLang.pl => 'Edytuj pulę',
        UiLang.en => 'Edit pool',
        UiLang.es => 'Editar lista',
        UiLang.ru => 'Изменить набор',
      };

  String get enterPoolName => switch (lang) {
        UiLang.pl => 'Podaj nazwę puli',
        UiLang.en => 'Enter a pool name',
        UiLang.es => 'Escribe un nombre de lista',
        UiLang.ru => 'Введи название набора',
      };

  String get selectAtLeastOne => switch (lang) {
        UiLang.pl => 'Zaznacz przynajmniej jedno słówko',
        UiLang.en => 'Select at least one word',
        UiLang.es => 'Selecciona al menos una palabra',
        UiLang.ru => 'Выбери хотя бы одно слово',
      };

  String poolCreated(String name) => switch (lang) {
        UiLang.pl => 'Utworzono pulę „$name” — ćwiczysz z niej',
        UiLang.en => 'Created pool “$name” — practicing from it',
        UiLang.es => 'Lista „$name” creada — practicas con ella',
        UiLang.ru => 'Набор «$name» создан — учишься из него',
      };

  String get poolsIntro => switch (lang) {
        UiLang.pl =>
          'Wybierz pulę do ćwiczeń albo utwórz własną: nazwa + zaznaczone słówka.',
        UiLang.en =>
          'Pick a practice pool or create your own: name + selected words.',
        UiLang.es =>
          'Elige una lista para practicar o crea la tuya: nombre + palabras.',
        UiLang.ru =>
          'Выбери набор для тренировки или создай свой: имя + выбранные слова.',
      };

  String get quickPick => switch (lang) {
        UiLang.pl => 'Szybki wybór',
        UiLang.en => 'Quick pick',
        UiLang.es => 'Selección rápida',
        UiLang.ru => 'Быстрый выбор',
      };

  String wordsCountShort(int n) => switch (lang) {
        UiLang.pl => '$n słów',
        UiLang.en => '$n words',
        UiLang.es => '$n palabras',
        UiLang.ru => '$n слов',
      };

  String get yourPoolsEmpty => switch (lang) {
        UiLang.pl => 'Twoje pule (pusto — dodaj pierwszą)',
        UiLang.en => 'Your pools (empty — add the first)',
        UiLang.es => 'Tus listas (vacío — añade la primera)',
        UiLang.ru => 'Твои наборы (пусто — добавь первый)',
      };

  String yourPoolsN(int n) => switch (lang) {
        UiLang.pl => 'Twoje pule ($n)',
        UiLang.en => 'Your pools ($n)',
        UiLang.es => 'Tus listas ($n)',
        UiLang.ru => 'Твои наборы ($n)',
      };

  String get yourPoolsHint => switch (lang) {
        UiLang.pl => 'Kliknij „Nowa pula”, wpisz nazwę i zaznacz słówka.',
        UiLang.en => 'Tap “New pool”, enter a name and select words.',
        UiLang.es => 'Pulsa „Nueva lista”, escribe un nombre y selecciona palabras.',
        UiLang.ru => 'Нажми «Новый набор», введи имя и выбери слова.',
      };

  String wordPoolsTitle(String langName) => switch (lang) {
        UiLang.pl => 'Pule słówek — $langName',
        UiLang.en => 'Word pools — $langName',
        UiLang.es => 'Listas de palabras — $langName',
        UiLang.ru => 'Наборы слов — $langName',
      };

  String get deleteWordConfirm => switch (lang) {
        UiLang.pl => 'Usunąć słówko?',
        UiLang.en => 'Delete word?',
        UiLang.es => '¿Eliminar palabra?',
        UiLang.ru => 'Удалить слово?',
      };

  String get editWord => switch (lang) {
        UiLang.pl => 'Edytuj słówko',
        UiLang.en => 'Edit word',
        UiLang.es => 'Editar palabra',
        UiLang.ru => 'Изменить слово',
      };

  String wordsTitle(String langName) => switch (lang) {
        UiLang.pl => 'Słówka — $langName',
        UiLang.en => 'Words — $langName',
        UiLang.es => 'Palabras — $langName',
        UiLang.ru => 'Слова — $langName',
      };

  String bought(String name) => switch (lang) {
        UiLang.pl => 'Kupiono: $name! 🐾',
        UiLang.en => 'Bought: $name! 🐾',
        UiLang.es => '¡Comprado: $name! 🐾',
        UiLang.ru => 'Куплено: $name! 🐾',
      };

  String get clothesTab => switch (lang) {
        UiLang.pl => 'Ubranka',
        UiLang.en => 'Clothes',
        UiLang.es => 'Ropa',
        UiLang.ru => 'Одежда',
      };

  String get roomTab => switch (lang) {
        UiLang.pl => 'Pokoik',
        UiLang.en => 'Room',
        UiLang.es => 'Habitación',
        UiLang.ru => 'Комната',
      };

  String shopBlurbFull({
    required int perCorrect,
    required int feedBonus,
    required String pet,
    required int perLevel,
    required int dailyChat,
  }) =>
      switch (lang) {
        UiLang.pl =>
          'Złote łapki: +$perCorrect za poprawną odpowiedź, '
              '+$feedBonus gdy $pet najedzona, '
              '+$perLevel za poziom, '
              '+$dailyChat za rozmowę AI.',
        UiLang.en =>
          'Golden paws: +$perCorrect per correct answer, '
              '+$feedBonus when $pet is full, '
              '+$perLevel per level, '
              '+$dailyChat for AI chat.',
        UiLang.es =>
          'Patitas doradas: +$perCorrect por respuesta correcta, '
              '+$feedBonus cuando $pet está llena, '
              '+$perLevel por nivel, '
              '+$dailyChat por charla IA.',
        UiLang.ru =>
          'Золотые лапки: +$perCorrect за правильный ответ, '
              '+$feedBonus когда $pet сыта, '
              '+$perLevel за уровень, '
              '+$dailyChat за чат с ИИ.',
      };

  String get preview3d => switch (lang) {
        UiLang.pl => 'Podgląd 3D',
        UiLang.en => '3D preview',
        UiLang.es => 'Vista 3D',
        UiLang.ru => 'Просмотр 3D',
      };

  String get unequip => switch (lang) {
        UiLang.pl => 'Zdjęte',
        UiLang.en => 'Unequip',
        UiLang.es => 'Quitar',
        UiLang.ru => 'Снять',
      };

  String get equip => switch (lang) {
        UiLang.pl => 'Ubierz',
        UiLang.en => 'Wear',
        UiLang.es => 'Vestir',
        UiLang.ru => 'Надеть',
      };

  String get hideItem => switch (lang) {
        UiLang.pl => 'Schowaj',
        UiLang.en => 'Hide',
        UiLang.es => 'Guardar',
        UiLang.ru => 'Убрать',
      };

  String get showItem => switch (lang) {
        UiLang.pl => 'Wystaw',
        UiLang.en => 'Place',
        UiLang.es => 'Colocar',
        UiLang.ru => 'Поставить',
      };

  String shopTitle(String pet) => switch (lang) {
        UiLang.pl => 'Sklep $pet',
        UiLang.en => '$pet shop',
        UiLang.es => 'Tienda de $pet',
        UiLang.ru => 'Магазин: $pet',
      };

  String get petCat => switch (lang) {
        UiLang.pl => '🐱 Kot',
        UiLang.en => '🐱 Cat',
        UiLang.es => '🐱 Gato',
        UiLang.ru => '🐱 Кот',
      };

  String get petDog => switch (lang) {
        UiLang.pl => '🐶 Pies',
        UiLang.en => '🐶 Dog',
        UiLang.es => '🐶 Perro',
        UiLang.ru => '🐶 Пёс',
      };

  String get shop => switch (lang) {
        UiLang.pl => 'Sklep',
        UiLang.en => 'Shop',
        UiLang.es => 'Tienda',
        UiLang.ru => 'Магазин',
      };

  String get fullWardrobe => switch (lang) {
        UiLang.pl => 'Pełna garderoba',
        UiLang.en => 'Full wardrobe',
        UiLang.es => 'Vestuario completo',
        UiLang.ru => 'Полный гардероб',
      };

  String furColorHint(bool dog) => switch (lang) {
        UiLang.pl => dog
            ? 'Kolor sierści — stuknij, żeby zmienić'
            : 'Kolor futerka — stuknij, żeby zmienić',
        UiLang.en => dog
            ? 'Coat color — tap to change'
            : 'Fur color — tap to change',
        UiLang.es => dog
            ? 'Color del pelaje — toca para cambiar'
            : 'Color del pelaje — toca para cambiar',
        UiLang.ru => dog
            ? 'Цвет шерсти — нажми, чтобы сменить'
            : 'Цвет шёрстки — нажми, чтобы сменить',
      };

  String petNeedsOutfit(String name) => switch (lang) {
        UiLang.pl =>
          'Awansuj na poziom 2 albo zajrzyj do sklepu — $name dostanie ubranko!',
        UiLang.en =>
          'Reach level 2 or visit the shop — $name will get an outfit!',
        UiLang.es =>
          '¡Sube al nivel 2 o mira la tienda — $name recibirá un atuendo!',
        UiLang.ru =>
          'Дойди до уровня 2 или зайди в магазин — $name получит одежду!',
      };

  String petName(bool dog) => switch (lang) {
        UiLang.pl => dog ? 'Piesek' : 'Kicia',
        UiLang.en => dog ? 'Puppy' : 'Kitty',
        UiLang.es => dog ? 'Perrito' : 'Michi',
        UiLang.ru => dog ? 'Пёсик' : 'Киса',
      };

  String slotHead() => switch (lang) {
        UiLang.pl => 'Głowa',
        UiLang.en => 'Head',
        UiLang.es => 'Cabeza',
        UiLang.ru => 'Голова',
      };

  String slotNeck() => switch (lang) {
        UiLang.pl => 'Szyja',
        UiLang.en => 'Neck',
        UiLang.es => 'Cuello',
        UiLang.ru => 'Шея',
      };

  String slotFace() => switch (lang) {
        UiLang.pl => 'Buzia',
        UiLang.en => 'Face',
        UiLang.es => 'Cara',
        UiLang.ru => 'Мордочка',
      };

  String slotBody() => switch (lang) {
        UiLang.pl => 'Ciałko',
        UiLang.en => 'Body',
        UiLang.es => 'Cuerpo',
        UiLang.ru => 'Тельце',
      };

  String slotSpecial() => switch (lang) {
        UiLang.pl => 'Specjalne',
        UiLang.en => 'Special',
        UiLang.es => 'Especial',
        UiLang.ru => 'Особое',
      };

  String playbackError(Object e) => switch (lang) {
        UiLang.pl => 'Odtwarzanie: $e',
        UiLang.en => 'Playback: $e',
        UiLang.es => 'Reproducción: $e',
        UiLang.ru => 'Воспроизведение: $e',
      };

  String get noAudioHint => switch (lang) {
        UiLang.pl =>
          'Brak audio. Na PC: python3 scripts/generate_tts.py',
        UiLang.en =>
          'No audio. On PC: python3 scripts/generate_tts.py',
        UiLang.es =>
          'Sin audio. En PC: python3 scripts/generate_tts.py',
        UiLang.ru =>
          'Нет аудио. На ПК: python3 scripts/generate_tts.py',
      };

  String get fedHappy => switch (lang) {
        UiLang.pl => 'Syta i szczęśliwa! (+nauka dziś ✓)',
        UiLang.en => 'Full and happy! (+study today ✓)',
        UiLang.es => '¡Llena y feliz! (+estudio hoy ✓)',
        UiLang.ru => 'Сыта и счастлива! (+учёба сегодня ✓)',
      };

  String get alreadyFed => switch (lang) {
        UiLang.pl => 'Już najedzona — możesz dalej ćwiczyć.',
        UiLang.en => 'Already full — you can keep practicing.',
        UiLang.es => 'Ya está llena — puedes seguir practicando.',
        UiLang.ru => 'Уже сыта — можешь продолжать учиться.',
      };

  String wordsLeftToFeed(int n) => switch (lang) {
        UiLang.pl =>
          'Głodna… nakarm nauką: jeszcze $n słówk${n == 1 ? 'o' : 'a'} dziś',
        UiLang.en => 'Hungry… feed with study: $n more word${n == 1 ? '' : 's'} today',
        UiLang.es =>
          'Hambrienta… alimenta con estudio: faltan $n palabra${n == 1 ? '' : 's'} hoy',
        UiLang.ru =>
          'Голодна… покорми учёбой: ещё $n слов${n == 1 ? 'о' : ''} сегодня',
      };

  String mascotTrainingTitle(String name) => switch (lang) {
        UiLang.pl => '$name — maskotka Treningu',
        UiLang.en => '$name — Training pet',
        UiLang.es => '$name — mascota del Entrenamiento',
        UiLang.ru => '$name — питомец Тренировки',
      };

  String get eatWordsDog => switch (lang) {
        UiLang.pl => 'Hau! Jem słówka!',
        UiLang.en => 'Woof! I eat words!',
        UiLang.es => '¡Guau! ¡Como palabras!',
        UiLang.ru => 'Гав! Ем слова!',
      };

  String get eatWordsCat => switch (lang) {
        UiLang.pl => 'Miaaa… jem słówka!',
        UiLang.en => 'Meow… I eat words!',
        UiLang.es => '¡Miau… como palabras!',
        UiLang.ru => 'Мяу… ем слова!',
      };

  String get collectPawsBlurb => switch (lang) {
        UiLang.pl =>
          'Zbieraj złote łapki 🐾 za poprawne odpowiedzi i kupuj '
              'miski, posłanie oraz ekskluzywne ubranka w sklepie!',
        UiLang.en =>
          'Collect golden paws 🐾 for correct answers and buy '
              'bowls, beds and exclusive outfits in the shop!',
        UiLang.es =>
          '¡Reúne patitas doradas 🐾 por respuestas correctas y compra '
              'comederos, camas y ropa exclusiva en la tienda!',
        UiLang.ru =>
          'Собирай золотые лапки 🐾 за правильные ответы и покупай '
              'миски, лежанки и эксклюзивную одежду в магазине!',
      };

  String get pasteOrPath => switch (lang) {
        UiLang.pl => 'Wklej tekst albo podaj ścieżkę',
        UiLang.en => 'Paste text or provide a path',
        UiLang.es => 'Pega texto o indica una ruta',
        UiLang.ru => 'Вставь текст или укажи путь',
      };

  String cannotReadFile(Object e) => switch (lang) {
        UiLang.pl => 'Nie da się odczytać pliku: $e',
        UiLang.en => 'Cannot read file: $e',
        UiLang.es => 'No se puede leer el archivo: $e',
        UiLang.ru => 'Не удалось прочитать файл: $e',
      };

  String audioUnavailable(Object e) => switch (lang) {
        UiLang.pl => 'Audio niedostępne: $e',
        UiLang.en => 'Audio unavailable: $e',
        UiLang.es => 'Audio no disponible: $e',
        UiLang.ru => 'Аудио недоступно: $e',
      };

  String paletteLabel(String key) => switch (key) {
        'mint' => switch (lang) {
            UiLang.pl => 'Mięta (świeża)',
            UiLang.en => 'Mint (fresh)',
            UiLang.es => 'Menta (fresca)',
            UiLang.ru => 'Мята (свежая)',
          },
        'candy' => switch (lang) {
            UiLang.pl => 'Cukierek (koral)',
            UiLang.en => 'Candy (coral)',
            UiLang.es => 'Caramelo (coral)',
            UiLang.ru => 'Конфета (коралл)',
          },
        'sky' => switch (lang) {
            UiLang.pl => 'Niebo (błękit)',
            UiLang.en => 'Sky (blue)',
            UiLang.es => 'Cielo (azul)',
            UiLang.ru => 'Небо (голубое)',
          },
        'sunset' => switch (lang) {
            UiLang.pl => 'Zachód (pomarańcz)',
            UiLang.en => 'Sunset (orange)',
            UiLang.es => 'Atardecer (naranja)',
            UiLang.ru => 'Закат (оранжевый)',
          },
        'berry' => switch (lang) {
            UiLang.pl => 'Jagoda (róż)',
            UiLang.en => 'Berry (pink)',
            UiLang.es => 'Baya (rosa)',
            UiLang.ru => 'Ягода (розовая)',
          },
        'forest' => switch (lang) {
            UiLang.pl => 'Las (zielony)',
            UiLang.en => 'Forest (green)',
            UiLang.es => 'Bosque (verde)',
            UiLang.ru => 'Лес (зелёный)',
          },
        'slate' => switch (lang) {
            UiLang.pl => 'Grafit',
            UiLang.en => 'Slate',
            UiLang.es => 'Pizarra',
            UiLang.ru => 'Графит',
          },
        _ => key,
      };
}
