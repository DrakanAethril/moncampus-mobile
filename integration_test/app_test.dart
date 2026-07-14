import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moncampus_mobile/main.dart' as app;

/// Drives the real app against the real moncampus dev API (see lib/services/api_config.dart) -
/// this is throwaway verification tooling, not meant to become a permanent CI suite yet (no test
/// server/fixtures exist for that).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A bounded pumpAndSettle - the default has no real cap (10 minutes), which turns a genuine
  // hang (a stuck network call keeping a spinner alive) into a silent process-kill with no
  // diagnostics instead of a clear, fast test failure.
  Future<void> settle(WidgetTester tester, [String? step]) async {
    if (step != null) debugPrint('STEP: $step');
    await tester.pumpAndSettle(const Duration(milliseconds: 200), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 15));
  }

  testWidgets('login screen renders and a valid LDAP login reaches the home screen',
      (WidgetTester tester) async {
    app.main();
    await settle(tester, 'app launched');

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), 'stharaud');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'password');
    await tester.tap(find.text('Se connecter'));

    // Real network round trip (POST /api/login then GET /api/me) - give it real wall-clock time.
    await settle(tester, 'submitted login');

    expect(find.textContaining('Bonjour'), findsOneWidget);
    expect(find.textContaining('THARAUD'), findsOneWidget);

    // Home tab: today's timetable card should have loaded real sessions (seeded manually before
    // this run - see the memory note on how to reproduce).
    await settle(tester, 'home tab loaded');
    expect(find.text('Ma journée'), findsOneWidget);

    // Emploi du temps tab
    await tester.tap(find.text('Emploi du t.'));
    await settle(tester, 'timetable tab loaded');
    expect(find.text('Emploi du temps'), findsOneWidget);

    // Agenda tab (placeholder, no backend feature yet)
    await tester.tap(find.text('Agenda'));
    await settle(tester, 'agenda tab loaded');
    expect(find.text('Bientôt disponible'), findsOneWidget);

    // Messages tab - real thread should be there and openable
    await tester.tap(find.text('Messages'));
    await settle(tester, 'messages tab loaded');
    expect(find.text('Messagerie'), findsOneWidget);
    expect(find.textContaining('Bienvenue sur moncampus mobile'), findsOneWidget);

    await tester.tap(find.textContaining('Bienvenue sur moncampus mobile'));
    await settle(tester, 'thread detail loaded');
    expect(find.textContaining('bienvenue sur la nouvelle application mobile'), findsOneWidget);
    await tester.pageBack();
    await settle(tester, 'back to inbox');

    // Plus tab - profile + logout
    await tester.tap(find.text('Plus'));
    await settle(tester, 'plus tab loaded');
    expect(find.text('Déconnexion'), findsOneWidget);
  });
}
