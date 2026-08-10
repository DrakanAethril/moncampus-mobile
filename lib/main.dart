import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/magic_link_landing_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/brand.dart';

void main() {
  // Spectral / Source Sans 3 are bundled under assets/google_fonts/ - see AppTheme's docblock.
  AppTheme.disableFontFetching();

  // Every screen has a dark navy/blue region at the very top (AppHeader's navy bar, or the
  // login gradient) - without this, Android/iOS default to an opaque status bar (often black)
  // that doesn't match, instead of letting the app's own background show through with light
  // (white) status bar icons/clock.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService()..tryAutoLogin(),
      child: const MonCampusApp(),
    ),
  );
}

class MonCampusApp extends StatelessWidget {
  const MonCampusApp({super.key});

  /// Pushing the magic-link landing screen needs a navigator that is not the one being built.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Beaupeyrat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: navigatorKey,
      home: const AuthGate(),
    );
  }
}

/// Switches between LoginScreen and MainShell (the 4-tab bottom nav) based on AuthService's
/// state, so nothing else in the widget tree has to think about auth/navigation itself.
///
/// Also the app's deep-link listener: `campusmanager://login/<token>` (design_handoff_mobile, tour
/// 6) pushes the landing screen, which trades the token for a session. Listening here rather than
/// in main() means the navigator already exists when a link arrives, including the one that cold
/// started the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleLink);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _handleLink(Uri uri) {
    if (uri.scheme != 'campusmanager' || uri.host != 'login') return;

    final token = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (token.isEmpty) return;

    // Back to the root first: a second link (a resend, a link opened twice) must replace the
    // landing screen, not stack another one on top of it.
    final navigator = MonCampusApp.navigatorKey.currentState;
    navigator?.popUntil((route) => route.isFirst);
    navigator?.push(MaterialPageRoute(
      builder: (_) => MagicLinkLandingScreen(token: token),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isLoading) {
      return const LaunchScreen();
    }

    return auth.isAuthenticated ? const MainShell() : const LoginScreen();
  }
}

/// The app's own first frame (design_handoff_mobile 4f): emblem and logotype on navy, nothing
/// else. It must stay identical to the native splash the system paints before the engine is up,
/// so the handover between the two is invisible - which is why the emblem is bare here, like the
/// launcher icon and the splash asset, rather than sitting in the ringed medallion the app bar
/// and the connexion screens use (BrandMedallion).
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Same footprint as the native splash draws it - measured, not guessed: Android 12+
            // paints the splash icon over a 288dp canvas whatever the asset's pixel size, and the
            // emblem covers 264 of its 512px, hence 148.
            Image(
              image: AssetImage('assets/brand/embleme-white.png'),
              height: 148,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 22),
            BrandWordmark.hero(),
          ],
        ),
      ),
    );
  }
}
