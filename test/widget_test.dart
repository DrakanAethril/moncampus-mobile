import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moncampus_mobile/main.dart';
import 'package:moncampus_mobile/services/auth_service.dart';

void main() {
  testWidgets('shows a loading indicator before auth state resolves',
      (WidgetTester tester) async {
    // Deliberately doesn't call tryAutoLogin() (that hits secure storage + the network), so
    // AuthService stays in its initial isLoading=true state and AuthGate shows the spinner - a
    // true smoke test of the app shell wiring without needing to mock platform channels.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: const MonCampusApp(),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
