package com.beaupeyrat.moncampus_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not the default FlutterActivity - local_auth's biometric prompt is an
// AndroidX BiometricPrompt, which requires a FragmentActivity host.
class MainActivity: FlutterFragmentActivity()
