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

/// Browsing only, matching the backend's scope decision (App\Controller\Api\MessagesController) -
/// no compose/reply endpoints exist yet.
class MessagingService {
  MessagingService({http.Client? client}) : _client = client ?? http.Client();

  static const folderInbox = 'inbox';
  static const folderSent = 'sent';
  static const folderArchived = 'archived';

  final http.Client _client;

  Future<List<MessageThreadSummary>> fetchThreads(String token, {String folder = folderInbox}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/messages/threads').replace(
      queryParameters: {'folder': folder},
    );

    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw MessagingException('Impossible de charger les messages.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['threads'] as List<dynamic>)
        .map((thread) => MessageThreadSummary.fromJson(thread as Map<String, dynamic>))
        .toList();
  }

  Future<MessageThreadDetail> fetchThread(String token, int id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/messages/threads/$id');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw MessagingException('Impossible de charger ce message.');
    }

    return MessageThreadDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<int> fetchUnreadCount(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/messages/unread-count');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw MessagingException('Impossible de charger le nombre de messages non lus.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return body['count'] as int;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
