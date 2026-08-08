/// Models for the student's individual quiz flow (Api\QuizController) - screen 1k of the web app's
/// design/design_handoff_quiz handoff and the passation that follows it.
///
/// The live multiplayer contest has its own models in quiz_live_state.dart: it is a synchronized
/// server-driven state machine, whereas everything here is paced by the student.
library;

class QuizProgram {
  const QuizProgram({required this.id, required this.name});

  final int id;
  final String name;

  factory QuizProgram.fromJson(Map<String, dynamic> json) =>
      QuizProgram(id: json['id'] as int, name: json['name'] as String);
}

/// One "Évaluations" row - a graded quiz with a single attempt.
class QuizEvaluation {
  const QuizEvaluation({
    required this.instanceId,
    required this.name,
    required this.questionCount,
    required this.secondsPerQuestion,
    required this.globalTimeMinutes,
    required this.closesAt,
    required this.openNow,
    required this.inProgress,
    required this.done,
    required this.scorePercent,
  });

  final int instanceId;
  final String name;
  final int questionCount;
  final int? secondsPerQuestion;
  final int? globalTimeMinutes;
  final DateTime? closesAt;
  final bool openNow;
  final bool inProgress;
  final bool done;

  /// Null either because the attempt is not finished or because the teacher has not published the
  /// score yet ("copie remise") - the UI shows "Fait" without a number in both cases.
  final double? scorePercent;

  factory QuizEvaluation.fromJson(Map<String, dynamic> json) => QuizEvaluation(
        instanceId: json['instanceId'] as int,
        name: json['name'] as String,
        questionCount: json['questionCount'] as int? ?? 0,
        secondsPerQuestion: json['secondsPerQuestion'] as int?,
        globalTimeMinutes: json['globalTimeMinutes'] as int?,
        closesAt: json['closesAt'] != null ? DateTime.tryParse(json['closesAt'] as String) : null,
        openNow: json['openNow'] as bool? ?? false,
        inProgress: json['inProgress'] as bool? ?? false,
        done: json['done'] as bool? ?? false,
        scorePercent: (json['scorePercent'] as num?)?.toDouble(),
      );
}

/// One "Entraînement libre" row - unlimited attempts, a fresh draw each time.
class QuizPractice {
  const QuizPractice({
    required this.instanceId,
    required this.name,
    required this.questionCount,
    required this.secondsPerQuestion,
    required this.openNow,
    required this.inProgress,
    required this.attemptCount,
    required this.bestScorePercent,
    required this.lastScorePercent,
  });

  final int instanceId;
  final String name;
  final int questionCount;
  final int? secondsPerQuestion;
  final bool openNow;
  final bool inProgress;
  final int attemptCount;
  final double? bestScorePercent;
  final double? lastScorePercent;

  factory QuizPractice.fromJson(Map<String, dynamic> json) => QuizPractice(
        instanceId: json['instanceId'] as int,
        name: json['name'] as String,
        questionCount: json['questionCount'] as int? ?? 0,
        secondsPerQuestion: json['secondsPerQuestion'] as int?,
        openNow: json['openNow'] as bool? ?? false,
        inProgress: json['inProgress'] as bool? ?? false,
        attemptCount: json['attemptCount'] as int? ?? 0,
        bestScorePercent: (json['bestScorePercent'] as num?)?.toDouble(),
        lastScorePercent: (json['lastScorePercent'] as num?)?.toDouble(),
      );
}

class QuizHub {
  const QuizHub({
    required this.program,
    required this.liveSessionId,
    required this.liveSessionName,
    required this.liveSessionHost,
    required this.liveParticipantCount,
    required this.evaluations,
    required this.practice,
  });

  final QuizProgram? program;
  final int? liveSessionId;
  final String? liveSessionName;
  final String? liveSessionHost;
  final int liveParticipantCount;
  final List<QuizEvaluation> evaluations;
  final List<QuizPractice> practice;

