/// Models for « Mes sondages » (Api\SurveyController).
///
/// Calqués sur quiz.dart, with the same shape of accessors - isMulti / isOrder / isComment - so the
/// widgets of quiz_take_screen.dart can be reused rather than rewritten: the multiple choice and,
/// above all, the drag-to-reorder already exist here and are proven.
///
/// Two things the payload carries that the app must not decide on its own:
///   - `anonymous`, which drives the notice shown before the first question. It is a promise made
///     to the respondent, so it cannot exist on the web and not on the phone.
///   - `questionCount`, which **excludes the « titre » lines**. They are shown - they structure the
///     reading - but they are not questions, and a progress bar counting them would never reach its
///     maximum.
library;

/// One row of « Mes sondages » - a survey still to answer.
class SurveySummary {
  const SurveySummary({
    required this.id,
    required this.name,
    required this.anonymous,
    required this.questionCount,
    required this.closesAt,
  });

  final int id;
  final String name;
  final bool anonymous;
  final int questionCount;
  final DateTime? closesAt;

  factory SurveySummary.fromJson(Map<String, dynamic> json) => SurveySummary(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        anonymous: json['anonymous'] as bool? ?? false,
        questionCount: json['questionCount'] as int? ?? 0,
        closesAt: json['closesAt'] != null
            ? DateTime.tryParse(json['closesAt'] as String)?.toLocal()
            : null,
      );
}

/// One proposed answer. On a question flagged [SurveyQuestion.isScale] its [orderIndex] *is* the
/// scale value, 0 being the low pole - which changes nothing here and everything in the results.
class SurveyAnswer {
  const SurveyAnswer({
    required this.id,
    required this.label,
    required this.orderIndex,
  });

  final int id;
  final String label;
  final int orderIndex;

  factory SurveyAnswer.fromJson(Map<String, dynamic> json) => SurveyAnswer(
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
        orderIndex: json['orderIndex'] as int? ?? 0,
      );
}

/// One line of a survey - a question, a free-text comment, or a section heading.
class SurveyQuestion {
  const SurveyQuestion({
    required this.id,
    required this.type,
    required this.label,
    required this.orderIndex,
    required this.required_,
    required this.isScale,
    required this.answers,
    this.helpText,
    this.minChoices,
    this.maxChoices,
    this.maxLength,
  });

  final int id;

  /// App\Enum\SurveyQuestionType's value: unique / multiple / ordre / commentaire / titre.
  final String type;
  final String label;
  final int orderIndex;
  final bool required_;
  final bool isScale;
  final List<SurveyAnswer> answers;
  final String? helpText;
  final int? minChoices;
  final int? maxChoices;

  /// The comment's cap, sent by the server so the counter shown is the real limit - a silent
  /// truncation is a bug, not a detail.
  final int? maxLength;

  bool get isSingle => type == 'unique';
  bool get isMulti => type == 'multiple';
  bool get isOrder => type == 'ordre';
  bool get isComment => type == 'commentaire';

  /// A section heading is not answered and is never counted - see the library docblock.
  bool get isHeading => type == 'titre';

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) => SurveyQuestion(
        id: json['id'] as int,
        type: json['type'] as String? ?? 'unique',
        label: json['label'] as String? ?? '',
        orderIndex: json['orderIndex'] as int? ?? 0,
        required_: json['required'] as bool? ?? true,
        isScale: json['isScale'] as bool? ?? false,
        helpText: json['helpText'] as String?,
        minChoices: json['minChoices'] as int?,
        maxChoices: json['maxChoices'] as int?,
        maxLength: json['maxLength'] as int?,
        answers: (json['answers'] as List<dynamic>? ?? const [])
            .map((e) => SurveyAnswer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A whole campaign, as the passation reads it.
class Survey {
  const Survey({
    required this.id,
    required this.name,
    required this.anonymous,
    required this.questionCount,
    required this.questions,
    this.description,
    this.closesAt,
  });

  final int id;
  final String name;
  final bool anonymous;

  /// The « titre » lines excluded - the total the progress counter must reach.
  final int questionCount;
  final List<SurveyQuestion> questions;
  final String? description;
  final DateTime? closesAt;

  /// The lines that actually ask something, in order.
  List<SurveyQuestion> get answerableQuestions =>
      questions.where((q) => !q.isHeading).toList();

  factory Survey.fromJson(Map<String, dynamic> json) => Survey(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        anonymous: json['anonymous'] as bool? ?? false,
        description: json['description'] as String?,
        questionCount: json['questionCount'] as int? ?? 0,
        closesAt: json['closesAt'] != null
            ? DateTime.tryParse(json['closesAt'] as String)?.toLocal()
            : null,
        questions: (json['questions'] as List<dynamic>? ?? const [])
            .map((e) => SurveyQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// What one response says about one question, on its way to the server.
///
/// For a ranking question the **position of an id in [answerIds] is the rank** - there is
/// deliberately no separate rank field the client and the server could contradict.
class SurveyAnswerInput {
  const SurveyAnswerInput({required this.questionId, this.answerIds, this.freeText});

  final int questionId;
  final List<int>? answerIds;
  final String? freeText;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        if (answerIds != null) 'answerIds': answerIds,
        if (freeText != null) 'freeText': freeText,
      };
}
