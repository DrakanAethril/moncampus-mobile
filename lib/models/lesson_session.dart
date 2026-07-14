/// Mirrors GET /api/timetable's session shape (App\Controller\Api\TimetableController on the
/// backend).
class LessonSession {
  const LessonSession({
    required this.id,
    required this.title,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.program,
    this.teacher,
    this.room,
  });

  factory LessonSession.fromJson(Map<String, dynamic> json) => LessonSession(
        id: json['id'] as int,
        title: json['title'] as String,
        day: DateTime.parse(json['day'] as String),
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        teacher: json['teacher'] as String?,
        room: json['room'] as String?,
        color: json['color'] as String,
        program: json['program'] as String,
      );

  final int id;
  final String title;
  final DateTime day;
  final String startTime;
  final String endTime;
  final String? teacher;
  final String? room;
  final String color;
  final String program;
}
