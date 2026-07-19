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
    expect(pack.wordsForGroup('g1').map((w) => w.pl), ['kot']);
    expect(pack.wordsForGroup('__all__'), hasLength(2));
  });

  test('applySrs raises level on correct', () {
    final w = Word(id: 'x', pl: 'dom', obcy: 'house');
    applySrs(w, correct: true);
    expect(w.level, 1);
    expect(w.nextDue, isNotNull);
    applySrs(w, correct: false);
    expect(w.level, 0);
    expect(w.hard, isTrue);
  });
}
