import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/course_space.dart';
import 'api_config.dart';

class CourseSpaceException implements Exception {
  CourseSpaceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to Api\CourseSpaceController - « Mes cours », its séquences, their séances and
/// the resources under them.
class CourseSpaceService {
  CourseSpaceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<CourseProgram>> fetchPrograms(String token) async {
    final body = await _get(token, '/api/courses', 'Impossible de charger vos cours.');

    return [
      for (final row in (body['programs'] as List<dynamic>? ?? const []))
        CourseProgram.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<CourseProgramPage> fetchProgram(String token, int programId) async {
    return CourseProgramPage.fromJson(
      await _get(token, '/api/courses/$programId', 'Impossible de charger cette classe.'),
    );
  }

  Future<CourseSequencePage> fetchSequence(String token, int programId, int sequenceId) async {
    return CourseSequencePage.fromJson(
      await _get(
        token,
        '/api/courses/$programId/sequences/$sequenceId',
        'Impossible de charger cette séquence.',
      ),
    );
  }

  /// Opens a resource: the server records the opening and hands back the address to launch.
  ///
  /// Two calls rather than a URL in the listing, and that is the whole point - this is the only
  /// moment that can tell « the student saw it listed » from « the student opened it », which is
  /// what an access condition downstream reads.
  Future<String> openResource(String token, int resourceId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/courses/resources/$resourceId/open'),
      headers: _headers(token),
    );

    // The lock is re-checked at the door on the server: a row greyed since the last refresh still
    // says no here, and the app must not present that as a failure to load.
    if (response.statusCode == 409) {
      throw CourseSpaceException("Cette ressource n'est pas encore accessible.");
    }
    if (response.statusCode != 200) {
      throw CourseSpaceException("Impossible d'ouvrir cette ressource.");
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final url = body['url'] as String? ?? '';
    if (url.isEmpty) {
      throw CourseSpaceException("Cette ressource n'a pas d'adresse.");
    }

    return url;
  }

  Future<Map<String, dynamic>> _get(String token, String path, String onError) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw CourseSpaceException(onError);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
