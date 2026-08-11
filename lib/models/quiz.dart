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

/// One piece of a Zone/Légende support line: literal text or a tappable zone.
///
/// Like the blanks, the server sends the support pre-split into lines and segments so the app
/// never re-implements the [[id|texte]] marker parsing (App\Util\ZoneTextParser) and cannot
/// disagree with the grader on which zones exist.
class QuizZoneSegment {
  const QuizZoneSegment({required this.isZone, required this.text, required this.id});

  final bool isZone;
  final String text;

  /// The zone id the answer is expressed in; empty for a text segment.
  final String id;

  factory QuizZoneSegment.fromJson(Map<String, dynamic> json) => QuizZoneSegment(
        isZone: json['type'] == 'zone',
        text: json['value'] as String? ?? '',
        id: json['id'] as String? ?? '',
      );
}

/// A drawn rectangle of an image support, coordinates normalized 0..1 of the displayed image.
class QuizImageZone {
  const QuizImageZone({required this.id, required this.x, required this.y, required this.w, required this.h});

  final String id;
  final double x;
  final double y;
  final double w;
  final double h;

  factory QuizImageZone.fromJson(Map<String, dynamic> json) => QuizImageZone(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        w: (json['w'] as num).toDouble(),
        h: (json['h'] as num).toDouble(),
      );
}

/// One placeable label of a Légende question. The [key] is what gets submitted; a real label's
/// key is its zone id, a distractor carries a synthetic d0/d1/… key that can never match.
class QuizZoneChoice {
  const QuizZoneChoice({required this.key, required this.text});

  final String key;
  final String text;

  factory QuizZoneChoice.fromJson(Map<String, dynamic> json) =>
      QuizZoneChoice(key: json['key'] as String, text: json['text'] as String? ?? '');
}

/// One item a student can place on an Apparier question - the right side of a real pair, or a
/// decoy. [imageUrl] is filled only on an image column, and [text] is then the item's alternative
/// text rather than its content.
class QuizMatchingChoice {
  const QuizMatchingChoice({required this.key, required this.text, required this.imageUrl});

  final String key;
  final String text;
  final String? imageUrl;

  factory QuizMatchingChoice.fromJson(Map<String, dynamic> json) => QuizMatchingChoice(
        key: json['key'] as String,
        text: json['text'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
      );
}

/// One row of an Apparier question. [right]/[rightImageUrl] are null during the passation - that
/// side *is* the answer, and the server only sends it back at correction time.
class QuizMatchingPair {
  const QuizMatchingPair({
    required this.id,
    required this.left,
    required this.leftImageUrl,
    required this.right,
    required this.rightImageUrl,
  });

  final String id;
  final String left;
  final String? leftImageUrl;
  final String? right;
  final String? rightImageUrl;

  bool get hasAnswer => right != null || rightImageUrl != null;

  factory QuizMatchingPair.fromJson(Map<String, dynamic> json) => QuizMatchingPair(
        id: json['id'] as String,
        left: json['left'] as String? ?? '',
        leftImageUrl: json['leftImageUrl'] as String?,
        right: json['right'] as String?,
        rightImageUrl: json['rightImageUrl'] as String?,
      );
}

/// The two column titles of an Apparier question. Empty strings rather than nulls, matching the
/// server: a caller that has to test before printing a header is one that will forget to.
class QuizMatchingHeaders {
  const QuizMatchingHeaders({required this.left, required this.right});

  final String left;
  final String right;

