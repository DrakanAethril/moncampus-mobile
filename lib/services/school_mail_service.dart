import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/school_mail.dart';
import 'api_config.dart';

class SchoolMailException implements Exception {
  SchoolMailException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to App\Controller\Api\SchoolMailController - Courrier pro (screens
/// 5a-5d). Reading, replying, forwarding and writing; no drafts and no trash, which stay on the
/// web mailbox.
class SchoolMailService {
  SchoolMailService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SchoolMailbox> fetchFolder(String token, {required bool sent}) async {
    final response = await _client.get(
      Uri.parse(
          '${ApiConfig.baseUrl}/api/school-mail?folder=${sent ? 'sent' : 'inbox'}'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw SchoolMailException('Impossible de charger votre courrier.');
    }

    return SchoolMailbox.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SchoolMailDetail> fetchMessage(String token, int id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/school-mail/$id'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw SchoolMailException('Impossible d\'ouvrir ce mail.');
    }

    return SchoolMailDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ComposeMeta> fetchComposeMeta(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/school-mail/meta/compose'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw SchoolMailException('Impossible de préparer le message.');
    }

    return ComposeMeta.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Sending (5d). Multipart, since attachments are files picked on the phone; [application] is
  /// the démarche the mail belongs to and [replyToId] threads it onto the mail being answered.
  Future<void> send(
    String token, {
    required String to,
    required String subject,
    required String body,
    required String application,
    int? replyToId,
    List<File> attachments = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/school-mail/send'),
    )
      ..headers.addAll(_headers(token))
      ..fields['to'] = to
      ..fields['subject'] = subject
      ..fields['body'] = body
      ..fields['application'] = application;

    if (replyToId != null) {
      request.fields['replyTo'] = replyToId.toString();
    }

    for (final file in attachments) {
      request.files
          .add(await http.MultipartFile.fromPath('attachments[]', file.path));
    }

    final response = await request.send();

    if (response.statusCode == 403) {
      throw SchoolMailException("Votre boîte n'autorise pas l'envoi.");
    }
    if (response.statusCode != 200) {
      throw SchoolMailException("Le mail n'a pas pu être envoyé.");
    }
  }

  /// Attachments are stored in the mail bucket and served behind the API's Bearer auth, which an
  /// external browser could not present - so the file is downloaded here and handed to the OS as
  /// a local file.
  Future<File> downloadAttachment(
      String token, MailAttachment attachment) async {
    final response = await _client.get(
      Uri.parse(
          '${ApiConfig.baseUrl}/api/school-mail/attachments/${attachment.id}'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw SchoolMailException("Pièce jointe indisponible.");
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${attachment.filename}');
    await file.writeAsBytes(response.bodyBytes);

    return file;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
