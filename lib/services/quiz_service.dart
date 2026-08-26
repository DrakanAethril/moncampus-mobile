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

  /// Starts a quiz, or resumes the attempt already open.
  ///
  /// **The supervision capability is declared here**, in the body, and that is what makes a
  /// supervised assessment startable at all: the server refuses a client that says nothing, because
  /// a version number tells it what was shipped, not what is compiled in. This build reports, so it
  /// says so.
  Future<QuizStartOutcome> start(String token, int instanceId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/quiz/$instanceId/start'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'supervision': 'supported'}),
    );

    if (response.statusCode == 409) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      // The server's own sentence when it has one - it is written to be shown as it stands.
      throw QuizException(body['message'] as String? ?? "Ce quiz n'est pas ouvert en ce moment.");
    }
    if (response.statusCode != 200) {
      throw QuizException('Impossible de démarrer ce quiz.');
    }

    return QuizStartOutcome.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// One fact of the supervision journal - the same endpoint vocabulary as the browser's beacon,
  /// so the server learns nothing new from a phone.
  ///
  /// Deliberately swallows its own failures: a lost event must never interrupt an assessment, and
  /// there is nothing a student could do about it anyway. What a lost departure costs is a duration
  /// the server reconstructs from the declared one, bounded by the instants it knows.
  Future<void> reportEvent(
    String token,
    int attemptId, {
    required String sessionKey,
    required String type,
    int? position,
    int? durationMs,
  }) async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/quiz/attempt/$attemptId/event'),
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionKey': sessionKey,
          'type': type,
          'position': position,
          'durationMs': durationMs,
        }),
      );
    } catch (_) {
      // Nothing to report to, and nothing for the student to do.
    }
  }

  /// One question of the attempt. [sessionKey] is presented on a supervised passation: the last
  /// client to open the attempt owns it, and this one is told rather than left composing into
  /// nothing if a browser has taken the hand.
  Future<QuizQuestionPage> fetchQuestion(String token, int attemptId, int position, {String? sessionKey}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/quiz/attempt/$attemptId/question/$position'),
      headers: {
        ..._headers(token),
        if (sessionKey != null) 'X-Quiz-Session': sessionKey,
      },
    );

    if (response.statusCode == 409) {
      throw QuizException('Ce contrôle a été repris ailleurs. Rouvrez-le pour reprendre la main.');
    }
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
  Future<({bool concluded, int? nextPosition, bool late})> submitAnswer(
    String token,
    int attemptId,
    int position, {
    List<int> answerIds = const [],
    List<String> blanks = const [],
    List<String> zones = const [],
    Map<String, String> placements = const {},
    Map<String, String> associations = const {},
    String numeric = '',
    String? sessionKey,
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
        // Numérique / Calculée: sent verbatim, comma and unit included. The server owns the reading
        // (App\Util\NumericAnswerParser) so the app and the grader can never disagree on what
        // "2,5 m" means.
        'numeric': numeric,
        // Who owns the attempt, on a supervised passation - the second opening becomes useless the
        // moment the first one answers, and this is which one this client is.
        'sessionKey': sessionKey,
      }),
    );

    if (response.statusCode == 409) {
      throw QuizException('Ce contrôle a été repris ailleurs. Rouvrez-le pour reprendre la main.');
    }
    if (response.statusCode != 200) {
      throw QuizException("Impossible d'enregistrer la réponse.");
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (
      concluded: body['concluded'] as bool? ?? false,
      nextPosition: body['nextPosition'] as int?,
      // The question's own budget had run out before the answer arrived: nothing was recorded and
      // the passation moves on, exactly as it does in a browser.
      late: body['late'] as bool? ?? false,
    );
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
