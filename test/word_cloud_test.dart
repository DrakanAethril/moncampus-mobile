import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/word_cloud.dart';

/// What the phone reads off Api\WordCloudController, and the two rules it keeps on its own.
///
/// The rest - the period, the quota, the duplicate - is the server's and is tested there. What
/// belongs here is the reading: « Illimités » travelling as null, and how many boxes that means
/// drawing. Get either wrong and the screen either forbids a word the server would have taken, or
/// offers thirty boxes to somebody entitled to one.
void main() {
  Map<String, dynamic> state({
    int? remainingWords = 3,
    bool canSubmit = true,
    String status = 'open',
    List<dynamic> ownWords = const [],
    List<dynamic>? cloud,
  }) =>
      {
        'id': 7,
        'name': 'Cybersécurité',
        'question': 'Quels mots associez-vous à la cybersécurité ?',
        'programShortName': 'SIO-1',
        'status': status,
        'canSubmit': canSubmit,
        'remainingWords': remainingWords,
        'maxWordsPerAnswer': 1,
        'maxCharacters': 30,
        'closesAt': '2026-09-08T09:15:00+02:00',
        'ownWords': ownWords,
        'cloud': cloud,
      };

  group('WordCloudState', () {
    test('reads the question, the status and what is left to write', () {
      final cloud = WordCloudState.fromJson(state());

      expect(cloud.question, 'Quels mots associez-vous à la cybersécurité ?');
      expect(cloud.status, 'open');
      expect(cloud.canSubmit, isTrue);
      expect(cloud.remainingWords, 3);
      expect(cloud.boxCount, 3);
    });

    /// Null is « Illimités » throughout the tool. It must never be read as "nothing left".
    test('an unlimited cloud has no remaining count and draws a single box', () {
      final cloud = WordCloudState.fromJson(state(remainingWords: null));

      expect(cloud.remainingWords, isNull);
      expect(cloud.boxCount, 1);
    });

    /// A page of boxes is not a word cloud: past six the screen stops adding them.
    test('a very generous quota still draws a readable number of boxes', () {
      expect(WordCloudState.fromJson(state(remainingWords: 20)).boxCount, 6);
    });

    test('nothing left to write draws no box at all', () {
      expect(WordCloudState.fromJson(state(remainingWords: 0, canSubmit: false)).boxCount, 0);
    });

    /// Refused: kept and flagged, so the screen can strike it through rather than lose it.
    test('own words carry their moderation state', () {
      final cloud = WordCloudState.fromJson(state(ownWords: [
        {'text': 'pare-feu', 'rejected': false, 'pending': false},
        {'text': 'darkweb', 'rejected': true, 'pending': false},
        {'text': 'h4ck3r', 'rejected': false, 'pending': true},
      ]));

      expect(cloud.ownWords.map((word) => word.text), ['pare-feu', 'darkweb', 'h4ck3r']);
      expect(cloud.ownWords[1].rejected, isTrue);
      expect(cloud.ownWords[2].pending, isTrue);
    });

    /// Off by default: the key is absent, and that is not an empty cloud but no cloud at all.
    test('no cloud comes back unless the teacher switched it on', () {
      expect(WordCloudState.fromJson(state()).cloud, isNull);
    });

    test('the cloud arrives already weighted', () {
      final cloud = WordCloudState.fromJson(state(cloud: [
        {'word': 'pare-feu', 'count': 6, 'size': 44, 'step': 'top'},
        {'word': 'VPN', 'count': 1, 'size': 27, 'step': 'faint'},
      ]));

      expect(cloud.cloud, hasLength(2));
      expect(cloud.cloud![0].size, 44);
      expect(cloud.cloud![0].step, 'top');
      expect(cloud.cloud![1].step, 'faint');
    });

    test('the status helpers read the three states', () {
      expect(WordCloudState.fromJson(state(status: 'scheduled')).isScheduled, isTrue);
      expect(WordCloudState.fromJson(state(status: 'closed')).isClosed, isTrue);
      expect(WordCloudState.fromJson(state()).isClosed, isFalse);
    });
  });

  group('WordCloudSubmitResult', () {
    /// A refusal is an ordinary answer, not an error: what was taken must survive it.
    test('what was accepted and what was refused arrive together with the new state', () {
      final result = WordCloudSubmitResult.fromJson({
        'accepted': ['pare-feu', 'phishing'],
        'refusals': [
          {
            'word': 'Pare-Feu',
            'reason': 'already_proposed',
            'message': 'Vous avez déjà proposé ce mot.',
          },
        ],
        'state': state(remainingWords: 1),
      });

      expect(result.accepted, ['pare-feu', 'phishing']);
      expect(result.refusals.single.reason, 'already_proposed');
      expect(result.refusals.single.message, 'Vous avez déjà proposé ce mot.');
      expect(result.state.remainingWords, 1);
    });
  });

  group('WordCloudBanner', () {
    test('carries what the home screen draws and nothing else', () {
      final banner = WordCloudBanner.fromJson({
        'id': 7,
        'name': 'Cybersécurité — première impression',
        'question': 'Quels mots associez-vous à la cybersécurité ?',
        'programShortName': 'SIO-1',
      });

      expect(banner.id, 7);
      expect(banner.question, 'Quels mots associez-vous à la cybersécurité ?');
      expect(banner.programShortName, 'SIO-1');
    });
  });
}
