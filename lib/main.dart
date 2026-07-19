import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'moncampus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Switches between LoginScreen and MainShell (the 5-tab bottom nav) based on AuthService's
/// state, so nothing else in the widget tree has to think about auth/navigation itself.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return auth.isAuthenticated ? const MainShell() : const LoginScreen();
  }
}
