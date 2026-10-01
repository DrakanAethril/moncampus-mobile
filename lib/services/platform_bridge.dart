/// What the phone does through a plugin or dart:io and the browser does otherwise - the PWA build
/// (tool/build_pwa.sh) takes the web half, every other build the io half. The two files expose the
/// same three functions, and nothing else of the app needs to know which one it got.
library;

export 'platform_bridge_io.dart' if (dart.library.js_interop) 'platform_bridge_web.dart';
