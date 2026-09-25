part of '../main.dart';

// ---------------- BIOMETRIC LOGIN (FINGERPRINT / FACE ID) ----------------
// Firebase Auth already keeps a user signed in across app restarts on its own - the
// biometric prompt here is purely a local device-level gate in front of that already-valid
// session (see AuthService.restoreSession), not a second credential store. Nothing about the
// account's actual username/password is ever read or written by this class.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> get isAvailable async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      // Any platform-channel hiccup (e.g. running on a platform without biometric support
      // at all) should just mean "not available", never crash the login screen.
      return false;
    }
  }

  static Future<bool> authenticate({String reason = 'Sign in to AES Portal'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  static String _prefKey(String uid) => 'biometric_login_enabled_$uid';

  static Future<bool> isEnabledFor(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey(uid)) ?? false;
  }

  static Future<void> setEnabledFor(String uid, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(uid), enabled);
  }

  // So the "enable biometric login?" prompt only ever shows once per account, even if the
  // user dismisses it with "Not now" rather than explicitly turning it on.
  static Future<bool> wasPromptedFor(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_login_prompted_$uid') ?? false;
  }

  static Future<void> markPromptedFor(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_login_prompted_$uid', true);
  }
}
