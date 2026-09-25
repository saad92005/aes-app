import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web_gsi;

// Renders Google's own GIS "Sign in with Google" button - required (rather than our own
// styled button calling GoogleSignIn.signIn()) because Google's own recommendation for
// FedCM-compliant, reliably-restorable sessions is to let their JS own the click, and report
// the result back via GoogleSignIn.onCurrentUserChanged instead of a normal onPressed.
Widget renderGoogleSignInButton() {
  return web_gsi.renderButton(
    configuration: web_gsi.GSIButtonConfiguration(
      theme: web_gsi.GSIButtonTheme.filledBlack,
      size: web_gsi.GSIButtonSize.large,
      text: web_gsi.GSIButtonText.signinWith,
      shape: web_gsi.GSIButtonShape.pill,
    ),
  );
}
