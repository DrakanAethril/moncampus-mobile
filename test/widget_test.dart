import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moncampus_mobile/main.dart';
import 'package:moncampus_mobile/screens/login_screen.dart';
import 'package:moncampus_mobile/services/auth_service.dart';

void main() {
  testWidgets('shows the launch screen while the auth state is still resolving',
      (WidgetTester tester) async {
    // Deliberately doesn't call tryAutoLogin() (that hits secure storage + the network), so
    // AuthService stays in its initial isLoading=true state and AuthGate shows its first frame -
    // a true smoke test of the app shell wiring without needing to mock platform channels.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: const MonCampusApp(),
      ),
    );

    // The launch screen, not a spinner: it has to stay identical to the native splash the system
    // paints before the engine is up, so the handover between the two is invisible (see
    // LaunchScreen's own docblock, design_handoff_mobile 4f).
    expect(find.byType(LaunchScreen), findsOneWidget);

    // The half this test is really guarding. Reading the token from secure storage takes a moment,
    // and « not authenticated yet » must not be shown as « not authenticated »: a login screen
    // flashed at every cold start in front of somebody who is signed in is the regression here.
    expect(find.byType(LoginScreen), findsNothing);
  });
}
