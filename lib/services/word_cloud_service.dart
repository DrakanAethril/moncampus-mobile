import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/word_cloud.dart';
import 'api_config.dart';

class WordCloudException implements Exception {
  WordCloudException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to Api\WordCloudController - three plain REST calls and no stream.
///
/// The live contest hand-rolls SSE because the phone has to learn that the host moved on; a word
/// cloud has nothing to push at a student who has written their word. When the teacher has switched
/// « Les étudiants voient le nuage sur leur écran » on, the cloud rides back with the answer to the
/// submission, which is the only moment it can have changed for them.
///
/// No pilot or projector calls here: those stay web-only, exactly as for the contest.
class WordCloudService {
  WordCloudService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// The banner's question. Answers null when there is nothing open for this account - including
  /// for a teacher, whom the API deliberately answers with an empty body rather than a 403.
  Future<WordCloudBanner?> fetchActive(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/word-clouds/active');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw WordCloudException('Impossible de vérifier les nuages de mots en cours.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final cloud = body['cloud'];

    return cloud != null ? WordCloudBanner.fromJson(cloud as Map<String, dynamic>) : null;
  }

  Future<WordCloudState> fetchCloud(String token, int id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/word-clouds/$id');
    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw WordCloudException('Ce nuage de mots n’est pas accessible.');
    }

    return WordCloudState.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Sends the boxes that were filled in, and gets back what was taken along with the new state.
  ///
  /// A refusal is **not** an exception: the period, the quota and the duplicate are ordinary
  /// answers the screen has to show, one word at a time. Only a broken call throws.
  Future<WordCloudSubmitResult> submit(String token, int id, List<String> words) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/word-clouds/$id/submit');
    final response = await _client.post(
      uri,
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'words': words}),
    );

    if (response.statusCode != 200) {
      throw WordCloudException('Votre mot n’a pas pu être envoyé.');
    }

    return WordCloudSubmitResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
