/// The mailbox as the app bar's envelope opens it - GET /api/school-mail
/// (App\Controller\Api\SchoolMailController).
///
/// [locked] is the whole of screen 5a: as long as the practice application has not been validated
/// by a teacher there is nothing to show and nothing to do (handoff, principe 5).
class SchoolMailbox {
  const SchoolMailbox({
    required this.locked,
    required this.unread,
    required this.canSend,
    required this.messages,
    this.address,
  });

  factory SchoolMailbox.fromJson(Map<String, dynamic> json) => SchoolMailbox(
        locked: json['locked'] as bool? ?? true,
        unread: json['unread'] as int? ?? 0,
        canSend: json['canSend'] as bool? ?? false,
        address: json['address'] as String?,
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .map((e) => SchoolMailMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final bool locked;
  final int unread;

  /// A closed job search leaves the mailbox readable but turns sending off - the FAB then goes.
  final bool canSend;

  /// `prenom.nom@etu.beaupeyrat.org` - always visible next to the title (principe 6).
  final String? address;
  final List<SchoolMailMessage> messages;
}

/// One row of the list (5b) - and, once opened, the head of the mail being read (5c).
class SchoolMailMessage {
  const SchoolMailMessage({
    required this.id,
    required this.name,
    required this.address,
    required this.initials,
    required this.date,
    required this.unread,
    required this.hasAttachments,
    this.subject,
    this.preview,
    this.application,
    this.outbound = false,
  });

  factory SchoolMailMessage.fromJson(Map<String, dynamic> json) =>
      SchoolMailMessage(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        initials: json['initials'] as String? ?? '?',
        subject: json['subject'] as String?,
        preview: json['preview'] as String?,
        date: DateTime.parse(json['date'] as String).toLocal(),
        unread: json['unread'] as bool? ?? false,
        hasAttachments: json['hasAttachments'] as bool? ?? false,
        application: json['application'] as String?,
        outbound: json['direction'] == 'outbound',
      );

  final int id;
  final String name;
  final String address;
  final String initials;
  final String? subject;
  final String? preview;
  final DateTime date;
  final bool unread;
  final bool hasAttachments;

  /// The démarche the mail belongs to - the gold "Candidature · …" chip.
  final String? application;
  final bool outbound;
}

/// A mail being read (5c): its head, its body and its attachments.
class SchoolMailDetail {
  const SchoolMailDetail({
    required this.message,
    required this.body,
    required this.attachments,
  });

  factory SchoolMailDetail.fromJson(Map<String, dynamic> json) =>
      SchoolMailDetail(
        message: SchoolMailMessage.fromJson(json),
        body: json['body'] as String? ?? '',
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .map((e) => MailAttachment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final SchoolMailMessage message;
  final String body;
  final List<MailAttachment> attachments;
}

class MailAttachment {
  const MailAttachment(
      {required this.id, required this.filename, required this.sizeBytes});

  factory MailAttachment.fromJson(Map<String, dynamic> json) => MailAttachment(
        id: json['id'] as int,
        filename: json['filename'] as String? ?? '',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
      );

  final int id;
  final String filename;
  final int sizeBytes;

  String get sizeLabel => sizeBytes >= 1024 * 1024
      ? '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo'
      : '${(sizeBytes / 1024).round()} Ko';

  /// "PDF", "PNG"… - the tile drawn at the left of the attachment row.
  String get kind {
    final dot = filename.lastIndexOf('.');
    if (dot == -1 || dot == filename.length - 1) return 'FICHIER';

    return filename.substring(dot + 1).toUpperCase().substring(
        0, filename.length - dot - 1 > 4 ? 4 : filename.length - dot - 1);
  }
}

/// What the compose screen needs before anything is typed (5d).
class ComposeMeta {
  const ComposeMeta({
    required this.signature,
    required this.applications,
    this.address,
  });

  factory ComposeMeta.fromJson(Map<String, dynamic> json) => ComposeMeta(
        address: json['address'] as String?,
        signature: json['signature'] as String? ?? '',
        applications: (json['applications'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
      );

  final String? address;

  /// Appended server-side at send time; the screen only shows it, greyed out.
  final String signature;
  final List<String> applications;
}
