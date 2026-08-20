import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/survey.dart';
import 'api_config.dart';

class SurveyException implements Exception {
  SurveyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to Api\SurveyController - « Mes sondages » and the passation.
///
/// The three refusals the server answers with (403 not_targeted / already_answered / closed) are
/// one rule: the frozen target *is* the right to answer, and nothing is recomputed here either.
class SurveyService {
  SurveyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// The surveys still to answer - target rows without responded_at, on an open campaign.
  Future<List<SurveySummary>> fetchPending(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/surveys'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw SurveyException('Impossible de charger les sondages.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['surveys'] as List<dynamic>? ?? const [])
        .map((e) => SurveySummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Survey> fetchSurvey(String token, int id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/surveys/$id'),
      headers: _headers(token),
    );

    if (response.statusCode == 403) {
      throw SurveyException(_refusalMessage(response.body));
    }
    if (response.statusCode != 200) {
      throw SurveyException('Impossible de charger ce sondage.');
    }

    return Survey.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Saves the answers. A draft by default; [submit] closes the response - which is the moment the
  /// server stamps survey_target.responded_at, in the same transaction.
  ///
  /// [responseId] is the draft being continued. Passing it matters on an **anonymous** campaign
  /// above all: the response stores no respondent there, so the server has nothing to find it back
  /// by - which is exactly why the draft survives the app being closed only if the app remembers
  /// its id.
  Future<({int responseId, bool submitted})> saveResponse(
    String token,
    int surveyId,
    List<SurveyAnswerInput> answers, {
    bool submit = false,
    int? responseId,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/surveys/$surveyId/response'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'answers': [for (final answer in answers) answer.toJson()],
        'submit': submit,
        if (responseId != null) 'responseId': responseId,
      }),
    );

    if (response.statusCode == 422) {
      throw SurveyException('Il reste des questions obligatoires sans réponse.');
    }
    if (response.statusCode == 403) {
      throw SurveyException(_refusalMessage(response.body));
    }
    if (response.statusCode != 200) {
      throw SurveyException("Impossible d'enregistrer vos réponses.");
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (
      responseId: body['responseId'] as int,
      submitted: body['submitted'] as bool? ?? false,
    );
  }

  /// The server's three refusals, said in French - they are the same rule seen from three angles.
  String _refusalMessage(String body) {
    try {
      final error = (jsonDecode(body) as Map<String, dynamic>)['error'] as String?;

      return switch (error) {
        'already_answered' => 'Vous avez déjà répondu à ce sondage.',
        'closed' => "Ce sondage n'est plus ouvert.",
        _ => "Ce sondage ne vous est pas adressé.",
      };
    } catch (_) {
      return "Ce sondage ne vous est pas adressé.";
    }
  }

  Map<String, String> _headers(String token) => {'Authorization': 'Bearer $token'};
}
