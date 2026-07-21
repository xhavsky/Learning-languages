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

  test("skróty EN — I'm ≈ I am, don't ≈ do not", () {
    expect(answersMatch("I'm", 'I am', lang: 'Angielski'), isTrue);
    expect(answersMatch('I am', "I'm", lang: 'Angielski'), isTrue);
    expect(answersMatch("i'm happy", 'I am happy', lang: 'Angielski'), isTrue);
    expect(answersMatch('I am happy', "I'm happy", lang: 'Angielski'), isTrue);
    expect(answersMatch("don't", 'do not', lang: 'Angielski'), isTrue);
    expect(answersMatch('do not', "don't", lang: 'Angielski'), isTrue);
    expect(answersMatch("can't", 'cannot', lang: 'Angielski'), isTrue);
    expect(answersMatch('I am sad', "I'm happy", lang: 'Angielski'), isFalse);
  });
}
