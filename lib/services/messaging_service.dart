import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/message_thread.dart';
import 'api_config.dart';

class MessagingException implements Exception {
  MessagingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A file staged for upload in a compose/reply request, before it's turned into a
/// [http.MultipartFile] - kept in memory (bytes, not a path) so it works the same whether it came
/// from file_picker or image_picker, on every platform those support.
class PendingAttachment {
  const PendingAttachment({required this.filename, required this.bytes});

  final String filename;
  final List<int> bytes;
}

class MessagingService {
  MessagingService({http.Client? client}) : _client = client ?? http.Client();

  static const folderInbox = 'inbox';
  static const folderSent = 'sent';
  static const folderArchived = 'archived';

  final http.Client _client;

  Future<List<MessageThreadSummary>> fetchThreads(String token,
      {String folder = folderInbox}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/messages/threads').replace(
      queryParameters: {'folder': folder},
    );

    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw MessagingException('Impossible de charger les messages.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['threads'] as List<dynamic>)
        .map((thread) =>
            MessageThreadSummary.fromJson(thread as Map<String, dynamic>))
        .toList();
  }

  Future<MessageThreadDetail> fetchThread(String token, int id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/messages/threads/$id');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw MessagingException('Impossible de charger ce message.');
    }

    return MessageThreadDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<int> fetchUnreadCount(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/messages/unread-count');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw MessagingException(
          'Impossible de charger le nombre de messages non lus.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return body['count'] as int;
  }

  Future<List<RecipientCandidate>> searchRecipients(
      String token, String query) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/messages/recipients-search')
        .replace(
      queryParameters: {'q': query},
    );

    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw MessagingException('Impossible de charger les destinataires.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['results'] as List<dynamic>)
        .map((result) =>
            RecipientCandidate.fromJson(result as Map<String, dynamic>))
        .toList();
  }

  /// Composes a new thread. [recipients] is the raw chip selection (mixed users/classes) - split
  /// here into the two id lists the API expects (App\Controller\Api\MessagesController::compose(),
  /// which expands "classe" chips into individual manual recipients server-side).
  Future<int> compose(
    String token, {
    required String subject,
    required String body,
    required List<RecipientCandidate> recipients,
    List<PendingAttachment> attachments = const [],
  }) async {
    final request = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}/api/messages'))
      ..headers.addAll(_headers(token))
      ..fields['subject'] = subject
      ..fields['body'] = body;

    _addFieldList(
        request,
        recipients.where((r) => !r.isProgram).map((r) => '${r.id}').toList(),
        'recipientUserIds[]');
    _addFieldList(
        request,
        recipients.where((r) => r.isProgram).map((r) => '${r.id}').toList(),
        'recipientProgramIds[]');

    for (final attachment in attachments) {
      request.files.add(http.MultipartFile.fromBytes(
          'attachments[]', attachment.bytes,
          filename: attachment.filename));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 201) {
      throw MessagingException(
          _errorMessage(response, 'Impossible d\'envoyer le message.'));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return decoded['id'] as int;
  }

  Future<void> reply(String token, int threadId,
      {required String body,
      List<PendingAttachment> attachments = const []}) async {
    final request = http.MultipartRequest('POST',
        Uri.parse('${ApiConfig.baseUrl}/api/messages/threads/$threadId/reply'))
      ..headers.addAll(_headers(token))
      ..fields['body'] = body;

    for (final attachment in attachments) {
      request.files.add(http.MultipartFile.fromBytes(
          'attachments[]', attachment.bytes,
          filename: attachment.filename));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw MessagingException(
          _errorMessage(response, 'Impossible d\'envoyer la réponse.'));
    }
  }

  // http.MultipartRequest.fields is a Map<String,String>, so repeated keys (the recipients[]
  // convention the Symfony backend expects) can't go through it directly - fields with the same
  // name must be added as separate entries in the underlying multipart body instead.
  void _addFieldList(
      http.MultipartRequest request, List<String> values, String field) {
    for (final value in values) {
      request.files.add(http.MultipartFile.fromString(field, value));
    }
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final errors = body['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) return errors.first as String;

      return switch (body['error']) {
        'subject_required' => "L'objet est requis.",
        'body_required' => 'Le message ne peut pas être vide.',
        'recipients_required' => 'Choisissez au moins un destinataire.',
        'programs_not_allowed' ||
        'program_not_allowed' =>
          "Vous n'êtes pas autorisé à écrire à cette classe.",
        'invalid_attachment' =>
          'Pièce jointe invalide (type ou taille non supportés).',
        _ => fallback,
      };
    } catch (_) {
      return fallback;
    }
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
