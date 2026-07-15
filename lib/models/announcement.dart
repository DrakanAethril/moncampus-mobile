import '../utils/html_text.dart';

/// Mirrors GET /api/announcements's row shape (App\Controller\Api\AnnouncementController).
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.creationDate,
    required this.audienceLabel,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
        creationDate: DateTime.parse(json['creationDate'] as String),
        audienceLabel: json['audienceLabel'] as String,
      );

  final int id;
  final String title;
  final String body;
  final DateTime creationDate;
  final String audienceLabel;

  /// The backend stores the rich-text (HugeRTE) sanitized HTML body as-is - see utils/html_text.dart.
  String get plainTextBody => stripHtmlToPlainText(body);
}
