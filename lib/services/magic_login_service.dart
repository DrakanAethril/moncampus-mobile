import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// The mailed link was refused: expired, already used, or unknown (screen 6d). The API never says
/// which, so neither does this.
class MagicLinkExpiredException implements Exception {}

class MagicLoginException implements Exception {
  MagicLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Passwordless login by mailed link (design_handoff_mobile, tour 6) - the client of
/// App\Controller\Api\MagicLoginController.
class MagicLoginService {
  MagicLoginService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Asks for a link and returns the masked address to display on 6b. Answers the same whether
  /// the address belongs to an account or not - by design, the app never learns which.
  Future<String> requestLink(String email) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/magic-login/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw MagicLoginException("Le lien n'a pas pu être envoyé.");
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return body['maskedEmail'] as String? ?? email;
  }

  /// Trades the token carried by the deep link for a JWT (6c).
  Future<({String token, String? firstname})> consume(String token) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/magic-login/consume'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 410) {
      throw MagicLinkExpiredException();
    }
    if (response.statusCode != 200) {
      throw MagicLoginException('Impossible de vous connecter.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (
      token: body['token'] as String,
      firstname: body['firstname'] as String?,
    );
  }
}
