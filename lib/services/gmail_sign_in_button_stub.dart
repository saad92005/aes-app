import 'package:flutter/widgets.dart';

// Non-web platforms (Android/iOS/desktop) never use this - they keep using the normal
// GoogleSignIn.signIn() popup flow, which isn't affected by the web-only FedCM/third-party
// -cookie restrictions this button exists to work around. See gmail_sign_in_button_web.dart.
Widget renderGoogleSignInButton() {
  throw UnsupportedError('Google Sign-In button rendering is only available on web.');
}
