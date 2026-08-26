import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/quiz.dart';

/// The mode contrôle, app side. Everything here is *read* rather than decided: the app reports and
/// renders, the server counts and judges - one rule, two clients.
void main() {
  group('QuizEvaluation', () {
    test('carries the supervised flag', () {
      final evaluation = QuizEvaluation.fromJson({
        'instanceId': 4,
        'name': 'Réseaux — contrôle du chapitre 4',
        'supervised': true,
      });

      expect(evaluation.supervised, isTrue);
    });

    /// A server that predates the mode contrôle says nothing, and an ordinary quiz is not
    /// supervised: the same absence, the same answer.
    test('reads a missing flag as not supervised', () {
      final evaluation = QuizEvaluation.fromJson({'instanceId': 4, 'name': 'Révisions'});

      expect(evaluation.supervised, isFalse);
    });
  });

  group('QuizStartOutcome', () {
    test('carries the key that owns the attempt', () {
      final outcome = QuizStartOutcome.fromJson({
        'attemptId': 12,
        'concluded': false,
        'supervised': true,
        'sessionKey': 'abc123',
        'supervisionExitSeconds': 8,
      });

      expect(outcome.attemptId, 12);
      expect(outcome.supervised, isTrue);
      expect(outcome.sessionKey, 'abc123');
      expect(outcome.exitSeconds, 8);
    });

    /// An ordinary quiz has no owner to be: there is nothing to take over.
    test('has no key on an unsupervised quiz', () {
      final outcome = QuizStartOutcome.fromJson({'attemptId': 12, 'concluded': false});

      expect(outcome.supervised, isFalse);
      expect(outcome.sessionKey, isNull);
    });
  });

  group('QuizQuestionPage', () {
    /// The point of the whole first lot: the countdown resumes where the server left it, rather
    /// than handing out a fresh budget on every reopening.
    test('counts down from what is left, not from the whole budget', () {
      final page = QuizQuestionPage.fromJson({
        'attemptId': 1,
        'position': 0,
        'total': 5,
        'secondsForQuestion': 30,
        'secondsRemaining': 11,
      });

      expect(page.secondsForQuestion, 30);
      expect(page.secondsRemaining, 11);
    });

    /// Against a server that does not send it, the whole budget is the only thing there is.
    test('falls back to the whole budget when the server does not say what is left', () {
      final page = QuizQuestionPage.fromJson({
        'attemptId': 1,
        'position': 0,
        'total': 5,
        'secondsForQuestion': 30,
      });

      expect(page.secondsRemaining, 30);
    });

    /// A present null is the answer, not a missing field: this question has no limit at all.
    test('keeps an explicit null as "no limit"', () {
      final page = QuizQuestionPage.fromJson({
        'attemptId': 1,
        'position': 0,
        'total': 5,
        'secondsForQuestion': null,
        'secondsRemaining': null,
      });

      expect(page.secondsRemaining, isNull);
    });

    test('reads the banner the server decided', () {
      final page = QuizQuestionPage.fromJson({
        'attemptId': 1,
        'position': 3,
        'total': 20,
        'supervision': {
          'exits': [38000, 12000],
          'warn': true,
          'submitAt': 5,
        },
      });

      expect(page.supervision, isNotNull);
      expect(page.supervision!.exitCount, 2);
      expect(page.supervision!.exitsMs, [38000, 12000]);
      expect(page.supervision!.warn, isTrue);
      expect(page.supervision!.submitAt, 5);
    });

    /// « Enregistrer seulement »: everything is journaled, nothing is shown.
    test('shows nothing when the policy does not warn', () {
      final page = QuizQuestionPage.fromJson({
        'attemptId': 1,
        'position': 0,
        'total': 5,
        'supervision': {'exits': [40000], 'warn': false},
      });

      expect(page.supervision!.warn, isFalse);
      expect(page.supervision!.submitAt, isNull);
    });

    test('has no supervision block on an ordinary quiz', () {
      final page = QuizQuestionPage.fromJson({'attemptId': 1, 'position': 0, 'total': 5});

      expect(page.supervision, isNull);
    });
  });
}
