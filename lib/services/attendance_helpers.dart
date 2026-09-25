part of '../main.dart';

// ---------------- ATTENDANCE ----------------
// Captures a single GPS fix at the moment of check-in/check-out (not continuous tracking -
// that would need background location permission, which is unnecessary for a daily attendance log).
Future<Position?> _captureAttendanceLocation(BuildContext context) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Please enable location services to check in/out')), backgroundColor: Colors.redAccent),
      );
    }
    return null;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Location permission is required to check in/out')), backgroundColor: Colors.redAccent),
      );
    }
    return null;
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e'), backgroundColor: Colors.redAccent),
      );
    }
    return null;
  }
}

String _todayDateString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _formatTime(String isoTimestamp) {
  final dt = DateTime.tryParse(isoTimestamp);
  if (dt == null) return isoTimestamp;
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

// Was previously fire-and-forget - launchUrl's returned success/failure was never checked, so
// a blocked popup, missing handler, or any other failure was completely silent: the button
// looked like it did nothing at all, which is exactly the reported "I can't see location when
// I click it" symptom. Now awaits the result and surfaces a real error instead of failing quietly.
Future<void> _openLocationInMaps(BuildContext context, double lat, double lng) async {
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open maps. Coordinates: $lat, $lng'), backgroundColor: Colors.redAccent),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open location: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

// Optional reason prompt shown right at the moment a check-in would be marked late -
// "Skip" (or dismissing the dialog) proceeds with no remarks, exactly like today, so this
// never blocks anyone from checking in.
Future<String?> _showLateReasonDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('You\'re checking in late'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Office hours start at 9:30 AM. Add a reason (traffic, network issue, etc.) so your manager knows why - optional.',
            style: TextStyle(fontSize: 13, color: AESColors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder(), isDense: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Skip'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? null : controller.text.trim()),
          child: Text(tr('Submit')),
        ),
      ],
    ),
  );
}

// Attendance-report admins for one specific region's record: CEO and Head of Operations
// always get every region (company-wide oversight), while Back Office and Operational
// Manager - who are normally a dedicated account per region, not one shared account - only
// get notified about their own region's attendance. An admin account explicitly set up as
// region 'All' is treated the same as CEO/Head of Operations here.
Future<Set<String>> _attendanceAdminsFor(AttendanceRecord record) async {
  final allUsers = await AuthService.listEmployees();
  const companyWideRoles = {'ceo', 'headOfOperations'};
  const regionalRoles = {'backOffice', 'operationalManager'};
  return allUsers
      .where((u) =>
          u['active'] != false &&
          u['username'] != record.employeeUsername &&
          (companyWideRoles.contains(u['role']) ||
              (regionalRoles.contains(u['role']) && (u['region'] == 'All' || u['region'] == record.region))))
      .map((u) => u['username'] as String)
      .toSet();
}

// Notifies the region-scoped attendance admins (see _attendanceAdminsFor) the moment
// someone checks in after the 9:30 AM office start time. Failures here are swallowed on
// purpose - a notification going out shouldn't be able to make check-in itself fail for the
// employee.
Future<void> _notifyAdminsOfLateCheckIn(AttendanceRecord record) async {
  try {
    final adminUsernames = await _attendanceAdminsFor(record);
    final timestamp = _formatDateTimeDisplay(DateTime.now());
    for (final admin in adminUsernames) {
      final notification = AppNotification(
        id: 'NOTIF-${_notificationCounter++}',
        recipientUsername: admin,
        title: 'Late Check-In',
        message: '${record.employeeUsername} checked in late at ${_formatTime(record.checkInAt)} (${record.region}) - office starts at 9:30 AM'
            '${record.remarks != null && record.remarks!.isNotEmpty ? ' - reason: ${record.remarks}' : ''}',
        timestamp: timestamp,
      );
      await DataService.saveNotification(notification);
    }
  } catch (_) {
    // Non-critical - the employee's check-in already succeeded, don't block on this.
  }
}

// Same region-scoped admin audience (see _attendanceAdminsFor) and same "don't let a
// notification failure affect the actual check-out" guarantee as _notifyAdminsOfLateCheckIn,
// but fires on every check-out rather than only a flagged one - full visibility into when
// each employee's day ends, not just exceptions.
Future<void> _notifyAdminsOfCheckOut(AttendanceRecord record) async {
  try {
    final adminUsernames = await _attendanceAdminsFor(record);
    final timestamp = _formatDateTimeDisplay(DateTime.now());
    for (final admin in adminUsernames) {
      final notification = AppNotification(
        id: 'NOTIF-${_notificationCounter++}',
        recipientUsername: admin,
        title: 'Check-Out',
        message: '${record.employeeUsername} checked out at ${_formatTime(record.checkOutAt!)} (${record.region})',
        timestamp: timestamp,
      );
      await DataService.saveNotification(notification);
    }
  } catch (_) {
    // Non-critical - the employee's check-out already succeeded, don't block on this.
  }
}

const List<String> _monthAbbrevs = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// The one shared "dd-MMM-yyyy HH:mm" formatter for target/completion dates - previously
// two different formats were generated in different places, which made these strings
// unreliable to parse back. New code should always go through this.
String _formatDateTimeDisplay(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}-${_monthAbbrevs[dt.month - 1]}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String _formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}

// Combined date+time picker used for setting a work order's real Target Finish deadline
// and an employee's actual completion time - both need a real DateTime, not free text.
Future<DateTime?> _pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 2),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial ?? now),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

