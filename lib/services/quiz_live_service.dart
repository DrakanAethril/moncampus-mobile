import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/quiz_live_state.dart';
import 'api_config.dart';

class QuizLiveException implements Exception {
  QuizLiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to Api\QuizLiveController - join/play a live multiplayer quiz. No
/// host/projector calls here, that stays web-only (see the backend service's class docblock).
class QuizLiveService {
  QuizLiveService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<QuizLiveActiveSession?> fetchActive(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/quiz-live/active');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw QuizLiveException('Impossible de vérifier les concours en cours.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final session = body['session'];

    return session != null ? QuizLiveActiveSession.fromJson(session as Map<String, dynamic>) : null;
  }

  Future<QuizLiveConnection> join(String token, int sessionId, String displayName) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/quiz-live/$sessionId/join');
    final response = await _client.post(
      uri,
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'displayName': displayName}),
    );

    if (response.statusCode != 200) {
      throw QuizLiveException('Impossible de rejoindre le concours.');
    }

    return QuizLiveConnection.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Resync fallback (app backgrounded past the SSE connection's idle window, cold start, etc.) -
  /// never the primary transport, same "resume from server truth" convention as the backend's own
  /// Api\QuizLiveController::state() docblock. Also doubles as how the play screen reconnects
  /// after a dropped stream, since it re-mints a fresh subscriber token too.
  Future<QuizLiveConnection> fetchState(String token, int sessionId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/quiz-live/$sessionId/state');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw QuizLiveException("Impossible de récupérer l'état du concours.");
    }

    return QuizLiveConnection.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> submitAnswer(String token, int sessionId, int answerId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/quiz-live/$sessionId/answer');
    final response = await _client.post(
      uri,
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'answerId': answerId}),
    );

    if (response.statusCode != 200) {
      throw QuizLiveException("Impossible d'envoyer la réponse.");
    }
  }

  /// Hand-rolled SSE - Dart has no built-in EventSource. `http`'s streamed response is enough
  /// since every Mercure update this feature publishes is a single-line `data:` JSON blob with no
  /// custom `event:` name (see QuizLiveSessionService's publish calls, all default-"message"
  /// updates) - the client dispatches on the payload's own `type` key instead. Unlike a browser's
  /// native EventSource, this does not auto-reconnect; the caller (QuizLivePlayScreen) is
  /// responsible for retrying via fetchState() + a fresh subscribe() on stream error/done.
  Stream<QuizLiveState> subscribe({
    required String mercurePublicUrl,
    required String topic,
    required String mercureToken,
  }) async* {
    final uri = Uri.parse(mercurePublicUrl).replace(queryParameters: {'topic': topic});
    final request = http.Request('GET', uri)
      ..headers['Authorization'] = 'Bearer $mercureToken'
      ..headers['Accept'] = 'text/event-stream';

    final streamedResponse = await http.Client().send(request);
    if (streamedResponse.statusCode != 200) {
      throw QuizLiveException('Connexion au concours perdue.');
    }

    final lines = streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter());

    final buffer = StringBuffer();
    await for (final line in lines) {
      if (line.isEmpty) {
        if (buffer.isNotEmpty) {
          yield QuizLiveState.fromJson(jsonDecode(buffer.toString()) as Map<String, dynamic>);
          buffer.clear();
        }
        continue;
      }
      if (line.startsWith('data:')) {
        buffer.write(line.substring(5).trimLeft());
      }
      // 'id:'/'retry:' lines and ':'-prefixed keep-alive comments are intentionally ignored.
    }
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
