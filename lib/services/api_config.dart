import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Dev-only base URL resolution for the moncampus API (FrankenPHP dev server, plain HTTP - see
/// that repo's CLAUDE.md, automatic HTTPS is disabled entirely in dev). The iOS Simulator and
/// desktop targets share the host machine's network namespace, so "localhost" reaches it
/// directly; the Android emulator runs in its own network namespace where "10.0.2.2" is its
/// fixed alias for the host loopback. A real device needs the host's LAN IP instead - not handled
/// here yet, revisit once this app is tested on physical hardware.
class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2';
    }

    return 'http://localhost';
  }
}
