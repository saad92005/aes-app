part of '../main.dart';

// ---------------- FIREBASE AUTH SERVICE ----------------
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // Employees log in with a username, but Firebase Auth needs an email -
  // so we convert the username into a fake internal email behind the scenes.
  static String _usernameToEmail(String username) => '${username.trim().toLowerCase()}@aes.local';

  static Future<AppUser> signIn(String username, String password) async {
    final email = _usernameToEmail(username);
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('Account exists but no profile found. Contact your administrator.');
    }
    final data = doc.data()!;
    if (data['active'] == false) {
      await _auth.signOut();
      throw Exception('This account has been deactivated. Contact your administrator.');
    }
    return AppUser(
      uid: uid,
      username: data['username'] ?? username,
      role: roleFromString(data['role'] ?? 'employee'),
      region: data['region'] ?? 'All',
      extraInventoryAccess: data['extraInventoryAccess'] ?? false,
    );
  }

  static Future<void> signOut() => _auth.signOut();

  // Firebase Auth persists the signed-in session across app restarts on its own - this
  // rebuilds the AppUser profile for whoever that already-persisted session belongs to,
  // without asking for a username/password again. Used to back the biometric "unlock"
  // flow: local_auth confirms it's really the device owner, this confirms the account is
  // still valid (profile still exists, not deactivated) and fills in the role/region.
  static Future<AppUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      if (data['active'] == false) {
        await _auth.signOut();
        return null;
      }
      return AppUser(
        uid: user.uid,
        username: data['username'] ?? '',
        role: roleFromString(data['role'] ?? 'employee'),
        region: data['region'] ?? 'All',
        extraInventoryAccess: data['extraInventoryAccess'] ?? false,
      );
    } catch (_) {
      // Offline or a transient Firestore hiccup - fall back to the normal login screen
      // rather than leaving the user stuck on a spinner.
      return null;
    }
  }

  // Creating a Firebase Auth account always signs the client in as that new account - on the
  // default FirebaseAuth instance that would silently kick whichever admin is currently signed
  // in out of their own session. A secondary, disposable FirebaseApp gives the new account its
  // own isolated auth state to sign into instead, so the admin's real session never moves.
  static Future<FirebaseAuth> _secondaryAuth() async {
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('employeeCreation');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(name: 'employeeCreation', options: Firebase.app().options);
    }
    return FirebaseAuth.instanceFor(app: secondaryApp);
  }

  // Used by Back Office/CEO to create new employee accounts. Designation is a free-text
  // title (e.g. "Senior Technician", "Site Supervisor") chosen per employee - unlike role, it
  // has no effect on permissions, it's purely descriptive/organizational.
  static Future<void> createEmployee({
    required String username,
    required String password,
    required UserRole role,
    required String region,
    String? designation,
    bool extraInventoryAccess = false,
  }) async {
    final email = _usernameToEmail(username);
    final secondaryAuth = await _secondaryAuth();
    final credential = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;
    await secondaryAuth.signOut();
    await _db.collection('users').doc(uid).set({
      'username': username.trim(),
      'role': roleToStringKey(role),
      'region': region,
      'designation': (designation ?? '').trim(),
      'extraInventoryAccess': extraInventoryAccess,
      'active': true,
    });
  }

  // Firebase Auth has no client-side way to overwrite another account's username/password in
  // place (that requires the Admin SDK, which needs a paid backend this app doesn't have) - so
  // "editing" credentials is really: delete the old login, create a fresh one with the new
  // username/password under the same role/region. Feels like a single edit from the UI.
  static Future<void> resetEmployeeCredentials(
    String oldUid, {
    required String newUsername,
    required String newPassword,
    required UserRole role,
    required String region,
    String? designation,
    bool extraInventoryAccess = false,
  }) async {
    await createEmployee(
      username: newUsername,
      password: newPassword,
      role: role,
      region: region,
      designation: designation,
      extraInventoryAccess: extraInventoryAccess,
    );
    await _db.collection('users').doc(oldUid).delete();
  }

  // Removes the employee's profile so they can no longer sign in or appear anywhere in the
  // app. This does not remove the underlying Firebase Auth credential (that needs the Admin
  // SDK), but it's harmless and invisible left behind - signIn() already refuses to log anyone
  // in without a matching profile doc.
  static Future<void> deleteEmployee(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  // CEO-only: fetch all employee accounts to display and manage
  static Future<List<Map<String, dynamic>>> listEmployees() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'username': data['username'] ?? '',
        'role': data['role'] ?? 'employee',
        'region': data['region'] ?? 'All',
        'designation': data['designation'] ?? '',
        'extraInventoryAccess': data['extraInventoryAccess'] ?? false,
        'active': data['active'] ?? true,
      };
    }).toList();
  }

  // CEO-only: turn access on/off for an existing employee
  static Future<void> setEmployeeActive(String uid, bool active) async {
    await _db.collection('users').doc(uid).update({'active': active});
  }

  // Edits an existing employee's role/region/designation/inventory-access-exception (e.g. a
  // promotion or a region transfer) - deliberately separate from setEmployeeActive so this
  // never accidentally touches whether the account can log in at all.
  static Future<void> updateEmployee(
    String uid, {
    required UserRole role,
    required String region,
    String? designation,
    bool extraInventoryAccess = false,
  }) async {
    await _db.collection('users').doc(uid).update({
      'role': roleToStringKey(role),
      'region': region,
      'designation': (designation ?? '').trim(),
      'extraInventoryAccess': extraInventoryAccess,
    });
  }
}

