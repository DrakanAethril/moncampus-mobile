import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/quiz_live_state.dart';

void main() {
  test('a numeric question carries its slider and unit', () {
    final state = QuizLiveState.fromJson({
      'type': 'question-opened',
      'questionIndex': 7,
      'totalQuestions': 8,
      'kind': 'number',
      'isVote': false,
      'secondsPerQuestion': 20,
      'phaseStartedAt': '2026-11-05T14:00:00+01:00',
      'answers': <dynamic>[],
      'range': {'min': 0, 'max': 4000.0, 'step': 1},
      'unit': '€',
      'answered': true,
    });

    expect(state.kind, 'number');
    expect(state.range!.max, 4000);
    expect(state.range!.step, 1);
    expect(state.unit, '€');
    expect(state.answered, isTrue);
  });

  test('results give each participant their own verdict', () {
    final state = QuizLiveState.fromJson({
      'type': 'results',
      'questionIndex': 0,
      'totalQuestions': 3,
      'kind': 'multi',
      'isVote': false,
      'outcomes': {
        '12': {'answered': true, 'correct': true, 'points': 874},
        '13': {'answered': false, 'correct': false, 'points': 0},
      },
      'leaderboard': [
        {'participantId': 12, 'displayName': 'Léa', 'score': 874, 'rank': 1},
      ],
      'isLastQuestion': false,
    });

    expect(state.outcomes!['12']!.correct, isTrue);
    expect(state.outcomes!['12']!.points, 874);
    expect(state.outcomes!['13']!.answered, isFalse);
  });

  test('a vote is neither right nor wrong, and no outcome yet comes as an empty list', () {
    final vote = QuizLiveState.fromJson({
      'type': 'results',
      'isVote': true,
      'outcomes': {
        '4': {'answered': true, 'correct': null, 'points': 0},
      },
    });
    final empty = QuizLiveState.fromJson({'type': 'results', 'outcomes': <dynamic>[]});

    expect(vote.outcomes!['4']!.correct, isNull);
    expect(empty.outcomes, isNull);
  });
}
