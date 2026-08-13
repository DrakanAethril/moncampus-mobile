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

  /// Reports what the player really heard of one file. The only write this service makes: listening
  /// is the proof of completion of a Listening travail, so a student listening on their phone has to
  /// be able to finish it there (design_handoff_enregistrements_audio, "Tracking d'écoute").
  ///
  /// Failures are swallowed by the caller: a lost progress report costs at most a few seconds of
  /// credit, which the next one makes up - the server only ever keeps the maximum.
  Future<int> reportListenProgress(
    String token,
    int assignmentId,
    int fileId,
    int percent,
  ) async {
    final response = await _client.post(
      Uri.parse(
          '${ApiConfig.baseUrl}/api/student-work/$assignmentId/audio/$fileId/listen-progress'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'percent': percent}),
    );

    if (response.statusCode != 200) {
      throw WorkException("La progression d'écoute n'a pas pu être envoyée.");
    }

    return (jsonDecode(response.body) as Map<String, dynamic>)['percent']
            as int? ??
        percent;
  }

  /// The watching reported by the mobile player, twin of reportListenProgress() one media over.
  ///
  /// Same ratchet on the server (App\Service\VideoWatchTracker): only the maximum is kept, so a
  /// report that went missing costs nothing but the credit of that moment, which the next one
  /// makes up.
  Future<int> reportWatchProgress(
    String token,
    int assignmentId,
    int fileId,
    int percent,
  ) async {
    final response = await _client.post(
      Uri.parse(
          '${ApiConfig.baseUrl}/api/student-work/$assignmentId/video/$fileId/watch-progress'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'percent': percent}),
    );

    if (response.statusCode != 200) {
      throw WorkException("La progression de visionnage n'a pas pu être envoyée.");
    }

    return (jsonDecode(response.body) as Map<String, dynamic>)['percent']
            as int? ??
        percent;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
