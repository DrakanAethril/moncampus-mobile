import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/quiz.dart';
import 'api_config.dart';

class QuizException implements Exception {
  QuizException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to Api\QuizController - the student's own Quiz section and the individual
/// passation (évaluation and entraînement). The live multiplayer contest is QuizLiveService.
class QuizService {
  QuizService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<QuizHub> fetchHub(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/quiz/mine'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw QuizException('Impossible de charger les quiz.');
    }

    return QuizHub.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Starts a quiz, or resumes the attempt already open. Returns the attempt id and whether it is
  /// already finished - an évaluation already handed in sends the student straight to the result.
  Future<({int attemptId, bool concluded})> start(String token, int instanceId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/quiz/$instanceId/start'),
      headers: _headers(token),
    );

    if (response.statusCode == 409) {
      throw QuizException("Ce quiz n'est pas ouvert en ce moment.");
    }
    if (response.statusCode != 200) {
      throw QuizException('Impossible de démarrer ce quiz.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (attemptId: body['attemptId'] as int, concluded: body['concluded'] as bool? ?? false);
  }

  Future<QuizQuestionPage> fetchQuestion(String token, int attemptId, int position) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/quiz/attempt/$attemptId/question/$position'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw QuizException('Impossible de charger la question.');
    }

    return QuizQuestionPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Saves one question and returns where to go next. [answerIds] carries the selected options (in
  /// submission order, which only matters for an "ordre" question); [blanks] carries one entry per
  /// blank of a texte à trous, in text order. Both modes of a texte à trous - placed words and
  /// typed text - use the very same [blanks] list, so the server never needs to tell them apart.
  /// [zones] carries a Zone question's tapped zone ids; [placements] a Légende's zone => choice
  /// pairs, sent as {"zone", "choice"} objects (the server's JsonRequestPayload reads object
  /// lists, not maps).
  Future<({bool concluded, int? nextPosition})> submitAnswer(
    String token,
    int attemptId,
    int position, {
    List<int> answerIds = const [],
    List<String> blanks = const [],
    List<String> zones = const [],
    Map<String, String> placements = const {},
    Map<String, String> associations = const {},
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/quiz/attempt/$attemptId/question/$position/answer'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'answers': answerIds,
        'blanks': blanks,
        'zones': zones,
        'placements': [
          for (final entry in placements.entries) {'zone': entry.key, 'choice': entry.value},
        ],
        // Apparier, same shape one type over: a list of objects rather than a map, so the payload
        // stays a list whatever the keys are (App\Service\JsonRequestPayload::objects()).
        'pairs': [
          for (final entry in associations.entries) {'pair': entry.key, 'choice': entry.value},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw QuizException("Impossible d'enregistrer la réponse.");
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (concluded: body['concluded'] as bool? ?? false, nextPosition: body['nextPosition'] as int?);
  }

  Future<QuizResult> fetchResult(String token, int attemptId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/quiz/attempt/$attemptId/result'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw QuizException('Impossible de charger le résultat.');
    }

    return QuizResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
