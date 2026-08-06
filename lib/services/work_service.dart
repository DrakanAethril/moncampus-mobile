import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/work_item.dart';
import 'api_config.dart';

class WorkException implements Exception {
  WorkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to App\Controller\Api\WorkController - the Travaux tab, student side
/// (4a/4b/4c) and teacher side (4d). Read-only: handing a file in and creating a travail both
/// stay on the web.
class WorkService {
  WorkService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WorkBoard> fetchStudentBoard(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/student-work'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw WorkException('Impossible de charger vos travaux.');
    }

    return WorkBoard.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WorkDetail> fetchDetail(String token, int assignmentId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/student-work/$assignmentId'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw WorkException('Impossible de charger ce travail.');
    }

    return WorkDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// [finished] switches the header pills of 4d: En cours (deadline ahead) / Terminés (passed).
  Future<List<TeacherWorkItem>> fetchTeacherWork(String token,
      {required bool finished}) async {
    final response = await _client.get(
      Uri.parse(
          '${ApiConfig.baseUrl}/api/teacher-work?scope=${finished ? 'finished' : 'current'}'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw WorkException('Impossible de charger vos travaux.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['items'] as List<dynamic>? ?? const [])
        .map((e) => TeacherWorkItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
