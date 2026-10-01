import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

import '../models/app_user.dart';
import '../utils/jwt_expiry.dart';
import 'api_config.dart';

/// The server could not be reached to open a remembered session: kept for next time, unlike a
/// refusal.
class _SessionUnreachable implements Exception {}

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
///
/// The JWT lives an hour. What keeps the app signed in past it is the refresh token every sign-in
/// now comes with (App\Security\MobileSessions on the backend): this class trades it for the next
/// JWT five minutes before the current one runs out ([refreshIfExpiring], also called by AuthGate
/// when the app comes back to the foreground, since a timer does not run while the phone sleeps).
/// The refresh token rotates at every exchange, so exchanges are never run twice at once. With
/// « Rester connecté » it is the refresh token that goes to secure storage, never the JWT; without,
/// it lives in memory for this run of the app only - long enough for a two-hour session anyway.
class AuthService extends ChangeNotifier {
  AuthService(
      {FlutterSecureStorage? storage,
      http.Client? client,
      LocalAuthentication? localAuth})
      : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client(),
        _localAuth = localAuth ?? LocalAuthentication();

  // A JWT remembered by a version of the app older than the refresh token: read once, never written.
  static const _tokenStorageKey = 'jwt_token';
  static const _refreshTokenStorageKey = 'refresh_token';

  /// How long before the JWT runs out the next one is asked for.
  static const refreshMargin = Duration(minutes: 5);
  static const _biometricEnabledKey = 'biometric_enabled';

  final FlutterSecureStorage _storage;
  final http.Client _client;
  final LocalAuthentication _localAuth;

  String? _token;
  String? _refreshToken;
  bool _rememberRefreshToken = false;
  Future<bool>? _refreshing;
  Timer? _refreshTimer;
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
      (_token != null || _refreshToken != null) && _currentUser == null && _biometricEnabled;

  /// Read-only - other services (TimetableService, MessagingService, ...) need it to build their
  /// own Authorization headers, but only AuthService ever writes it.
  String? get token => _token;

