import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moncampus_mobile/services/auth_service.dart';

/// « Rester connecté » past the JWT's hour: the refresh token is what is remembered, it is traded
/// for the next JWT before the current one runs out, never twice at once, and signing out closes
/// the session on the server too.

String _jwt(Duration validFor) {
  String part(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000;

  return '${part({'alg': 'RS256'})}.${part({'exp': exp})}.signature';
}

class _Server {
  final requests = <http.Request>[];
  int refreshStatus = 200;
  bool offline = false;
  int _generation = 1;
  Duration tokenLifetime = const Duration(hours: 1);

  late final client = MockClient((request) async {
    if (offline) throw http.ClientException('offline');
    requests.add(request);

    switch (request.url.path) {
      case '/api/login':
        return http.Response(jsonEncode({'token': _jwt(tokenLifetime), 'refreshToken': 'mcrt_1'}), 200);
      case '/api/me':
        return http.Response(jsonEncode({'id': 1, 'username': 'prof', 'roles': ['ROLE_TEACHER']}), 200);
      case '/api/token/refresh':
        // A little latency, so two exchanges asked at once really overlap.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (refreshStatus != 200) return http.Response('{"error":"invalid_refresh_token"}', refreshStatus);
        _generation++;
        return http.Response(jsonEncode({'token': _jwt(tokenLifetime), 'refreshToken': 'mcrt_$_generation'}), 200);
      case '/api/token/revoke':
        return http.Response('', 204);
    }

    return http.Response('', 404);
  });

  List<String> get paths => requests.map((r) => r.url.path).toList();

  List<Map<String, dynamic>> bodiesTo(String path) => requests
      .where((r) => r.url.path == path)
      .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();

  Future<String?> stored(String key) => storage.read(key: key);

  test('« Rester connecté » remembers the refresh token, never the JWT, and names the app', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = _Server();
    final auth = AuthService(client: server.client);

    await auth.login('prof', 'secret', rememberMe: true);

    expect(auth.isAuthenticated, isTrue);
    expect(await stored('refresh_token'), 'mcrt_1');
    expect(await stored('jwt_token'), isNull);
    expect(server.bodiesTo('/api/login').single['client'], 'moncampus');
  });

  test('without « Rester connecté » nothing is written', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final auth = AuthService(client: _Server().client);

    await auth.login('prof', 'secret', rememberMe: false);

    expect(auth.isAuthenticated, isTrue);
    expect(await stored('refresh_token'), isNull);
  });

  test('a cold start trades the remembered refresh token and keeps the rotated one', () async {
    FlutterSecureStorage.setMockInitialValues({'refresh_token': 'mcrt_1'});
    final server = _Server();
    final auth = AuthService(client: server.client);

    await auth.tryAutoLogin();

    expect(auth.isAuthenticated, isTrue);
    expect(server.paths, ['/api/token/refresh', '/api/me']);
    expect(await stored('refresh_token'), 'mcrt_2');
  });

  test('a refused refresh token ends the remembered session', () async {
    FlutterSecureStorage.setMockInitialValues({'refresh_token': 'mcrt_1'});
    final server = _Server()..refreshStatus = 401;
    final auth = AuthService(client: server.client);

    await auth.tryAutoLogin();

    expect(auth.isAuthenticated, isFalse);
    expect(await stored('refresh_token'), isNull);
  });

  test('no network at launch keeps the remembered session for the next one', () async {
    FlutterSecureStorage.setMockInitialValues({'refresh_token': 'mcrt_1'});
    final server = _Server()..offline = true;
    final auth = AuthService(client: server.client);

    await auth.tryAutoLogin();

    expect(auth.isAuthenticated, isFalse);
    expect(auth.isLoading, isFalse);
    expect(await stored('refresh_token'), 'mcrt_1');
  });

  test('a JWT about to run out is renewed once, however many ask at the same time', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = _Server()..tokenLifetime = const Duration(minutes: 2);
    final auth = AuthService(client: server.client);
    await auth.login('prof', 'secret', rememberMe: true);
    final before = auth.token;
    server.tokenLifetime = const Duration(hours: 1);

    await Future.wait([auth.refreshIfExpiring(), auth.refreshIfExpiring(), auth.refreshIfExpiring()]);

    expect(server.paths.where((p) => p == '/api/token/refresh').length, 1);
    expect(auth.token, isNot(before));
    expect(await stored('refresh_token'), 'mcrt_2');

    // A fresh JWT is left alone.
    await auth.refreshIfExpiring();
    expect(server.paths.where((p) => p == '/api/token/refresh').length, 1);
    await auth.logout();
  });

  test('signing out closes the session on the server and forgets it here', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = _Server();
    final auth = AuthService(client: server.client);
    await auth.login('prof', 'secret', rememberMe: true);

    await auth.logout();
    await Future<void>.delayed(Duration.zero);

    expect(auth.isAuthenticated, isFalse);
    expect(server.bodiesTo('/api/token/revoke').single['refreshToken'], 'mcrt_1');
    expect(await stored('refresh_token'), isNull);
  });

  test('a JWT remembered by an older version still opens the app until its hour is up', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': _jwt(const Duration(minutes: 30))});
    final server = _Server();
    final auth = AuthService(client: server.client);

    await auth.tryAutoLogin();

    expect(auth.isAuthenticated, isTrue);
    expect(server.paths, ['/api/me']);
    await auth.logout();
  });
}
