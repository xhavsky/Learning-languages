import 'package:dialectium/answer_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('to swim ≈ swim, ale nie swimming / swam', () {
    expect(answersMatch('swim', 'To swim', lang: 'Angielski'), isTrue);
    expect(answersMatch('to swim', 'To swim', lang: 'Angielski'), isTrue);
    expect(answersMatch('swimming', 'To swim', lang: 'Angielski'), isFalse);
    expect(answersMatch('swam', 'To swim', lang: 'Angielski'), isFalse);
    expect(answersMatch('run', 'To swim', lang: 'Angielski'), isFalse);
  });

  test('hiszpański — bez odmian, z akcentami', () {
    expect(answersMatch('nadar', 'Nadar', lang: 'Hiszpański'), isTrue);
    expect(answersMatch('nado', 'Nadar', lang: 'Hiszpański'), isFalse);
    expect(answersMatch('manana', 'Mañana', lang: 'Hiszpański'), isTrue);
  });

  test('polski — bez odmian', () {
    expect(
      answersMatch('pływać', 'Pływać', expectPolish: true),
      isTrue,
    );
    expect(
      answersMatch('plywac', 'Pływać', expectPolish: true),
      isTrue,
    );
    expect(
      answersMatch('pływam', 'Pływać', expectPolish: true),
      isFalse,
    );
  });
}