  Future<bool> get canUseBiometrics async {
    // A browser has no biometric prompt local_auth can reach: the PWA never offers the gate.
    if (kIsWeb) return false;

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
    _refreshToken = await _storage.read(key: _refreshTokenStorageKey);
    _rememberRefreshToken = _refreshToken != null;
    // Only an app upgraded from before the refresh token still holds a bare JWT: it is used until
    // its hour is up, then the login screen comes back once and never again.
    _token = _refreshToken == null ? await _storage.read(key: _tokenStorageKey) : null;
    _biometricEnabled =
        (await _storage.read(key: _biometricEnabledKey)) == 'true';

    if ((_token != null || _refreshToken != null) && !_biometricEnabled) {
      try {
        await _openStoredSession();
      } on AuthException {
        await logout();
      } catch (_) {
        // No network at launch: the stored session is kept for the next launch, and the login
        // screen shows meanwhile.
        _token = null;
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
      await _openStoredSession();
      notifyListeners();
      return true;
    } on _SessionUnreachable {
      return false;
    } catch (_) {
      await logout();
      return false;
    }
  }

  /// A remembered session becomes a signed-in one: a JWT first when only the refresh token was
  /// kept, then the user it belongs to.
  Future<void> _openStoredSession() async {
    if (_token == null && !await _refresh()) {
      throw _SessionUnreachable();
    }
    await _fetchCurrentUser();
    _scheduleRefresh();
  }

  Future<void> login(String username, String password,
      {required bool rememberMe}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password, 'client': ApiConfig.clientName}),
    );

    if (response.statusCode != 200) {
      throw AuthException('Identifiant ou mot de passe incorrect.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _token = body['token'] as String;
    _refreshToken = body['refreshToken'] as String?;
    _rememberRefreshToken = rememberMe;
    await _storage.delete(key: _tokenStorageKey);

    if (rememberMe) {
      await _storeRefreshToken();
    } else {
      // Drops any token remembered by a previous, since-abandoned "Rester connecté" session -
      // otherwise the next cold start would silently restore it despite this explicit opt-out.
      await _storage.delete(key: _refreshTokenStorageKey);
      await setBiometricEnabled(false);
    }

    await _fetchCurrentUser();
    _scheduleRefresh();
    notifyListeners();
  }

  /// Adopts a JWT obtained outside the identifiant/mot de passe form - today only the magic link
  /// (design_handoff_mobile, tour 6), whose token App\Controller\Api\MagicLoginController has
  /// already traded for this one. Always remembered: the whole point of the link is not to have to
  /// prove anything again next time, and the biometric prompt of 6c is offered right after.
  Future<void> adoptToken(String token, {String? refreshToken}) async {
    _token = token;
    _refreshToken = refreshToken;
    _rememberRefreshToken = true;
    await _storage.delete(key: _tokenStorageKey);
    await _storeRefreshToken();
    await _fetchCurrentUser();
    _scheduleRefresh();
    notifyListeners();
  }

  /// Asks for the next JWT if the current one runs out within [refreshMargin] - the timer's job,
  /// and AuthGate's when the app comes back to the foreground after the timer could not run.
  Future<void> refreshIfExpiring() async {
    if (_refreshToken == null || _currentUser == null) return;
    final expiry = _token == null ? null : jwtExpiry(_token!);
    if (expiry != null && expiry.isAfter(DateTime.now().add(refreshMargin))) return;

    try {
      if (await _refresh()) {
        _scheduleRefresh();
        notifyListeners();
      }
    } on AuthException {
      // Refused: logout() has already sent the app back to the login screen.
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    final expiry = _token == null ? null : jwtExpiry(_token!);
    if (expiry == null) return;

    if (_refreshToken == null) {
      // The bare JWT of an older app: nothing can renew it, so the session ends with it.
      _refreshTimer = Timer(_delayUntil(expiry), logout);
      return;
    }
    _refreshTimer = Timer(_delayUntil(expiry.subtract(refreshMargin)), () async {
      try {
        if (!await _refresh()) {
          // No network: try again in a minute.
          _refreshTimer = Timer(const Duration(minutes: 1), refreshIfExpiring);
          return;
        }
      } on AuthException {
        return;
      }
      _scheduleRefresh();
      notifyListeners();
    });
  }

  Duration _delayUntil(DateTime at) {
    final delay = at.difference(DateTime.now());

    return delay.isNegative ? Duration.zero : delay;
  }

  /// One exchange at a time: the refresh token rotates, so a second exchange running alongside
  /// would present a token the first one just replaced - which the server reads as a replay.
  Future<bool> _refresh() => _refreshing ??= _exchangeRefreshToken().whenComplete(() => _refreshing = null);

  /// True with a new pair in hand; false when the server could not be reached. A refusal (expired,
  /// revoked, deactivated account) ends the session and throws [AuthException].
  Future<bool> _exchangeRefreshToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;

    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/token/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
    } catch (_) {
      return false;
    }

    if (response.statusCode == 401) {
      await logout(revoke: false);
      throw AuthException('Session expirée.');
    }
    if (response.statusCode != 200) return false;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _token = body['token'] as String;
    _refreshToken = body['refreshToken'] as String;
    await _storeRefreshToken();

    return true;
  }

  Future<void> _storeRefreshToken() async {
    if (_rememberRefreshToken && _refreshToken != null) {
      await _storage.write(key: _refreshTokenStorageKey, value: _refreshToken);
    }
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

  /// Signs out here, and closes the session on the server too (unless it is already gone): a
  /// refresh token forgotten by the app but still valid would otherwise stay usable for 30 days.
  Future<void> logout({bool revoke = true}) async {
    final refreshToken = _refreshToken;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _token = null;
    _refreshToken = null;
    _currentUser = null;
    if (revoke && refreshToken != null) {
      unawaited(_client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/token/revoke'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 5))
          .then((_) {}, onError: (_) {}));
    }
    await _storage.delete(key: _tokenStorageKey);
    await _storage.delete(key: _refreshTokenStorageKey);
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
