part of '../main.dart';

// ---------------- LOCAL NOTIFICATIONS ----------------
// True push - a notification arriving even while the app is fully closed - needs a server
// component (a Cloud Function watching Firestore, calling FCM), which needs Firebase's paid
// Blaze plan. Staying on the free Spark plan, this is the closest equivalent: while the app
// is open (foreground or freshly backgrounded), it live-listens for new entries in the same
// `notifications` collection every event in the app already writes to - late check-in, leave
// applied/approved, work order assigned, expense submitted/approved, etc. (see
// lib/models/notification.dart) - and raises a real system notification for each one, so it
// still lands in the notification shade/lock screen. The real limitation: if Android has
// killed the app process after it's been closed for a while, nothing fires until it's
// reopened - there's no way around that without a server able to wake the device.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static StreamSubscription<QuerySnapshot>? _sub;
  static bool _initialized = false;
  static int _notifIdCounter = 0;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));
    _initialized = true;
  }

  // Called after every successful sign-in (password or biometric) - starts watching this
  // user's notifications for as long as the app stays open. Best-effort: a notification
  // hiccup should never block someone from getting into the app.
  static Future<void> start(String username) async {
    try {
      await _ensureInitialized();
      // Android 13+ and iOS both require an explicit runtime permission before any local
      // notification can actually be shown.
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      stop(); // guard against a stale listener left over from a previous session
      var skippedInitialSnapshot = false;
      _sub = FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUsername', isEqualTo: username)
          .snapshots()
          .listen((snapshot) {
        // Firestore reports every already-existing doc as "added" on the very first
        // snapshot - only react to ones that arrive after that, or every past notification
        // would re-fire as a fresh system notification the moment the app opens.
        if (!skippedInitialSnapshot) {
          skippedInitialSnapshot = true;
          return;
        }
        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null) continue;
          _show(data['title'] as String? ?? 'AES Portal', data['message'] as String? ?? '');
        }
      });
    } catch (_) {
      // No notification permission, or a transient Firestore/plugin issue - the app itself
      // still works fine without local notifications.
    }
  }

  static Future<void> _show(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'aes_portal_general',
      'AES Portal Notifications',
      channelDescription: 'Work order, attendance, leave, and expense alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    try {
      await _plugin.show(_notifIdCounter++, title, body, details);
    } catch (_) {}
  }

  // Called on logout, so a signed-out device stops raising notifications meant for whoever
  // logs in next on a shared device.
  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
