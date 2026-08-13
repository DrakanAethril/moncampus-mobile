import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/video_cue.dart';
import '../widgets/quiz_question_form.dart';
import 'api_config.dart';

class VideoCueException implements Exception {
  VideoCueException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to Api\VideoCueController - the markers of an interactive video, the
/// statement of one of them, and its answer.
class VideoCueService {
  VideoCueService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<VideoCuePoint>> fetchCues(String token, int assignmentId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/student-work/$assignmentId/video/cues'),
      headers: _headers(token),
    );

    // A travail with no interactive video simply has no markers - not an error worth showing.
    if (response.statusCode == 404) {
      return const [];
    }
    if (response.statusCode != 200) {
      throw VideoCueException('Impossible de charger les questions de la vidéo.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return [
      for (final row in (body['cuePoints'] as List<dynamic>? ?? const []))
        VideoCuePoint.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<VideoCueQuestion> fetchQuestion(String token, int assignmentId, int cueId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/student-work/$assignmentId/video/cue/$cueId'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw VideoCueException('Impossible de charger cette question.');
    }

    return VideoCueQuestion.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Posts the answer under the names the grader reads.
  ///
  /// The same six lists as a quiz answer, and for the same reason: App\Service\VideoCueGrader is
  /// App\Service\QuizAnswerChecker with a posted body read into it, so a question cannot be right
  /// in a quiz and wrong in a video.
  Future<VideoCueOutcome> submitAnswer(
    String token,
    int assignmentId,
    int cueId,
    QuizAnswerInput input,
  ) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/student-work/$assignmentId/video/cue/$cueId/answer'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'answers': input.answerIds,
        'blanks': input.blanks,
        'zones': input.zones,
        'placements': [
          for (final entry in input.placements.entries) {'zone': entry.key, 'choice': entry.value},
        ],
        'pairs': [
          for (final entry in input.associations.entries) {'pair': entry.key, 'choice': entry.value},
        ],
        'numeric': input.numeric,
      }),
    );

    if (response.statusCode != 200) {
      throw VideoCueException("Impossible d'enregistrer la réponse.");
    }

    return VideoCueOutcome.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
