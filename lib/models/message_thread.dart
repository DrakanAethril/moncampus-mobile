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

  factory MessageThreadSummary.fromJson(Map<String, dynamic> json) => MessageThreadSummary(
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

  factory MessageAttachment.fromJson(Map<String, dynamic> json) => MessageAttachment(
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
            .map((attachment) => MessageAttachment.fromJson(attachment as Map<String, dynamic>))
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
  });

  factory MessageThreadDetail.fromJson(Map<String, dynamic> json) => MessageThreadDetail(
        id: json['id'] as int,
        subject: json['subject'] as String,
        canReply: json['canReply'] as bool,
        messages: (json['messages'] as List<dynamic>)
            .map((message) => MessageItem.fromJson(message as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String subject;
  final bool canReply;
  final List<MessageItem> messages;
}
