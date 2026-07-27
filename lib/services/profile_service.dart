import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ProfileException implements Exception {
  ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to App\Controller\Api\ProfileController - the contact-email 3-state machine
/// (design 3g/3j/3k) and self-service password change.
class ProfileService {
  ProfileService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Pass `null` to remove the contact email (the 3g "Annuler" / pending-state removal action -
  /// there's no separate cancel endpoint, same as the web, see App\Controller\Api\
  /// ProfileController::updateContactEmail()'s docblock).
  Future<void> updateContactEmail(String token, String? contactEmail) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/profile/contact-email'),
      headers: _headers(token),
      body: jsonEncode({'contactEmail': contactEmail}),
    );

    if (response.statusCode != 200) {
      throw ProfileException(
          _errorMessage(response, "Impossible d'enregistrer cette adresse."));
    }
  }

  Future<void> resendContactEmailConfirmation(String token) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/profile/contact-email/resend'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw ProfileException(_errorMessage(
          response, "Impossible de renvoyer l'email de confirmation."));
    }
  }

  Future<void> changePassword(
    String token, {
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/profile/change-password'),
      headers: _headers(token),
      body: jsonEncode({
        'newPassword': newPassword,
        'newPasswordConfirmation': newPasswordConfirmation,
      }),
    );

    if (response.statusCode != 200) {
      throw ProfileException(
          _errorMessage(response, 'Impossible de changer le mot de passe.'));
    }
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final errors = body['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) return errors.first as String;

      return switch (body['error']) {
        'no_pending_email' => 'Aucune adresse en attente de validation.',
        'resend_too_soon' =>
          'Un email a déjà été envoyé récemment, merci de patienter.',
        'new_password_contains_username' =>
          'Le nouveau mot de passe ne doit pas contenir votre identifiant.',
        _ => fallback,
      };
    } catch (_) {
      return fallback;
    }
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
}
