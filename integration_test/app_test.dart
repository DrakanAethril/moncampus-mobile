import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moncampus_mobile/main.dart' as app;

/// Drives the real app against the real moncampus dev API (see lib/services/api_config.dart) -
/// this is throwaway verification tooling, not meant to become a permanent CI suite yet (no test
/// server/fixtures exist for that).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login screen renders and a valid LDAP login reaches the home screen',
      (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), 'stharaud');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'password');
    await tester.tap(find.text('Se connecter'));

    // Real network round trip (POST /api/login then GET /api/me) - give it real wall-clock time.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.textContaining('Bonjour'), findsOneWidget);
    expect(find.textContaining('THARAUD'), findsOneWidget);
  });
}
