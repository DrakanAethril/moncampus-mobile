import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/quiz.dart';

/// The Réponse courte additions. The point of this type on the app side is that there is almost
/// nothing to it: the server stores it as a texte à trous with a single blank, so it travels in the
/// same `blanks` field and comes back with the same per-blank verdicts. These tests pin that the
/// app reads it as one blank and never mistakes it for a real texte à trous.
void main() {
  group('QuizQuestion short answer payload', () {
    test('parses a short answer with its matching options', () {
      final question = QuizQuestion.fromJson({
        'type': 'reponse_courte',
        'label': 'Quel organite produit l\'ATP ?',
        'answers': [],
        'blankIgnoreCase': true,
        'blankTolerateTypo': true,
        // A short answer has no split statement and no bank: both are texte-à-trous things.
        'blankSegments': null,
        'wordBank': null,
      });

      expect(question.isShortAnswer, isTrue);
      expect(question.isBlanks, isFalse, reason: 'it must not take the texte à trous branch');
      expect(question.blankIgnoreCase, isTrue);
      expect(question.blankTolerateTypo, isTrue);
      expect(question.blankSegments, isEmpty);
      expect(question.blankCount, 0, reason: 'the count comes from the type, not from the segments');
    });

    test('the matching options fall back to the server defaults', () {
      final question = QuizQuestion.fromJson({'type': 'reponse_courte', 'label': 'x', 'answers': []});

      expect(question.blankIgnoreCase, isTrue, reason: 'case and accents forgiven by default');
      expect(question.blankTolerateTypo, isFalse, reason: 'typos are not');
    });

    test('a texte à trous is still its own thing', () {
      final question = QuizQuestion.fromJson({
        'type': 'texte_a_trous',
        'label': 'La méthode ... compile.',
        'answers': [],
        'blankSegments': [
          {'type': 'text', 'value': 'La méthode ', 'index': -1},
          {'type': 'blank', 'value': '', 'index': 0},
        ],
      });

      expect(question.isBlanks, isTrue);
      expect(question.isShortAnswer, isFalse);
      expect(question.blankCount, 1);
    });
  });

  group('QuizCorrectionEntry short answer payload', () {
    test('reads the typed answer, the verdict and every accepted wording', () {
      final entry = QuizCorrectionEntry.fromJson({
        'type': 'reponse_courte',
        'isCorrect': false,
        'blankResponses': ['ATP'],
        'blankResults': [false],
        'blankExpected': [
          ['mitochondrie', 'la mitochondrie', 'les mitochondries'],
        ],
      });

      expect(entry.isShortAnswer, isTrue);
      expect(entry.isBlanks, isFalse);
      expect(entry.blankResponses, ['ATP']);
      expect(entry.blankResults, [false]);
      expect(entry.blankExpected.first, ['mitochondrie', 'la mitochondrie', 'les mitochondries']);
    });

    test('an unanswered short answer comes back with an empty response list', () {
      final entry = QuizCorrectionEntry.fromJson({'type': 'reponse_courte', 'blankResponses': ['']});

      expect(entry.blankResponses, ['']);
      expect(entry.blankExpected, isEmpty);
    });
  });
}
