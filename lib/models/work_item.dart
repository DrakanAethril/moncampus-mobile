/// Where one travail stands for the student - mirrors App\Enum\StudentWorkState, restricted to the
/// three states the mobile list draws (design_handoff_mobile 4b: EN RETARD / À FAIRE, a handed-in
/// row staying in place with its green "Rendu" tag).
enum WorkState {
  todo,
  late,
  submitted;

  static WorkState parse(String? value) => switch (value) {
        'late' => WorkState.late,
        'submitted' => WorkState.submitted,
        _ => WorkState.todo,
      };
}

/// What the row's right-hand side offers. A quiz and a reading are actionable on mobile; a deposit
/// is not - it opens the consultation sheet, which carries the "Dépôt sur le web" pill (handoff,
/// principe 3). A listening opens the same sheet, but onto its player: the phone is where listening
/// happens most naturally, and its tracking has to work there too
/// (design_handoff_enregistrements_audio).
enum WorkAction {
  quiz,
  read,
  listen,
  open;

  static WorkAction parse(String? value) => switch (value) {
        'quiz' => WorkAction.quiz,
        'read' => WorkAction.read,
        'listen' => WorkAction.listen,
        _ => WorkAction.open,
      };
}

/// One row of the student's travaux - GET /api/student-work (App\Controller\Api\WorkController).
class WorkItem {
  const WorkItem({
    required this.id,
    required this.title,
    required this.state,
    required this.dueDate,
    required this.action,
    this.nature = '',
    this.subject,
    this.subjectId,
    this.teacher,
    this.quizInstanceId,
    this.surveyCampaignId,
    this.questionCount,
    this.minimumScorePercent,
    this.readingUrl,
    this.expectationCount = 0,
  });

  factory WorkItem.fromJson(Map<String, dynamic> json) => WorkItem(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        state: WorkState.parse(json['state'] as String?),
        dueDate: DateTime.parse(json['dueDate'] as String).toLocal(),
        action: WorkAction.parse(json['action'] as String?),
        nature: json['nature'] as String? ?? '',
        subject: json['subject'] as String?,
        subjectId: json['subjectId'] as int?,
        teacher: json['teacher'] as String?,
        quizInstanceId: json['quizInstanceId'] as int?,
        surveyCampaignId: json['surveyCampaignId'] as int?,
        questionCount: json['questionCount'] as int?,
        minimumScorePercent: (json['minimumScorePercent'] as num?)?.toDouble(),
        readingUrl: json['readingUrl'] as String?,
        expectationCount: json['expectationCount'] as int? ?? 0,
      );

  final int id;
  final String title;
  final WorkState state;
  final DateTime dueDate;
  final WorkAction action;

  /// App\Enum\AssignmentNature's value, as TeacherWorkItem already carries it. Read for the one
  /// nature the phone cannot finish yet: a survey, whose sheet says where it is answered instead.
  final String nature;
  final String? subject;
  final int? subjectId;
  final String? teacher;
  final int? quizInstanceId;

  /// The survey campaign a Survey work asks to answer - the counterpart of [quizInstanceId], and
  /// what the detail sheet opens the passation with.
  final int? surveyCampaignId;
  final int? questionCount;
  final double? minimumScorePercent;
  final String? readingUrl;
  final int expectationCount;

  /// "Cybersécurité — M. Sautour · 10 questions" - the row's second line (4b). Only what the model
  /// actually holds ends up there; nothing is padded with helper text (handoff, principe 2).
  String get metaLine {
    final head = [
      if (subject != null && subject!.isNotEmpty) subject!,
      if (teacher != null && teacher!.isNotEmpty) teacher!,
    ].join(' — ');

    final details = <String>[
      if (questionCount != null) '$questionCount questions',
      if (minimumScorePercent != null)
        'objectif ${_formatPercent(minimumScorePercent!)} %',
    ];

    return [if (head.isNotEmpty) head, ...details].join(' · ');
  }

