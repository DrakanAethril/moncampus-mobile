import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lesson_session.dart';
import 'api_config.dart';

class TimetableException implements Exception {
  TimetableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TimetableService {
  TimetableService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<LessonSession>> fetchWeek(String token, {required DateTime from, required DateTime to}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/timetable').replace(
      queryParameters: {'from': _isoDate(from), 'to': _isoDate(to)},
    );

    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw TimetableException("Impossible de charger l'emploi du temps.");
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['sessions'] as List<dynamic>)
        .map((session) => LessonSession.fromJson(session as Map<String, dynamic>))
        .toList();
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
