import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agenda_event.dart';
import 'api_config.dart';

class AgendaException implements Exception {
  AgendaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AgendaService {
  AgendaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AgendaEvent>> fetchEvents(String token, {bool past = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/agenda').replace(
      queryParameters: {'past': past ? '1' : '0'},
    );

    final response = await _client.get(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw AgendaException("Impossible de charger l'agenda.");
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['events'] as List<dynamic>)
        .map((event) => AgendaEvent.fromJson(event as Map<String, dynamic>))
        .toList();
  }

  Future<SignupListSummary> register(String token, int signupListId) =>
      _postSignupListAction(token, signupListId, 'register');

  Future<SignupListSummary> unregister(String token, int signupListId) =>
      _postSignupListAction(token, signupListId, 'unregister');

  Future<SignupListSummary> _postSignupListAction(String token, int signupListId, String action) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/signup-lists/$signupListId/$action');
    final response = await _client.post(uri, headers: _headers(token));

    if (response.statusCode != 200) {
      throw AgendaException(
        'register' == action ? "Impossible de vous inscrire." : "Impossible de vous désinscrire.",
      );
    }

    return SignupListSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
