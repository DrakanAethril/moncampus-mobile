import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/quiz.dart';
import 'package:moncampus_mobile/widgets/quiz_zone_support.dart';

/// The Zone/Légende additions: the model must read the API payload exactly as the server writes
/// it (Api\QuizController), including the two shapes zoneResponses can take, and the support
/// widget must report taps by zone id - that id is the whole answer.
void main() {
  group('QuizQuestion zone payload', () {
    test('parses a code-support Zone question', () {
      final question = QuizQuestion.fromJson({
        'type': 'zone',
        'label': 'Cliquez la fermeture.',
        'answers': [],
        'zoneKind': 'code',
        'zoneLanguage': 'html',
        'zoneLines': [
          [
            {'type': 'text', 'value': '<body>', 'id': ''},
          ],
          [
            {'type': 'text', 'value': '  ', 'id': ''},
            {'type': 'zone', 'value': '<nav>', 'id': 'z1'},
          ],
          [
            {'type': 'zone', 'value': '</nav>', 'id': 'z2'},
          ],
        ],
        'zoneHintIds': ['z1', 'z2'],
        'zoneMultiple': false,
      });

      expect(question.isZone, isTrue);
      expect(question.isZones, isTrue);
      expect(question.isImageSupport, isFalse);
      expect(question.zoneLines, hasLength(3));
      expect(question.zoneIds, ['z1', 'z2']);
      expect(question.zoneHintIds, ['z1', 'z2']);
    });

    test('parses a Légende question with image zones and choices', () {
      final question = QuizQuestion.fromJson({
        'type': 'legende',
        'label': 'Placez.',
        'answers': [],
        'zoneKind': 'image',
        'imageZones': [
          {'id': 'a', 'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.1},
        ],
        'zoneChoices': [
          {'key': 'a', 'text': 'Cratère'},
          {'key': 'd0', 'text': 'Nappe phréatique'},
        ],
      });

      expect(question.isLegende, isTrue);
      expect(question.isImageSupport, isTrue);
      expect(question.zoneIds, ['a']);
      expect(question.zoneChoices.map((c) => c.key), ['a', 'd0']);
    });
  });

  group('QuizCorrectionEntry zone payload', () {
    test('reads a Zone answer (zoneResponses as a list)', () {
      final entry = QuizCorrectionEntry.fromJson({
        'type': 'zone',
        'zoneResponses': ['z1'],
        'zoneCorrectIds': ['z2'],
        'zoneFeedback': {'z1': 'Ouvrante.'},
      });

      expect(entry.zoneClicked, ['z1']);
      expect(entry.zonePlacements, isEmpty);
      expect(entry.zoneFeedback['z1'], 'Ouvrante.');
    });

    test('reads a Légende answer (zoneResponses as a map)', () {
      final entry = QuizCorrectionEntry.fromJson({
        'type': 'legende',
        'zoneResponses': {'s': 's', 'p': 'd0'},
        'zoneResults': {'s': true, 'p': false},
        'zoneLabels': {'p': 'Propriété'},
      });

      expect(entry.zonePlacements, {'s': 's', 'p': 'd0'});
      expect(entry.zoneResults, {'s': true, 'p': false});
    });

    test('tolerates the empty-array shape PHP gives an empty map', () {
      // An unanswered question stores [], whatever the type - both readings must accept it.
      final entry = QuizCorrectionEntry.fromJson({
        'type': 'legende',
        'zoneResponses': <dynamic>[],
        'zoneResults': <dynamic>[],
      });

      expect(entry.zonePlacements, isEmpty);
      expect(entry.zoneResults, isEmpty);
    });
  });

  group('QuizZoneSupport', () {
    testWidgets('reports taps by zone id and paints states', (tester) async {
      final taps = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuizZoneSupport(
            kind: 'code',
            lines: const [
              [
                QuizZoneSegment(isZone: true, text: '<nav>', id: 'z1'),
                QuizZoneSegment(isZone: false, text: 'Accueil', id: ''),
                QuizZoneSegment(isZone: true, text: '</nav>', id: 'z2'),
              ],
            ],
            imageZones: const [],
            imageUrl: null,
            stateOf: (id) => id == 'z1' ? ZoneVisualState.selected : ZoneVisualState.none,
            onZoneTap: taps.add,
          ),
        ),
      ));

      expect(find.text('<nav>'), findsOneWidget);
      await tester.tap(find.text('</nav>'));
      expect(taps, ['z2']);
    });

    testWidgets('shows the placed label on a légende zone', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuizZoneSupport(
            kind: 'texte',
            lines: const [
              [QuizZoneSegment(isZone: true, text: 'chat', id: 's')],
            ],
            imageZones: const [],
            imageUrl: null,
            stateOf: (_) => ZoneVisualState.none,
            placedTextOf: (id) => id == 's' ? 'Sujet' : null,
          ),
        ),
      ));

      expect(find.text('Sujet'), findsOneWidget);
    });
  });
}
