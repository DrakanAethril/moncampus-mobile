import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/quiz.dart';
import 'package:moncampus_mobile/screens/quiz_contract_screen.dart';
import 'package:moncampus_mobile/utils/penalty.dart';
import 'package:moncampus_mobile/widgets/quiz_penalty_notice.dart';

/// « Note négative sur erreurs », app side. Nothing here is decided: the marks are computed on the
/// server and frozen into each answer as it is given, so the app only ever reads the rule and words
/// it. What is worth pinning is that it words it the same way everywhere, and that a quiz without a
/// penalty - or a server that has never heard of one - shows nothing at all.
void main() {
  group('QuizNegativeMarking', () {
    test('a fixed penalty is said in points', () {
      final penalty = QuizNegativeMarking.fromJson(
        {'mode': 'fixed', 'points': 0.5, 'percent': 50, 'floorAtZero': true},
      )!;

      expect(penalty.isScale, isFalse);
      expect(penalty.shortLabel, '−0,5 pt par erreur');
      expect(penalty.costSentence, 'Chaque réponse fausse retire 0,5 point.');
      expect(penalty.floorSentence, 'La note ne peut pas descendre en dessous de 0.');
    });

    test('a scale penalty is said as a share of the question', () {
      final penalty = QuizNegativeMarking.fromJson(
        {'mode': 'scale', 'points': 0.5, 'percent': 25, 'floorAtZero': false},
      )!;

      expect(penalty.isScale, isTrue);
      expect(penalty.shortLabel, '−25 % du barème par erreur');
      expect(penalty.costSentence, 'Chaque réponse fausse retire 25 % du barème de la question.');
      expect(penalty.floorSentence, 'La note peut descendre en dessous de 0.');
    });

    /// A quiz carrying no penalty sends null, and a server that predates the feature sends nothing:
    /// the same absence, the same answer, and no screen has to tell them apart.
    test('null and absent both mean no penalty', () {
      expect(QuizNegativeMarking.fromJson(null), isNull);
      expect(QuizNegativeMarking.fromJson(<String, dynamic>{}['negativeMarking']), isNull);
    });
  });

  group('the rule reaches every screen that announces it', () {
    test('an évaluation row carries it', () {
      final evaluation = QuizEvaluation.fromJson({
        'instanceId': 4,
        'name': 'Réseaux — contrôle du chapitre 4',
        'negativeMarking': {'mode': 'fixed', 'points': 0.5, 'percent': 50, 'floorAtZero': true},
      });

      expect(evaluation.negativeMarking?.shortLabel, '−0,5 pt par erreur');
    });

    test('an entraînement row carries it', () {
      final practice = QuizPractice.fromJson({
        'instanceId': 7,
        'name': 'Adressage IP — révisions',
        'negativeMarking': {'mode': 'scale', 'points': 0.5, 'percent': 100, 'floorAtZero': false},
      });

      expect(practice.negativeMarking?.shortLabel, '−100 % du barème par erreur');
    });

    test('the passation carries it, so an entraînement is told too - it has no door', () {
      final page = QuizQuestionPage.fromJson({
        'attemptId': 12,
        'negativeMarking': {'mode': 'fixed', 'points': 1, 'percent': 50, 'floorAtZero': true},
      });

      expect(page.negativeMarking?.costSentence, 'Chaque réponse fausse retire 1 point.');
    });

    test('an ordinary quiz carries none of it', () {
      final page = QuizQuestionPage.fromJson({'attemptId': 12});
      final evaluation = QuizEvaluation.fromJson({'instanceId': 4, 'name': 'Révisions'});

      expect(page.negativeMarking, isNull);
      expect(evaluation.negativeMarking, isNull);
    });
  });

  group('the copy that comes back', () {
    test('the result carries the rule that explains its mark', () {
      final result = QuizResult.fromJson({
        'quizName': 'Réseaux',
        'mode': 'entrainement',
        'scoreVisible': true,
        'score': '-1',
        'questionTotal': 5,
        'negativeMarking': {'mode': 'fixed', 'points': 0.5, 'percent': 50, 'floorAtZero': false},
      });

      expect(result.negativeMarking?.floorSentence, 'La note peut descendre en dessous de 0.');
    });

    test('a correction line carries what it was worth, negative included', () {
      final charged = QuizCorrectionEntry.fromJson({'label': 'Q1', 'type': 'qcm', 'isCorrect': false, 'score': -0.5});
      final earned = QuizCorrectionEntry.fromJson({'label': 'Q2', 'type': 'qcm', 'isCorrect': true, 'score': 1});

      expect(charged.score, -0.5);
      expect(earned.score, 1.0);
    });

    /// An older server sends no score per line - the correction then simply shows no figure rather
    /// than inventing one.
    test('a line with no score reads as null', () {
      final entry = QuizCorrectionEntry.fromJson({'label': 'Q1', 'type': 'qcm', 'isCorrect': false});

      expect(entry.score, isNull);
    });
  });

  group('formatting', () {
    test('drops the trailing zeros a half point does not need', () {
      expect(formatPenaltyPoints(0.5), '0,5');
      expect(formatPenaltyPoints(1), '1');
      expect(formatPenaltyPoints(0.25), '0,25');
      expect(formatPenaltyPoints(2), '2');
    });

    /// Always signed: a line that cost something has to read differently from one that simply
    /// earned nothing.
    test('a line score is always signed', () {
      expect(formatPenaltyScore(-0.5), '−0,5');
      expect(formatPenaltyScore(1), '+1');
    });
  });

  group('the door of a supervised assessment', () {
    /// Pumped whole rather than the notice alone: what is being pinned here is the *wiring* - the
    /// rule reaching the screen from the évaluation it was launched with.
    testWidgets('announces the penalty alongside the surveillance', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: QuizContractScreen(
          evaluation: QuizEvaluation.fromJson({
            'instanceId': 4,
            'name': 'Réseaux — contrôle du chapitre 4',
            'questionCount': 5,
            'supervised': true,
            'negativeMarking': {'mode': 'scale', 'points': 0.5, 'percent': 50, 'floorAtZero': true},
          }),
        ),
      ));

      expect(find.text('Chaque réponse fausse retire 50 % du barème de la question.'), findsOneWidget);
      expect(find.text('Ce contrôle est surveillé.'), findsOneWidget);
    });

    testWidgets('says nothing about a penalty the quiz does not carry', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: QuizContractScreen(
          evaluation: QuizEvaluation.fromJson({'instanceId': 4, 'name': 'Contrôle', 'supervised': true}),
        ),
      ));

      expect(find.textContaining('réponse fausse'), findsNothing);
    });
  });

  group('QuizPenaltyNotice', () {
    testWidgets('says the cost and the floor', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuizPenaltyNotice(
            penalty: QuizNegativeMarking.fromJson(
              {'mode': 'fixed', 'points': 0.5, 'percent': 50, 'floorAtZero': true},
            ),
          ),
        ),
      ));

      expect(find.text('Chaque réponse fausse retire 0,5 point.'), findsOneWidget);
      expect(find.textContaining('ne peut pas descendre en dessous de 0'), findsOneWidget);
      // The two exemptions belong in the announcement, not only in the code: a student who leaves a
      // question blank must not believe it will cost them.
      expect(find.textContaining('partiellement juste'), findsOneWidget);
      expect(find.textContaining('sans réponse'), findsOneWidget);
    });

    /// Rendered unconditionally by every screen, so it has to disappear on its own.
    testWidgets('draws nothing at all without a penalty', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: QuizPenaltyNotice(penalty: null))));

      expect(find.byType(Text), findsNothing);
    });
  });
}