  static String _formatPercent(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceAll('.', ',');
}

/// The full travail behind a row - GET /api/student-work/{id}, drawn in the consultation sheet 4c.
class WorkDetail {
  const WorkDetail({
    required this.item,
    required this.expectations,
    required this.attachments,
    required this.audioFiles,
    required this.videoFiles,
    this.description,
    this.givenAt,
  });

  factory WorkDetail.fromJson(Map<String, dynamic> json) => WorkDetail(
        item: WorkItem.fromJson(json),
        description: json['description'] as String?,
        givenAt: json['givenAt'] != null
            ? DateTime.parse(json['givenAt'] as String).toLocal()
            : null,
        expectations: (json['expectations'] as List<dynamic>? ?? const [])
            .map((e) => WorkExpectation.fromJson(e as Map<String, dynamic>))
            .toList(),
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .map((e) => WorkAttachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        audioFiles: (json['audioFiles'] as List<dynamic>? ?? const [])
            .map((e) => WorkAudioFile.fromJson(e as Map<String, dynamic>))
            .toList(),
        videoFiles: (json['videoFiles'] as List<dynamic>? ?? const [])
            .map((e) => WorkVideoFile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final WorkItem item;
  final String? description;
  final DateTime? givenAt;
  final List<WorkExpectation> expectations;
  final List<WorkAttachment> attachments;

  /// The files of a Listening travail: the common ones and this student's own. Empty for every
  /// other nature.
  final List<WorkAudioFile> audioFiles;

  /// The files to watch. Empty for anything but a Watching travail.
  final List<WorkVideoFile> videoFiles;
}

/// One audio file to listen to, with how much of it has already been heard.
///
/// [percent] is the furthest point ever reached, not the position of the last playback - the server
/// keeps a maximum (App\Entity\AudioListenProgress) and the player resumes crediting from it. The
/// travail counts as done once every one of these files is at 100.
class WorkAudioFile {
  const WorkAudioFile({
    required this.id,
    required this.name,
    required this.duration,
    required this.percent,
    required this.url,
  });

  factory WorkAudioFile.fromJson(Map<String, dynamic> json) => WorkAudioFile(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        duration: json['duration'] as String? ?? '',
        percent: json['percent'] as int? ?? 0,
        url: json['url'] as String? ?? '',
      );

  final int id;
  final String name;
  final String duration;
  final int percent;
  final String url;
}

/// One line of "Dépôts demandés" (4c).
class WorkExpectation {
  const WorkExpectation({
    required this.name,
    required this.submitted,
    required this.constraints,
    this.fileName,
    this.submittedAt,
    this.dueDate,
  });

  factory WorkExpectation.fromJson(Map<String, dynamic> json) =>
      WorkExpectation(
        name: json['name'] as String? ?? '',
        submitted: json['submitted'] as bool? ?? false,
        constraints: json['constraints'] as String? ?? '',
        fileName: json['fileName'] as String?,
        submittedAt: json['submittedAt'] != null
            ? DateTime.parse(json['submittedAt'] as String).toLocal()
            : null,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String).toLocal()
            : null,
      );

  final String name;
  final bool submitted;

  /// "PDF · 10 Mo max" - format and size, composed server-side so the wording matches the web.
  final String constraints;
  final String? fileName;
  final DateTime? submittedAt;
  final DateTime? dueDate;
}

/// A support the teacher attached to the travail - a file to download or a link to follow.
class WorkAttachment {
  const WorkAttachment({required this.label, required this.kind, this.url});

  factory WorkAttachment.fromJson(Map<String, dynamic> json) => WorkAttachment(
        label: json['label'] as String? ?? '',
        kind: json['kind'] as String? ?? 'FICHIER',
        url: json['url'] as String?,
      );

  final String label;

  /// Drawn in the row's 32px tile: "PDF", "PNG", "LIEN"…
  final String kind;
  final String? url;
}

/// A subject of the "Toutes les matières" filter (4b header).
class WorkSubject {
  const WorkSubject({required this.id, required this.name});

  factory WorkSubject.fromJson(Map<String, dynamic> json) => WorkSubject(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );

  final int id;
  final String name;
}

/// The student's whole board: the rows, plus what the header filter offers.
class WorkBoard {
  const WorkBoard({
    required this.items,
    required this.subjects,
    this.displayName,
  });

  factory WorkBoard.fromJson(Map<String, dynamic> json) => WorkBoard(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => WorkItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subjects: (json['subjects'] as List<dynamic>? ?? const [])
            .map((e) => WorkSubject.fromJson(e as Map<String, dynamic>))
            .toList(),
        displayName: json['displayName'] as String?,
      );

  final List<WorkItem> items;
  final List<WorkSubject> subjects;

  /// The student's first name, for the home greeting ("Bonjour Léa", 4a).
  final String? displayName;

  List<WorkItem> get late =>
      items.where((item) => item.state == WorkState.late).toList();

  List<WorkItem> get todo =>
      items.where((item) => item.state != WorkState.late).toList();
}

/// One travail on the teacher's list (4d) - GET /api/teacher-work.
class TeacherWorkItem {
  const TeacherWorkItem({
    required this.id,
    required this.title,
    required this.nature,
    required this.natureLabel,
    required this.progress,
    this.programName,
    this.programId,
    this.dueDate,
  });

  factory TeacherWorkItem.fromJson(Map<String, dynamic> json) =>
      TeacherWorkItem(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        nature: json['nature'] as String? ?? '',
        natureLabel: json['natureLabel'] as String? ?? '',
        programName: json['programName'] as String?,
        programId: json['programId'] as int?,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String).toLocal()
            : null,
        progress: WorkProgress.fromJson(
            json['progress'] as Map<String, dynamic>? ?? const {}),
      );

  final int id;
  final String title;

  /// App\Enum\AssignmentNature's value - decides how the counter reads ("rendus" for a deposit,
  /// "passages" for a quiz, "lectures" for a reading).
  final String nature;
  final String natureLabel;
  final String? programName;
  final int? programId;
  final DateTime? dueDate;
  final WorkProgress progress;
}

/// The bar and its counter on a teacher row: how far the class has got, and - once the deadline is
/// past - how many are still missing, which is what turns the bar red (4d).
class WorkProgress {
  const WorkProgress({
    required this.done,
    this.total,
    this.missing,
    this.alert = false,
    this.hidden = false,
  });

