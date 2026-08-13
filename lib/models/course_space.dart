/// « Mes cours » - the read side of the course space, as Api\CourseSpaceController sends it.
///
/// Three levels, and the app decides nothing about any of them: what is published, what an access
/// condition still holds back, and why, are all answered on the server (CourseSpaceBoard,
/// SequenceInstanceVoter, AccessConditionGate). A locked row arrives *with* its reasons rather than
/// being left out, because a row that vanishes cannot say what would open it.
library;

class CourseProgram {
  const CourseProgram({required this.id, required this.name});

  factory CourseProgram.fromJson(Map<String, dynamic> json) => CourseProgram(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );

  final int id;
  final String name;
}

class CourseSequence {
  const CourseSequence({
    required this.id,
    required this.title,
    required this.seanceCount,
    required this.locked,
    required this.lockedReasons,
  });

  factory CourseSequence.fromJson(Map<String, dynamic> json) => CourseSequence(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        seanceCount: json['seanceCount'] as int? ?? 0,
        locked: json['locked'] as bool? ?? false,
        lockedReasons: _strings(json['lockedReasons']),
      );

  final int id;
  final String title;
  final int seanceCount;

  /// Held by an access condition: the row is shown, greyed, and cannot be opened.
  final bool locked;

  /// What would open it, written by the server - the app never composes these sentences.
  final List<String> lockedReasons;
}

class CourseProgramPage {
  const CourseProgramPage({required this.program, required this.sequences});

  factory CourseProgramPage.fromJson(Map<String, dynamic> json) => CourseProgramPage(
        program: CourseProgram.fromJson(json['program'] as Map<String, dynamic>),
        sequences: [
          for (final row in (json['sequences'] as List<dynamic>? ?? const []))
            CourseSequence.fromJson(row as Map<String, dynamic>),
        ],
      );

  final CourseProgram program;
  final List<CourseSequence> sequences;
}

/// One resource under a séance. The address is deliberately absent: it is fetched one call later,
/// through the opening route, which is also what records that the student actually opened it.
class CourseResource {
  const CourseResource({
    required this.id,
    required this.label,
    required this.type,
    required this.opened,
    required this.locked,
    required this.lockedReasons,
  });

  factory CourseResource.fromJson(Map<String, dynamic> json) => CourseResource(
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
        type: json['type'] as String? ?? 'link',
        opened: json['opened'] as bool? ?? false,
        locked: json['locked'] as bool? ?? false,
        lockedReasons: _strings(json['lockedReasons']),
      );

  final int id;
  final String label;

  /// `upload` or `link` - only used to pick the pictogram.
  final String type;

  /// Already opened once. A read mark, not a permission.
  final bool opened;
  final bool locked;
  final List<String> lockedReasons;

  bool get isUpload => type == 'upload';
}

class CourseSeance {
  const CourseSeance({
    required this.id,
    required this.title,
    required this.order,
    required this.resources,
  });

  factory CourseSeance.fromJson(Map<String, dynamic> json) => CourseSeance(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        order: json['order'] as int? ?? 0,
        resources: [
          for (final row in (json['resources'] as List<dynamic>? ?? const []))
            CourseResource.fromJson(row as Map<String, dynamic>),
        ],
      );

  final int id;
  final String title;
  final int order;
  final List<CourseResource> resources;
}

class CourseSequencePage {
  const CourseSequencePage({required this.title, required this.seances});

  factory CourseSequencePage.fromJson(Map<String, dynamic> json) {
    final sequence = json['sequence'] as Map<String, dynamic>? ?? const {};

    return CourseSequencePage(
      title: sequence['title'] as String? ?? '',
      seances: [
        for (final row in (json['seances'] as List<dynamic>? ?? const []))
          CourseSeance.fromJson(row as Map<String, dynamic>),
      ],
    );
  }

  final String title;
  final List<CourseSeance> seances;
}

List<String> _strings(dynamic raw) => [
      for (final value in (raw as List<dynamic>? ?? const [])) value.toString(),
    ];
