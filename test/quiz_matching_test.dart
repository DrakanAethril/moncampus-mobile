import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/quiz.dart';
import 'package:moncampus_mobile/widgets/quiz_matching_board.dart';

/// The Apparier additions: the model must read the API payload exactly as the server writes it
/// (Api\QuizController), including the fact that the answer side of a pair is *absent* during the
/// attempt and only arrives at correction time, and the board must report taps by pair id - that id
/// is what the answer is expressed in.
void main() {
  group('QuizQuestion apparier payload', () {
    test('parses a text question and withholds the answer side', () {
      final question = QuizQuestion.fromJson({
        'type': 'apparier',
        'label': 'Reliez chaque pays à sa capitale.',
        'answers': [],
        'matchingHeaders': {'left': 'Pays', 'right': 'Capitale'},
        'matchingLeftKind': 'texte',
        'matchingRightKind': 'texte',
        'matchingPairs': [
          {'id': 'p1', 'left': 'France', 'leftImageUrl': null},
          {'id': 'p2', 'left': 'Italie', 'leftImageUrl': null},
        ],
        'matchingChoices': [
          {'key': 'p1', 'text': 'Paris', 'imageUrl': null},
          {'key': 'd0', 'text': 'Bruxelles', 'imageUrl': null},
        ],
      });

      expect(question.isApparier, isTrue);
      expect(question.matchingHeaders.left, 'Pays');
      expect(question.matchingPairs.map((p) => p.id), ['p1', 'p2']);
      // The right-hand side is the answer: the server does not send it during the attempt.
      expect(question.matchingPairs.first.hasAnswer, isFalse);
      expect(question.matchingChoices.map((c) => c.key), ['p1', 'd0']);
    });

    test('parses an image column, keeping the alt text alongside the url', () {
      final question = QuizQuestion.fromJson({
        'type': 'apparier',
        'label': 'Reliez.',
        'answers': [],
        'matchingRightKind': 'image',
        'matchingPairs': [
          {'id': 'p1', 'left': 'Rouge', 'leftImageUrl': null},
        ],
        'matchingChoices': [
          {'key': 'p1', 'text': 'Figure rouge', 'imageUrl': 'https://cdn/x.png'},
        ],
      });

      expect(question.matchingChoices.first.imageUrl, 'https://cdn/x.png');
      expect(question.matchingChoices.first.text, 'Figure rouge');
    });

    test('a question of another type carries no matching data', () {
      final question = QuizQuestion.fromJson({'type': 'qcm', 'label': 'x', 'answers': []});

      expect(question.isApparier, isFalse);
      expect(question.matchingPairs, isEmpty);
      expect(question.matchingHeaders.left, '');
    });
  });

  group('QuizCorrectionEntry apparier payload', () {
    test('reads the answer side, the verdicts and the feedbacks', () {
      final entry = QuizCorrectionEntry.fromJson({
        'type': 'apparier',
        'matchingHeaders': {'left': 'Pays', 'right': 'Capitale'},
        'matchingPairs': [
          {'id': 'p1', 'left': 'France', 'leftImageUrl': null, 'right': 'Paris', 'rightImageUrl': null},
        ],
        'matchingChoices': [
          {'key': 'p1', 'text': 'Paris', 'imageUrl': null},
        ],
        'matchingResponses': {'p1': 'd0'},
        'matchingResults': {'p1': false},
        'matchingFeedback': {'p1': 'Paris depuis 987.'},
      });

      expect(entry.isApparier, isTrue);
      expect(entry.matchingPairs.first.hasAnswer, isTrue);
      expect(entry.matchingPairs.first.right, 'Paris');
      expect(entry.matchingResults, {'p1': false});
      expect(entry.matchingFeedback['p1'], 'Paris depuis 987.');
    });

    test('tolerates the empty-array shape PHP gives an empty map', () {
      // An unanswered question stores [], and an apparier with no feedback serializes its empty
      // map the same way - both readings must accept it (same guard as the zones payload).
      final entry = QuizCorrectionEntry.fromJson({
        'type': 'apparier',
        'matchingResponses': <dynamic>[],
        'matchingResults': <dynamic>[],
        'matchingFeedback': <dynamic>[],
      });

      expect(entry.matchingResponses, isEmpty);
      expect(entry.matchingResults, isEmpty);
      expect(entry.matchingFeedback, isEmpty);
    });
  });

  group('QuizMatchingBoard', () {
    const pairs = [
      QuizMatchingPair(id: 'p1', left: 'France', leftImageUrl: null, right: null, rightImageUrl: null),
      QuizMatchingPair(id: 'p2', left: 'Italie', leftImageUrl: null, right: null, rightImageUrl: null),
    ];

    testWidgets('reports taps by pair id', (tester) async {
      final taps = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuizMatchingBoard(
            pairs: pairs,
            headers: const QuizMatchingHeaders(left: 'Pays', right: 'Capitale'),
            stateOf: (_) => MatchVisualState.none,
            onSlotTap: taps.add,
          ),
        ),
      ));

      expect(find.text('France'), findsOneWidget);
      // The left column is a clue, not a target - only the slot under it answers a tap.
      await tester.tap(find.byType(GestureDetector).last);
      expect(taps, ['p2']);
    });

    testWidgets('shows the item placed in a slot', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuizMatchingBoard(
            pairs: pairs,
            headers: const QuizMatchingHeaders(left: '', right: ''),
            stateOf: (_) => MatchVisualState.none,
            placedOf: (id) => id == 'p1'
                ? const QuizMatchingChoice(key: 'p1', text: 'Paris', imageUrl: null)
                : null,
          ),
        ),
      ));

      expect(find.text('Paris'), findsOneWidget);
    });

    testWidgets('reveals the expected item only on a pair that went wrong', (tester) async {
      const answered = [
        QuizMatchingPair(id: 'p1', left: 'France', leftImageUrl: null, right: 'Paris', rightImageUrl: null),
        QuizMatchingPair(id: 'p2', left: 'Italie', leftImageUrl: null, right: 'Rome', rightImageUrl: null),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuizMatchingBoard(
            pairs: answered,
            headers: const QuizMatchingHeaders(left: '', right: ''),
            stateOf: (id) => id == 'p1' ? MatchVisualState.good : MatchVisualState.bad,
            reveal: true,
          ),
        ),
      ));

      // The one they got right needs no "Attendu :" - it is already in the slot.
      expect(find.text('Attendu : '), findsOneWidget);
      expect(find.text('Rome'), findsOneWidget);
      expect(find.text('Paris'), findsNothing);
    });
  });
}
