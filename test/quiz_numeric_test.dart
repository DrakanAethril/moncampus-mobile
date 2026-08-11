import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/quiz.dart';

/// The Numérique / Calculée additions: the app reads a statement the *server* already rendered with
/// this student's drawn values, and never sees the expected value until the correction. Both are
/// deliberate - the substitution rule and the answer both belong to the grader.
void main() {
  group('QuizQuestion numeric payload', () {
    test('parses a calculée whose statement arrives already rendered', () {
      final question = QuizQuestion.fromJson({
        'type': 'calculee',
        'label': 'Un train roule à {v} km/h pendant {t} h.',
        'answers': [],
        'numericStatement': 'Un train roule à 120 km/h pendant 2,5 h.',
        'numericUnit': 'km',
        'numericUnitRequired': false,
      });

      expect(question.isNumeric, isTrue);
      // The rendered statement is what the screen shows; the raw label still carries the markers.
      expect(question.numericStatement, 'Un train roule à 120 km/h pendant 2,5 h.');
      expect(question.numericUnit, 'km');
      expect(question.numericUnitRequired, isFalse);
    });

    test('parses a plain numérique that requires its unit', () {
      final question = QuizQuestion.fromJson({
        'type': 'numerique',
        'label': 'Quelle est l\'accélération de la pesanteur ?',
        'answers': [],
        'numericStatement': 'Quelle est l\'accélération de la pesanteur ?',
        'numericUnit': 'm/s²',
        'numericUnitRequired': true,
      });

      expect(question.isNumeric, isTrue);
      expect(question.numericUnitRequired, isTrue);
    });

    test('a question of another type carries no numeric data', () {
      final question = QuizQuestion.fromJson({'type': 'qcm', 'label': 'x', 'answers': []});

      expect(question.isNumeric, isFalse);
      expect(question.numericStatement, isNull);
      expect(question.numericUnit, isNull);
      expect(question.numericUnitRequired, isFalse);
    });
  });

  group('QuizCorrectionEntry numeric payload', () {
    test('reads the replayed statement, the answer and the accepted range', () {
      final entry = QuizCorrectionEntry.fromJson({
        'type': 'calculee',
        'isCorrect': false,
        'numericStatement': 'Un train roule à 140 km/h pendant 2,0 h.',
        'numericRaw': '12,5',
        'numericExpected': 280,
        'numericMargin': 5.6,
        'numericUnit': 'km',
        'numericDecimals': 2,
      });

      expect(entry.isNumeric, isTrue);
      expect(entry.numericStatement, 'Un train roule à 140 km/h pendant 2,0 h.');
      expect(entry.numericRaw, '12,5');
      expect(entry.numericExpected, 280.0);
      expect(entry.numericMargin, 5.6);
      expect(entry.numericDecimals, 2);
    });

    test('an unanswerable question comes back without an expected value', () {
      // A formula that does not evaluate for these values: the server sends null rather than a
      // number, and the app has to render that as "no expected value" instead of crashing on it.
      final entry = QuizCorrectionEntry.fromJson({
        'type': 'calculee',
        'numericRaw': '3',
        'numericExpected': null,
        'numericMargin': null,
      });

      expect(entry.numericExpected, isNull);
      expect(entry.numericMargin, isNull);
      expect(entry.numericDecimals, 2, reason: 'falls back rather than throwing');
    });

    test('an integer expected value still reads as a double', () {
      // PHP serialises 280.0 as 280 - a plain `as double?` cast would throw on it.
      final entry = QuizCorrectionEntry.fromJson({'type': 'numerique', 'numericExpected': 300});

      expect(entry.numericExpected, 300.0);
    });
  });
}
