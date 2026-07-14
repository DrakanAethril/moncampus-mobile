import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import 'api_config.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Holds the JWT (in secure/keychain storage, not SharedPreferences, since it's a credential) and
/// the current user, and is the single place that talks to POST /api/login + GET /api/me. Mobile
/// auth always goes through the moncampus API's LDAP-backed login (App\Security\
/// ApiLdapAuthenticator on the backend) - this class never stores or checks a password itself.
class AuthService extends ChangeNotifier {
  AuthService({FlutterSecureStorage? storage, http.Client? client})
      : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  static const _tokenStorageKey = 'jwt_token';

  final FlutterSecureStorage _storage;
  final http.Client _client;

  String? _token;
  AppUser? _currentUser;
  bool _isLoading = true;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;

  /// Read-only - other services (TimetableService, MessagingService, ...) need it to build their
  /// own Authorization headers, but only AuthService ever writes it.
  String? get token => _token;

  /// Called once at app startup: restores a previously stored token and validates it against
  /// GET /api/me (an expired/revoked token just falls back to the login screen).
  Future<void> tryAutoLogin() async {
    _token = await _storage.read(key: _tokenStorageKey);

    if (_token != null) {
      try {
        _currentUser = await _fetchCurrentUser();
      } catch (_) {
        await logout();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw AuthException('Identifiant ou mot de passe incorrect.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _token = body['token'] as String;
    await _storage.write(key: _tokenStorageKey, value: _token);

    _currentUser = await _fetchCurrentUser();
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _storage.delete(key: _tokenStorageKey);
    notifyListeners();
  }

  Future<AppUser> _fetchCurrentUser() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/me'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw AuthException('Session expirée.');
    }

    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
