import 'package:flutter/services.dart';

/// Blocks screen capture while a supervised assessment is being composed.
///
/// On **Android** this is `FLAG_SECURE`: screenshots and screen recordings are refused by the
/// system, and the app's thumbnail in the task switcher turns black. A method channel rather than a
/// package: the whole native side is nine lines, and a dependency that stops being maintained is a
/// dependency that eventually blocks a Flutter upgrade.
///
/// On **iOS** the flag does not exist. Its equivalent is a veil - an opaque layer put over the
/// passation the instant the app stops being frontmost, so the app-switcher snapshot shows the veil
/// and not the paper. That half is pure Dart (see QuizTakeScreen), which is why this class quietly
/// does nothing there rather than pretending.
///
/// Neither half is a security boundary and neither is claimed to be: a phone can always be
/// photographed by another phone. What they do is make the easy gesture stop being easy.
class ScreenCaptureGuard {
  const ScreenCaptureGuard();

  static const MethodChannel _channel = MethodChannel('moncampus/screen_capture');

  /// Turns capture blocking on for the passation. Failures are swallowed: an assessment must not
  /// fail to open because a platform refused a flag.
  Future<void> enable() => _set(true);

  /// Turns it off again - the flag is the activity's, not the screen's, so leaving it on would
  /// blacken the whole app's thumbnail long after the assessment ended.
  Future<void> disable() => _set(false);

  Future<void> _set(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on PlatformException {
      // Not implemented on this platform (iOS, where the veil does the work instead).
    } on MissingPluginException {
      // The native side of an older build.
    }
  }
}
