import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'dart:io' show Platform;

/// Base URL resolution for the moncampus API.
///
/// Production builds must pass the real domain at compile time:
///   flutter build apk --release --dart-define=API_BASE_URL=https://your-domain.tld
///
/// The PWA (tool/build_pwa.sh) is the exception: a release web build is served by moncampus itself,
/// so it calls the origin it was loaded from and is never given API_BASE_URL.
///
/// Without that flag, this falls back to the dev-only addresses (FrankenPHP dev server, plain
/// HTTP - see that repo's CLAUDE.md, automatic HTTPS is disabled entirely in dev). The iOS
/// Simulator and desktop targets share the host machine's network namespace, so "localhost"
/// reaches it directly; the Android emulator runs in its own network namespace where "10.0.2.2"
/// is its fixed alias for the host loopback. A real device on dev still needs the host's LAN IP
/// instead - not handled here, pass --dart-define=API_BASE_URL=http://<lan-ip> for that case too.
class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) {
      return _override;
    }

    if (kIsWeb) {
      // `flutter run -d chrome` serves the app from a port of its own, which is not the API.
      return kReleaseMode ? Uri.base.origin : 'http://localhost';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2';
    }

    return 'http://localhost';
  }

  /// What the app declares itself as at sign-in (`client`): « Mon profil » lists the PWA's
  /// sessions apart from the phone's (App\Enum\MobileApp).
  static String get clientName => kIsWeb ? 'moncampus-web' : 'moncampus';
}
