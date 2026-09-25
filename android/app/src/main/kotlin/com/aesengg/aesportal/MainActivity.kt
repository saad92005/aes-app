package com.aesengg.aesportal

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's Android BiometricPrompt integration requires a FragmentActivity host -
// FlutterActivity alone doesn't provide one.
class MainActivity : FlutterFragmentActivity()
