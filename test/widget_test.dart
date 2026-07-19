import 'package:flutter_test/flutter_test.dart';
import 'package:trener_jezykowy/models.dart';

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
}
