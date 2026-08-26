package com.beaupeyrat.moncampus_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not the default FlutterActivity - local_auth's biometric prompt is an
// AndroidX BiometricPrompt, which requires a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    // FLAG_SECURE for the duration of a supervised quiz: screenshots and screen recordings are
    // refused by the system, and the app's thumbnail in the task switcher turns black.
    //
    // The flag belongs to the window, so it is set and cleared by the passation screen rather than
    // once at startup - left on, it would blacken the whole app's thumbnail forever. iOS has no
    // equivalent; there the app puts an opaque veil over the paper instead (ScreenCaptureGuard).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "moncampus/screen_capture")
            .setMethodCallHandler { call, result ->
                if (call.method != "setSecure") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val secure = call.argument<Boolean>("secure") ?: false
                runOnUiThread {
                    if (secure) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
                result.success(null)
            }
    }
}