  bool get hasLiveSession => liveSessionId != null;

  factory QuizHub.fromJson(Map<String, dynamic> json) {
    final live = json['liveSession'] as Map<String, dynamic>?;

    return QuizHub(
      program: json['program'] != null ? QuizProgram.fromJson(json['program'] as Map<String, dynamic>) : null,
      liveSessionId: live?['sessionId'] as int?,
      liveSessionName: live?['name'] as String?,
      liveSessionHost: live?['hostName'] as String?,
      liveParticipantCount: live?['participantCount'] as int? ?? 0,
      evaluations: (json['evaluations'] as List<dynamic>? ?? [])
          .map((e) => QuizEvaluation.fromJson(e as Map<String, dynamic>))
          .toList(),
      practice: (json['practice'] as List<dynamic>? ?? [])
          .map((e) => QuizPractice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizAnswerOption {
  const QuizAnswerOption({required this.id, required this.label});

  final int id;
  final String label;

  factory QuizAnswerOption.fromJson(Map<String, dynamic> json) =>
      QuizAnswerOption(id: json['id'] as int, label: json['label'] as String);
}

/// One piece of a "texte à trous" statement: either literal text or a blank to fill.
///
/// The server sends the statement pre-split rather than raw, so the app never re-implements the
/// "..." parsing rules (App\Util\BlankTextParser) - if it did, the app and the grader could
/// disagree on how many blanks a question has.
class QuizBlankSegment {
  const QuizBlankSegment({required this.isBlank, required this.text, required this.index});

  final bool isBlank;
  final String text;

  /// 0-based blank number in text order; -1 for a text segment.
  final int index;

  factory QuizBlankSegment.fromJson(Map<String, dynamic> json) => QuizBlankSegment(
        isBlank: json['type'] == 'blank',
        text: json['value'] as String? ?? '',
        index: json['index'] as int? ?? -1,
      );
}

class QuizQuestion {
  const QuizQuestion({
    required this.type,
    required this.label,
    required this.imageUrl,
    required this.answers,
    required this.blankMode,
    required this.blankSegments,
    required this.wordBank,
  });

  /// 'qcm' | 'qcm_multi' | 'vrai_faux' | 'image' | 'ordre' | 'texte_a_trous'.
  final String type;
  final String label;
  final String? imageUrl;
  final List<QuizAnswerOption> answers;

  /// 'banque' | 'libre', null unless [type] is 'texte_a_trous'.
  final String? blankMode;
  final List<QuizBlankSegment> blankSegments;
  final List<String> wordBank;

  bool get isBlanks => type == 'texte_a_trous';
  bool get isMulti => type == 'qcm_multi';
  bool get isOrder => type == 'ordre';
  bool get isWordBank => blankMode == 'banque';

  int get blankCount => blankSegments.where((s) => s.isBlank).length;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        type: json['type'] as String,
        label: json['label'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        answers: (json['answers'] as List<dynamic>? ?? [])
            .map((e) => QuizAnswerOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        blankMode: json['blankMode'] as String?,
        blankSegments: (json['blankSegments'] as List<dynamic>? ?? [])
            .map((e) => QuizBlankSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        wordBank: (json['wordBank'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      );
}

class QuizQuestionPage {
  const QuizQuestionPage({
    required this.concluded,
    required this.attemptId,
    required this.quizName,
    required this.mode,
    required this.position,
    required this.total,
    required this.secondsForQuestion,
    required this.deadline,
    required this.question,
  });

  final bool concluded;
  final int attemptId;
  final String quizName;
  final String mode;
  final int position;
  final int total;

  /// Seconds allowed for THIS question - the quiz's default unless the question overrides it or
  /// lifts the limit for itself. Null means no countdown at all.
  final int? secondsForQuestion;

  /// Wall-clock instant the whole attempt expires (global timer or closing date, whichever comes
  /// first). Absent when the quiz has neither.
  final DateTime? deadline;
  final QuizQuestion? question;

  factory QuizQuestionPage.fromJson(Map<String, dynamic> json) => QuizQuestionPage(
        concluded: json['concluded'] as bool? ?? false,
        attemptId: json['attemptId'] as int,
        quizName: json['quizName'] as String? ?? '',
        mode: json['mode'] as String? ?? '',
        position: json['position'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
        // Older servers only send secondsPerQuestion, which was the quiz-wide value; falling back
        // on it keeps this build working against one of those.
        secondsForQuestion: json['secondsForQuestion'] as int? ?? json['secondsPerQuestion'] as int?,
        deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'] as String) : null,
        question: json['question'] != null ? QuizQuestion.fromJson(json['question'] as Map<String, dynamic>) : null,
      );
}

class QuizCorrectionAnswer {
  const QuizCorrectionAnswer({required this.label, required this.correct, required this.selected});

  final String label;
  final bool correct;
  final bool selected;

  factory QuizCorrectionAnswer.fromJson(Map<String, dynamic> json) => QuizCorrectionAnswer(
        label: json['label'] as String,
        correct: json['correct'] as bool? ?? false,
        selected: json['selected'] as bool? ?? false,
      );
}

class QuizCorrectionEntry {
  const QuizCorrectionEntry({
    required this.label,
    required this.type,
    required this.isCorrect,
    required this.explanation,
    required this.answers,
    required this.blankResponses,
    required this.blankResults,
    required this.blankExpected,
  });

  final String label;
  final String type;
  final bool isCorrect;
  final String? explanation;
  final List<QuizCorrectionAnswer> answers;
  final List<String> blankResponses;
  final List<bool> blankResults;
  final List<List<String>> blankExpected;

  bool get isBlanks => type == 'texte_a_trous';

  factory QuizCorrectionEntry.fromJson(Map<String, dynamic> json) => QuizCorrectionEntry(
        label: json['label'] as String? ?? '',
        type: json['type'] as String? ?? '',
        isCorrect: json['isCorrect'] as bool? ?? false,
        explanation: json['explanation'] as String?,
        answers: (json['answers'] as List<dynamic>? ?? [])
            .map((e) => QuizCorrectionAnswer.fromJson(e as Map<String, dynamic>))
            .toList(),
        blankResponses: (json['blankResponses'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        blankResults: (json['blankResults'] as List<dynamic>? ?? []).map((e) => e as bool).toList(),
        blankExpected: (json['blankExpected'] as List<dynamic>? ?? [])
            .map((e) => (e as List<dynamic>).map((v) => v as String).toList())
            .toList(),
      );
}

class QuizResult {
  const QuizResult({
    required this.quizName,
    required this.mode,
    required this.scoreVisible,
    required this.score,
    required this.questionTotal,
    required this.scorePercent,
    required this.scoreOn20,
    required this.correction,
  });

  final String quizName;
  final String mode;

  /// False for an évaluation whose teacher has not published the score: the student sees
  /// "copie remise" instead of a number.
  final bool scoreVisible;
  final String? score;
  final int? questionTotal;
  final double? scorePercent;
  final double? scoreOn20;

  /// Only ever filled in entraînement - the correction is that mode's whole point.
  final List<QuizCorrectionEntry> correction;

  bool get isPractice => mode == 'entrainement';

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        quizName: json['quizName'] as String? ?? '',
        mode: json['mode'] as String? ?? '',
        scoreVisible: json['scoreVisible'] as bool? ?? false,
        score: json['score'] as String?,
        questionTotal: json['questionTotal'] as int?,
        scorePercent: (json['scorePercent'] as num?)?.toDouble(),
        scoreOn20: (json['scoreOn20'] as num?)?.toDouble(),
        correction: (json['correction'] as List<dynamic>? ?? [])
            .map((e) => QuizCorrectionEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
