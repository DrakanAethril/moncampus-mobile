/// One answer slot as sent to a player (shape/color only, never a label - see
/// QuizLiveSessionService's class docblock on the backend for why: the question/answer text stays
/// projector-only, this is a confirmed product decision, not a missing feature).
class QuizLiveAnswerOption {
  const QuizLiveAnswerOption({
    required this.answerId,
    required this.shapeIndex,
    required this.shape,
    required this.color,
  });

  factory QuizLiveAnswerOption.fromJson(Map<String, dynamic> json) => QuizLiveAnswerOption(
        answerId: json['answerId'] as int,
        shapeIndex: json['shapeIndex'] as int,
        shape: json['shape'] as String,
        color: json['color'] as String,
      );

  final int answerId;
  final int shapeIndex;
  final String shape;
  final String color;
}

class QuizLiveLeaderboardEntry {
  const QuizLiveLeaderboardEntry({
    required this.participantId,
    required this.displayName,
    required this.score,
    required this.rank,
  });

  factory QuizLiveLeaderboardEntry.fromJson(Map<String, dynamic> json) => QuizLiveLeaderboardEntry(
        participantId: json['participantId'] as int,
        displayName: json['displayName'] as String,
        score: json['score'] as int,
        rank: json['rank'] as int,
      );

  final int participantId;
  final String displayName;
  final int score;
  final int rank;
}

/// One envelope shape covers every phase (lobby/countdown-started/question-opened/reveal/
/// session-finished/session-cancelled), discriminated by [type] - mirrors the JSON payloads
/// App\Service\QuizLiveSessionService publishes over Mercure (and the same shape
/// Api\QuizLiveController returns for the initial join()/state() snapshot), and the same
/// switch-on-type dispatch as assets/controllers/quiz_live_play_controller.js on the web side.
/// Fields irrelevant to the current [type] are simply null - simpler than a sealed-class
/// hierarchy for a payload this small and this centrally consumed (one screen, one switch).
class QuizLiveState {
  const QuizLiveState({
    required this.type,
    this.participantCount,
    this.countdownSeconds,
    this.serverTime,
    this.questionIndex,
    this.totalQuestions,
    this.secondsPerQuestion,
    this.phaseStartedAt,
    this.answers,
    this.correctShapeIndex,
    this.leaderboard,
    this.isLastQuestion,
    this.finalLeaderboard,
    this.podium,
  });

  factory QuizLiveState.fromJson(Map<String, dynamic> json) => QuizLiveState(
        type: json['type'] as String,
        participantCount: json['participantCount'] as int?,
        countdownSeconds: json['countdownSeconds'] as int?,
        serverTime: json['serverTime'] != null ? DateTime.parse(json['serverTime'] as String) : null,
        questionIndex: json['questionIndex'] as int?,
        totalQuestions: json['totalQuestions'] as int?,
        secondsPerQuestion: json['secondsPerQuestion'] as int?,
        phaseStartedAt: json['phaseStartedAt'] != null ? DateTime.parse(json['phaseStartedAt'] as String) : null,
        answers: (json['answers'] as List<dynamic>?)
            ?.map((a) => QuizLiveAnswerOption.fromJson(a as Map<String, dynamic>))
            .toList(),
        correctShapeIndex: json['correctShapeIndex'] as int?,
        leaderboard: (json['leaderboard'] as List<dynamic>?)
            ?.map((e) => QuizLiveLeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        isLastQuestion: json['isLastQuestion'] as bool?,
        finalLeaderboard: (json['finalLeaderboard'] as List<dynamic>?)
            ?.map((e) => QuizLiveLeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        podium: (json['podium'] as List<dynamic>?)
            ?.map((e) => QuizLiveLeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String type;
  final int? participantCount;
  final int? countdownSeconds;
  final DateTime? serverTime;
  final int? questionIndex;
  final int? totalQuestions;
  final int? secondsPerQuestion;
  final DateTime? phaseStartedAt;
  final List<QuizLiveAnswerOption>? answers;
  final int? correctShapeIndex;
  final List<QuizLiveLeaderboardEntry>? leaderboard;
  final bool? isLastQuestion;
  final List<QuizLiveLeaderboardEntry>? finalLeaderboard;
  final List<QuizLiveLeaderboardEntry>? podium;
}

/// GET /api/quiz-live/active's summary shape - just enough to render the Home screen's banner.
class QuizLiveActiveSession {
  const QuizLiveActiveSession({
    required this.sessionId,
    required this.name,
    required this.programId,
    required this.hostName,
  });

  factory QuizLiveActiveSession.fromJson(Map<String, dynamic> json) => QuizLiveActiveSession(
        sessionId: json['sessionId'] as int,
        name: json['name'] as String,
        programId: json['programId'] as int,
        hostName: json['hostName'] as String,
      );

  final int sessionId;
  final String name;
  final int programId;
  final String hostName;
}

/// Shared response shape of both POST /join and GET /state - everything a client needs to open
/// (or resume) its SSE subscription plus the current phase snapshot.
class QuizLiveConnection {
  const QuizLiveConnection({
    required this.participantId,
    required this.mercurePublicUrl,
    required this.mercureToken,
    required this.playersTopic,
    required this.state,
  });

  factory QuizLiveConnection.fromJson(Map<String, dynamic> json) => QuizLiveConnection(
        participantId: json['participantId'] as int?,
        mercurePublicUrl: json['mercurePublicUrl'] as String,
        mercureToken: json['mercureToken'] as String,
        playersTopic: json['playersTopic'] as String,
        state: QuizLiveState.fromJson(json['state'] as Map<String, dynamic>),
      );

  final int? participantId;
  final String mercurePublicUrl;
  final String mercureToken;
  final String playersTopic;
  final QuizLiveState state;
}
