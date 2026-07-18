import '../utils/html_text.dart';

/// Mirrors GET /api/messages/threads's row shape (App\Controller\Api\MessagesController).
class MessageThreadSummary {
  const MessageThreadSummary({
    required this.id,
    required this.subject,
    required this.counterpart,
    required this.snippet,
    required this.lastMessageAt,
    required this.unread,
  });

  factory MessageThreadSummary.fromJson(Map<String, dynamic> json) =>
      MessageThreadSummary(
        id: json['id'] as int,
        subject: json['subject'] as String,
        counterpart: json['counterpart'] as String,
        snippet: json['snippet'] as String,
        lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
        unread: json['unread'] as bool,
      );

  final int id;
  final String subject;
  final String counterpart;
  final String snippet;
  final DateTime lastMessageAt;
  final bool unread;
}

class MessageAttachment {
  const MessageAttachment({required this.label, required this.url});

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        label: json['label'] as String,
        url: json['url'] as String,
      );

  final String label;
  final String url;
}

class MessageItem {
  const MessageItem({
    required this.id,
    required this.author,
    required this.body,
    required this.sentAt,
    required this.attachments,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) => MessageItem(
        id: json['id'] as int,
        author: json['author'] as String,
        body: json['body'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
        attachments: (json['attachments'] as List<dynamic>)
            .map((attachment) =>
                MessageAttachment.fromJson(attachment as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String author;
  final String body;
  final DateTime sentAt;
  final List<MessageAttachment> attachments;

  /// The backend stores the rich-text (HugeRTE) sanitized HTML body as-is - see utils/html_text.dart.
  String get plainTextBody => stripHtmlToPlainText(body);
}

class MessageThreadDetail {
  const MessageThreadDetail({
    required this.id,
    required this.subject,
    required this.canReply,
    required this.messages,
    required this.recipientNames,
    required this.audienceLabel,
  });

  factory MessageThreadDetail.fromJson(Map<String, dynamic> json) =>
      MessageThreadDetail(
        id: json['id'] as int,
        subject: json['subject'] as String,
        canReply: json['canReply'] as bool,
        messages: (json['messages'] as List<dynamic>)
            .map((message) =>
                MessageItem.fromJson(message as Map<String, dynamic>))
            .toList(),
        recipientNames: (json['recipientNames'] as List<dynamic>)
            .map((name) => name as String)
            .toList(),
        audienceLabel: json['audienceLabel'] as String?,
      );

  final int id;
  final String subject;
  final bool canReply;
  final List<MessageItem> messages;

  /// Every other participant's display name (the viewer excluded) - backs the "+ N destinataires
  /// ▾" expandable row (design 3i).
  final List<String> recipientNames;

  /// Set only for a broadcast-shaped thread (Program/AllStudents/AllTeachers/AllStaff) - null for
  /// a Manual thread, where [recipientNames] alone is the label (see
  /// App\Controller\Api\MessagesController::show()'s docblock on why).
  final String? audienceLabel;
}

/// A single autocomplete result from GET /api/messages/recipients-search - either an individual
/// user or (teacher/staff senders only) a whole "classe"/Program, expanded server-side into its
/// students at compose time.
class RecipientCandidate {
  const RecipientCandidate(
      {required this.type,
      required this.id,
      required this.label,
      required this.sublabel});

  factory RecipientCandidate.fromJson(Map<String, dynamic> json) =>
      RecipientCandidate(
        type: json['type'] as String,
        id: json['id'] as int,
        label: json['label'] as String,
        sublabel: json['sublabel'] as String,
      );

  static const typeUser = 'user';
  static const typeProgram = 'program';

  final String type;
  final int id;
  final String label;
  final String sublabel;

  bool get isProgram => type == typeProgram;
}
