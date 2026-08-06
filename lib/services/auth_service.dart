import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

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
/// ApiLdapAuthenticator on the backend) - this class never stores or checks a password itself, and
/// never will: biometrics here only ever gate access to an already-issued JWT, they don't replace
/// the LDAP bind.
///
/// "Rester connecté" (design 3f) controls whether the token survives a cold start at all: checked
/// -> persisted to secure storage, so tryAutoLogin() can restore the session; unchecked -> kept in
/// memory only, so the app behaves as logged-in for this run but always requires the login form
/// again next launch. Biometrics (also 3f) are a second, independent gate layered on top of a
/// remembered session: if enabled, a restored token isn't silently traded for a fetched User at
/// startup - [hasPendingBiometricUnlock] stays true (so AuthGate keeps showing LoginScreen) until
/// [unlockWithBiometrics] succeeds.
class AuthService extends ChangeNotifier {
  AuthService(
      {FlutterSecureStorage? storage,
      http.Client? client,
      LocalAuthentication? localAuth})
      : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client(),
        _localAuth = localAuth ?? LocalAuthentication();

  static const _tokenStorageKey = 'jwt_token';
  static const _biometricEnabledKey = 'biometric_enabled';

  final FlutterSecureStorage _storage;
  final http.Client _client;
  final LocalAuthentication _localAuth;

  String? _token;
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _biometricEnabled = false;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;
  bool get biometricEnabled => _biometricEnabled;

  /// True once tryAutoLogin() has restored a token from a "Rester connecté" session but is
  /// withholding it behind the biometric gate - LoginScreen shows the unlock prompt instead of
  /// the identifiant/mot de passe form while this is true.
  bool get hasPendingBiometricUnlock =>
      _token != null && _currentUser == null && _biometricEnabled;

  /// Read-only - other services (TimetableService, MessagingService, ...) need it to build their
  /// own Authorization headers, but only AuthService ever writes it.
  String? get token => _token;

  Future<bool> get canUseBiometrics async {
    try {
      return await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Called once at app startup: restores a previously stored token. If biometrics are enabled,
  /// the token is kept but GET /api/me is deliberately NOT called yet - see
  /// [hasPendingBiometricUnlock]. Otherwise this behaves as a plain silent restore (an
  /// expired/revoked token just falls back to the login screen).
  Future<void> tryAutoLogin() async {
    _token = await _storage.read(key: _tokenStorageKey);
    _biometricEnabled =
        (await _storage.read(key: _biometricEnabledKey)) == 'true';

    if (_token != null && !_biometricEnabled) {
      try {
        await _fetchCurrentUser();
      } catch (_) {
        await logout();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Completes a pending biometric unlock (see [hasPendingBiometricUnlock]) - prompts the OS
  /// biometric UI, and only on success fetches the current user to actually complete sign-in.
  Future<bool> unlockWithBiometrics() async {
    if (_token == null) return false;

    bool authenticated;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: 'Déverrouillez votre session MonCampus',
        options:
            const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      authenticated = false;
    }

    if (!authenticated) return false;

    try {
      await _fetchCurrentUser();
      notifyListeners();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> login(String username, String password,
      {required bool rememberMe}) async {
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

    if (rememberMe) {
      await _storage.write(key: _tokenStorageKey, value: _token);
    } else {
      // Drops any token remembered by a previous, since-abandoned "Rester connecté" session -
      // otherwise the next cold start would silently restore it despite this explicit opt-out.
      await _storage.delete(key: _tokenStorageKey);
      await setBiometricEnabled(false);
    }

    await _fetchCurrentUser();
    notifyListeners();
  }

  /// Adopts a JWT obtained outside the identifiant/mot de passe form - today only the magic link
  /// (design_handoff_mobile, tour 6), whose token App\Controller\Api\MagicLoginController has
  /// already traded for this one. Always remembered: the whole point of the link is not to have to
  /// prove anything again next time, and the biometric prompt of 6c is offered right after.
  Future<void> adoptToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenStorageKey, value: token);
    await _fetchCurrentUser();
    notifyListeners();
  }

  /// Only meaningful once a "Rester connecté" session exists (a token in secure storage) - see
  /// this class's docblock. LoginScreen offers this right after a fresh password login.
  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    if (enabled) {
      await _storage.write(key: _biometricEnabledKey, value: 'true');
    } else {
      await _storage.delete(key: _biometricEnabledKey);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _storage.delete(key: _tokenStorageKey);
    await _storage.delete(key: _biometricEnabledKey);
    _biometricEnabled = false;
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

    final user =
        AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _currentUser = user;

    return user;
  }

  /// Re-fetches the current user (e.g. after a contact-email or password change) without a full
  /// re-login.
  Future<void> refreshCurrentUser() async {
    _currentUser = await _fetchCurrentUser();
    notifyListeners();
  }
}
