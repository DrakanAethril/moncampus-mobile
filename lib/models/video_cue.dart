/// The interactive video (créas 5B), as Api\VideoCueController sends it.
///
/// The statement itself is a plain [QuizQuestion] - the very class the quiz passation parses,
/// because the server describes both through one object (App\Service\QuizQuestionPayload). That is
/// what makes the twelve types playable inside a video without a second implementation of any of
/// them.
library;

import 'quiz.dart';

/// Where a marker sits on the timeline, and whether this student has already answered it.
///
/// The statements are deliberately NOT here: they arrive one at a time, when their minute is
/// reached. A payload carrying all four questions would hand a curious student the whole set before
/// the lecture has explained any of it - and on a client-side app, trivially so.
class VideoCuePoint {
  const VideoCuePoint({
    required this.id,
    required this.fileId,
    required this.timecode,
    required this.pauseVideo,
    required this.blocking,
    required this.replayFrom,
    required this.answered,
  });

  factory VideoCuePoint.fromJson(Map<String, dynamic> json) => VideoCuePoint(
        id: json['id'] as int,
        fileId: json['fileId'] as int?,
        timecode: (json['timecode'] as num?)?.toDouble() ?? 0,
        pauseVideo: json['pauseVideo'] as bool? ?? true,
        blocking: json['blocking'] as bool? ?? false,
        replayFrom: (json['replayFrom'] as num?)?.toDouble(),
        answered: json['answered'] as bool? ?? false,
      );

  final int id;
  final int? fileId;

  /// Seconds into the file.
  final double timecode;

  final bool pauseVideo;

  /// Blocking: the video does not go on until the marker has been answered.
  final bool blocking;

  /// Where "revoir ce passage" rewinds to, in seconds, when the teacher set one.
  final double? replayFrom;

  /// Already answered once. The marker is drawn but never asked again - the answer that counts is
  /// the first one, so a second viewing is a viewing.
  final bool answered;

  Duration get position => Duration(milliseconds: (timecode * 1000).round());
}

/// One marker's statement, fetched when its minute is reached.
class VideoCueQuestion {
  const VideoCueQuestion({
    required this.cueId,
    required this.blocking,
    required this.replayFrom,
    required this.question,
  });

  factory VideoCueQuestion.fromJson(Map<String, dynamic> json) => VideoCueQuestion(
        cueId: json['cueId'] as int,
        blocking: json['blocking'] as bool? ?? false,
        replayFrom: (json['replayFrom'] as num?)?.toDouble(),
        question: QuizQuestion.fromJson(json['question'] as Map<String, dynamic>),
      );

  final int cueId;
  final bool blocking;
  final double? replayFrom;
  final QuizQuestion question;
}

/// What comes back once the marker has been answered.
class VideoCueOutcome {
  const VideoCueOutcome({
    required this.correct,
    required this.recorded,
    required this.explanation,
  });

  factory VideoCueOutcome.fromJson(Map<String, dynamic> json) => VideoCueOutcome(
        correct: json['correct'] as bool? ?? false,
        // False on a second pass: the answer is graded and shown, it simply changes nothing.
        recorded: json['recorded'] as bool? ?? false,
        explanation: json['explanation'] as String?,
      );

  final bool correct;
  final bool recorded;
  final String? explanation;
}