  factory WorkProgress.fromJson(Map<String, dynamic> json) => WorkProgress(
        done: json['done'] as int? ?? 0,
        total: json['total'] as int?,
        missing: json['missing'] as int?,
        alert: json['alert'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
      );

  final int done;
  final int? total;
  final int? missing;
  final bool alert;

  /// The travail is not published yet - nobody has seen it, so there is no progress to show.
  final bool hidden;

  double get ratio {
    if (total == null || total == 0) return 0;
    return (done / total!).clamp(0, 1).toDouble();
  }
}

/// One video file to watch, with how much of it has already been seen.
///
/// The same reading as [WorkAudioFile]: [percent] is the furthest point ever reached, not where the
/// last playback stopped. The server keeps a maximum (App\Entity\VideoWatchProgress) and the
/// player resumes crediting from it, so a student who watched half yesterday does not have to
/// replay the whole thing in one go.
class WorkVideoFile {
  const WorkVideoFile({
    required this.id,
    required this.name,
    required this.duration,
    required this.durationSeconds,
    required this.percent,
    required this.url,
  });

  factory WorkVideoFile.fromJson(Map<String, dynamic> json) => WorkVideoFile(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        duration: json['duration'] as String? ?? '',
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
        percent: json['percent'] as int? ?? 0,
        url: json['url'] as String? ?? '',
      );

  final int id;
  final String name;
  final String duration;

  /// Read by the browser on upload, not by a server-side probe - it only draws a bar and places
  /// the cue markers on a timeline.
  final double durationSeconds;

  final int percent;
  final String url;
}
