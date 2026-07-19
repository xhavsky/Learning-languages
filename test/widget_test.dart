import 'package:flutter_test/flutter_test.dart';
import 'package:trener_jezykowy/curiosities.dart';
import 'package:trener_jezykowy/import_csv.dart';
import 'package:trener_jezykowy/models.dart';
import 'package:trener_jezykowy/storage.dart';

void main() {
  test('parseBaza migrates legacy list format', () {
    final baza = parseBaza({
      'Angielski': [
        {'pl': 'kot', 'obcy': 'cat', 'nauczone': true},
      ],
    });
    expect(baza['Angielski']!.words, hasLength(1));
    expect(baza['Angielski']!.words.first.level, 3);
    expect(baza['Angielski']!.words.first.pl, 'Kot');
    expect(baza['Angielski']!.groups, isEmpty);
  });

  test('parseBaza reads groups with wordIds', () {
    final baza = parseBaza({
      'Angielski': {
        'words': [
          {'id': 'a', 'pl': 'kot', 'obcy': 'cat'},
          {'id': 'b', 'pl': 'pies', 'obcy': 'dog'},
        ],
        'groups': [
          {
            'id': 'g1',
            'name': 'Zwierzęta',
            'wordIds': ['a'],
          },
        ],
      },
    });
    final pack = baza['Angielski']!;
    expect(pack.wordsForGroup('g1').map((w) => w.pl), ['Kot']);
    expect(pack.wordsForGroup('__all__'), hasLength(2));
  });

  test('applySrs needs 3 correct in a row to master', () {
    final w = Word(id: 'x', pl: 'Dom', obcy: 'House');
    applySrs(w, correct: true);
    expect(w.level, 1);
    expect(w.correctStreak, 1);
    expect(w.nauczone, isFalse);

    applySrs(w, correct: true);
    expect(w.level, 2);
    expect(w.correctStreak, 2);
    expect(w.nauczone, isFalse);

    applySrs(w, correct: true);
    expect(w.level, 3);
    expect(w.correctStreak, 3);
    expect(w.nauczone, isTrue);
  });

  test('wrong answer resets streak', () {
    final w = Word(id: 'x', pl: 'Dom', obcy: 'House');
    applySrs(w, correct: true);
    applySrs(w, correct: true);
    expect(w.correctStreak, 2);
    applySrs(w, correct: false);
    expect(w.correctStreak, 0);
    expect(w.level, 0);
    expect(w.hard, isTrue);
    expect(w.nauczone, isFalse);
  });

  test('removeWord drops from groups', () {
    final pack = LangPack(
      words: [
        Word(id: 'a', pl: 'Kot', obcy: 'Cat'),
        Word(id: 'b', pl: 'Pies', obcy: 'Dog'),
      ],
      groups: [
        WordGroup(id: 'g', name: 'Z', wordIds: ['a', 'b']),
      ],
    );
    expect(pack.removeWord('a'), isTrue);
    expect(pack.words.map((w) => w.id), ['b']);
    expect(pack.groups.first.wordIds, ['b']);
  });

  test('capitalizePhrase', () {
    expect(capitalizePhrase('dom'), 'Dom');
    expect(capitalizePhrase('  hello'), 'Hello');
    expect(capitalizePhrase('быть'), 'Быть');
  });

  test('parseWordText csv and dash', () {
    final pairs = parseWordText('''
pl,obcy
kot,cat
pies;dog
dom - house
# komentarz
''');
    expect(pairs.map((p) => '${p.pl}|${p.obcy}').toList(), [
      'Kot|Cat',
      'Pies|Dog',
      'Dom|House',
    ]);
  });

  test('importWordText skips duplicates', () {
    final pack = LangPack(
      words: [Word.fromJson({'pl': 'Kot', 'obcy': 'Cat'})],
      groups: [],
    );
    final r = importWordText(pack, 'kot,cat\npies,dog');
    expect(r.added, 1);
    expect(r.skippedDuplicates, 1);
    expect(pack.words, hasLength(2));
  });

  test('AppStats xp and levels', () {
    final s = AppStats();
    expect(s.playerLevel, 1);
    s.addXp(50);
    expect(s.playerLevel, 2);
    s.recordAnswer(true);
    expect(s.xp, 60);
    expect(s.sessionXp, 60);
    final gained = s.completeDailyChat();
    expect(gained, 40);
    expect(s.completeDailyChat(), 0);
    expect(s.chatDoneToday, isTrue);
  });

  test('level rewards pending then claimed', () {
    final s = AppStats();
    expect(s.pendingRewardLevels(), isEmpty);
    s.addXp(50); // level 2
    expect(s.pendingRewardLevels(), [2]);
    s.markRewardsClaimed([2]);
    expect(s.rewardedLevel, 2);
    expect(s.pendingRewardLevels(), isEmpty);
  });

  test('categoriesFor returns group names', () {
    final pack = LangPack(
      words: [
        Word(id: 'a', pl: 'Kot', obcy: 'Cat'),
        Word(id: 'b', pl: 'Pies', obcy: 'Dog'),
      ],
      groups: [
        WordGroup(id: 'z', name: 'Zwierzęta', wordIds: ['a', 'b']),
      ],
    );
    expect(pack.categoriesFor('a'), ['Zwierzęta']);
    expect(pack.categoriesFor('missing'), isEmpty);
  });

  test('curiosityForLevel returns fact', () {
    final c = curiosityForLevel(2, lang: 'Angielski');
    expect(c.title, isNotEmpty);
    expect(c.text, isNotEmpty);
  });

  test('titleForLevel and album unlock', () {
    expect(titleForLevel(1).title, 'Nowicjuszka');
    expect(titleForLevel(6).title, 'Rozmówczyni');
    expect(newTitleAtLevel(2)?.title, 'Łowczyni słówek');
    expect(unlockedCuriosities(rewardedLevel: 1), isEmpty);
    expect(unlockedCuriosities(rewardedLevel: 3, lang: 'Angielski'), isNotEmpty);
    expect(levelUpBonusXpFor(5), greaterThan(levelUpBonusXpFor(2)));
  });
}