  factory QuizMatchingHeaders.fromJson(dynamic json) => json is Map
      ? QuizMatchingHeaders(left: json['left'] as String? ?? '', right: json['right'] as String? ?? '')
      : const QuizMatchingHeaders(left: '', right: '');
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
    required this.zoneKind,
    required this.zoneLines,
    required this.imageZones,
    required this.zoneChoices,
    required this.zoneHintIds,
    required this.zoneMultiple,
    required this.matchingHeaders,
    required this.matchingPairs,
    required this.matchingChoices,
    required this.numericStatement,
    required this.numericUnit,
    required this.numericUnitRequired,
  });

  /// 'qcm' | 'qcm_multi' | 'vrai_faux' | 'image' | 'ordre' | 'texte_a_trous' | 'zone' | 'legende'
  /// | 'apparier'.
  final String type;
  final String label;
  final String? imageUrl;
  final List<QuizAnswerOption> answers;

  /// 'banque' | 'libre', null unless [type] is 'texte_a_trous'.
  final String? blankMode;
  final List<QuizBlankSegment> blankSegments;
  final List<String> wordBank;

  /// 'texte' | 'code' | 'image', null unless [type] is 'zone' or 'legende'.
  final String? zoneKind;
  final List<List<QuizZoneSegment>> zoneLines;
  final List<QuizImageZone> imageZones;
  final List<QuizZoneChoice> zoneChoices;

  /// Zones left visible when the student asks for the hint - only ever sent in entraînement,
  /// so an empty list also means "no hint button at all".
  final List<String> zoneHintIds;

  /// True when a Zone question expects several zones to be tapped.
  final bool zoneMultiple;

  /// Apparier: the left column already shuffled for this attempt, and the pool of items to place.
  /// Both empty unless [type] is 'apparier'.
  final QuizMatchingHeaders matchingHeaders;
  final List<QuizMatchingPair> matchingPairs;
  final List<QuizMatchingChoice> matchingChoices;

  /// Numérique / Calculée: the statement already rendered with *this* student's drawn values, so
  /// the app never re-implements the {v} substitution the grader owns. Null unless the question is
  /// one of the numeric types.
  final String? numericStatement;

  /// The unit the answer is expressed in, and whether the student has to type it themselves. When
  /// they do not, it is shown beside the field and they type only the number.
  final String? numericUnit;
  final bool numericUnitRequired;

  bool get isBlanks => type == 'texte_a_trous';
  bool get isMulti => type == 'qcm_multi';
  bool get isOrder => type == 'ordre';
  bool get isWordBank => blankMode == 'banque';
  bool get isZone => type == 'zone';
  bool get isLegende => type == 'legende';
  bool get isZones => isZone || isLegende;
  bool get isApparier => type == 'apparier';
  bool get isNumeric => type == 'numerique' || type == 'calculee';
  bool get isImageSupport => zoneKind == 'image';

  int get blankCount => blankSegments.where((s) => s.isBlank).length;

  /// Every zone id the support carries, whatever the kind.
  List<String> get zoneIds => isImageSupport
      ? imageZones.map((z) => z.id).toList()
      : zoneLines.expand((line) => line).where((s) => s.isZone).map((s) => s.id).toSet().toList();

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
        zoneKind: json['zoneKind'] as String?,
        zoneLines: _parseZoneLines(json['zoneLines']),
        imageZones: (json['imageZones'] as List<dynamic>? ?? [])
            .map((e) => QuizImageZone.fromJson(e as Map<String, dynamic>))
            .toList(),
        zoneChoices: (json['zoneChoices'] as List<dynamic>? ?? [])
            .map((e) => QuizZoneChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
        zoneHintIds: (json['zoneHintIds'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        zoneMultiple: json['zoneMultiple'] as bool? ?? false,
        matchingHeaders: QuizMatchingHeaders.fromJson(json['matchingHeaders']),
        matchingPairs: (json['matchingPairs'] as List<dynamic>? ?? [])
            .map((e) => QuizMatchingPair.fromJson(e as Map<String, dynamic>))
            .toList(),
        matchingChoices: (json['matchingChoices'] as List<dynamic>? ?? [])
            .map((e) => QuizMatchingChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
        numericStatement: json['numericStatement'] as String?,
        numericUnit: json['numericUnit'] as String?,
        numericUnitRequired: json['numericUnitRequired'] as bool? ?? false,
      );
}

List<List<QuizZoneSegment>> _parseZoneLines(dynamic raw) => (raw as List<dynamic>? ?? [])
    .map((line) =>
        (line as List<dynamic>).map((e) => QuizZoneSegment.fromJson(e as Map<String, dynamic>)).toList())
    .toList();

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
        // Older servers only send secondsPerQuestion, the quiz-wide value; falling back on it
        // keeps this build working against one of those. Keyed on whether the field is THERE, not
        // on whether it is null - a present null is the whole point of the field, it means this
        // question has no time limit, and `??` would silently put the quiz's limit back.
        secondsForQuestion: json.containsKey('secondsForQuestion')
            ? json['secondsForQuestion'] as int?
            : json['secondsPerQuestion'] as int?,
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
    required this.zoneKind,
    required this.zoneLines,
    required this.imageZones,
    required this.imageUrl,
    required this.zoneClicked,
    required this.zonePlacements,
    required this.zoneCorrectIds,
    required this.zoneResults,
    required this.zoneLabels,
    required this.zoneChoices,
    required this.zoneFeedback,
    required this.matchingHeaders,
    required this.matchingPairs,
    required this.matchingChoices,
    required this.matchingResponses,
    required this.matchingResults,
    required this.matchingFeedback,
    required this.numericStatement,
    required this.numericRaw,
    required this.numericExpected,
    required this.numericMargin,
    required this.numericUnit,
    required this.numericDecimals,
  });

  final String label;
  final String type;
  final bool isCorrect;
  final String? explanation;
  final List<QuizCorrectionAnswer> answers;
  final List<String> blankResponses;
  final List<bool> blankResults;
  final List<List<String>> blankExpected;

  final String? zoneKind;
  final List<List<QuizZoneSegment>> zoneLines;
  final List<QuizImageZone> imageZones;
  final String? imageUrl;

  /// Zone question: the zone ids the student tapped.
  final List<String> zoneClicked;

  /// Légende question: zone id => the choice key the student placed on it.
  final Map<String, String> zonePlacements;

  final List<String> zoneCorrectIds;

  /// Légende: zone id => right/wrong.
  final Map<String, bool> zoneResults;

  /// Légende: zone id => the label that belonged there.
  final Map<String, String> zoneLabels;
  final List<QuizZoneChoice> zoneChoices;

  /// Zone: zone id tapped by mistake => the teacher's "why this one is wrong" text.
  final Map<String, String> zoneFeedback;

  /// Apparier, at correction time - the pairs now carry their right-hand side, which is the answer.
  final QuizMatchingHeaders matchingHeaders;
  final List<QuizMatchingPair> matchingPairs;
  final List<QuizMatchingChoice> matchingChoices;

  /// pair id => the choice key the student placed on it.
  final Map<String, String> matchingResponses;

  /// pair id => right/wrong.
  final Map<String, bool> matchingResults;

  /// pair id the student got wrong => the teacher's "why these two go together" text.
  final Map<String, String> matchingFeedback;

  /// Numérique / Calculée at correction time: the statement as this student read it, what they
  /// typed verbatim, and what was expected of them - the three things a correction lines up.
  final String? numericStatement;
  final String? numericRaw;
  final double? numericExpected;
  final double? numericMargin;
  final String? numericUnit;
  final int numericDecimals;

  bool get isBlanks => type == 'texte_a_trous';
  bool get isZone => type == 'zone';
  bool get isLegende => type == 'legende';
  bool get isZones => isZone || isLegende;
  bool get isApparier => type == 'apparier';
  bool get isNumeric => type == 'numerique' || type == 'calculee';
  bool get isImageSupport => zoneKind == 'image';

  factory QuizCorrectionEntry.fromJson(Map<String, dynamic> json) {
    // zoneResponses mirrors how it was stored: a JSON array of tapped ids for a Zone question, an
    // object of zone => choice for a Légende. An empty PHP array serializes as [] either way, so
    // both readings have to accept both shapes.
    final rawResponses = json['zoneResponses'];
    final zoneClicked = rawResponses is List ? rawResponses.map((e) => e.toString()).toList() : <String>[];
    final zonePlacements = rawResponses is Map
        ? rawResponses.map((k, v) => MapEntry(k.toString(), v.toString()))
        : <String, String>{};

    Map<String, T> mapOf<T>(dynamic raw) =>
        raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v as T)) : <String, T>{};

    return QuizCorrectionEntry(
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
      zoneKind: json['zoneKind'] as String?,
      zoneLines: _parseZoneLines(json['zoneLines']),
      imageZones: (json['imageZones'] as List<dynamic>? ?? [])
          .map((e) => QuizImageZone.fromJson(e as Map<String, dynamic>))
          .toList(),
      imageUrl: json['imageUrl'] as String?,
      zoneClicked: zoneClicked,
      zonePlacements: zonePlacements,
      zoneCorrectIds: (json['zoneCorrectIds'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      zoneResults: mapOf<bool>(json['zoneResults']),
      zoneLabels: mapOf<String>(json['zoneLabels']),
      zoneChoices: (json['zoneChoices'] as List<dynamic>? ?? [])
          .map((e) => QuizZoneChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      zoneFeedback: mapOf<String>(json['zoneFeedback']),
      matchingHeaders: QuizMatchingHeaders.fromJson(json['matchingHeaders']),
      matchingPairs: (json['matchingPairs'] as List<dynamic>? ?? [])
          .map((e) => QuizMatchingPair.fromJson(e as Map<String, dynamic>))
          .toList(),
      matchingChoices: (json['matchingChoices'] as List<dynamic>? ?? [])
          .map((e) => QuizMatchingChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      // An empty PHP array serializes as [] rather than {} - mapOf() already treats anything that
      // is not a Map as empty, which is the same guard zoneResults needs.
      matchingResponses: mapOf<String>(json['matchingResponses']),
      matchingResults: mapOf<bool>(json['matchingResults']),
      matchingFeedback: mapOf<String>(json['matchingFeedback']),
      numericStatement: json['numericStatement'] as String?,
      numericRaw: json['numericRaw'] as String?,
      numericExpected: (json['numericExpected'] as num?)?.toDouble(),
      numericMargin: (json['numericMargin'] as num?)?.toDouble(),
      numericUnit: json['numericUnit'] as String?,
      numericDecimals: json['numericDecimals'] as int? ?? 2,
    );
  }
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
