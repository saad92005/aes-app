part of '../main.dart';

// ---------------- ATTENDANCE ----------------
// Standard office hours - checking in after this counts as Late, checking out after this
// counts as Overtime. One shared cutoff so check-in, the report, and the admin notice all
// agree on the same numbers.
const int officeStartHour = 9;
const int officeStartMinute = 30;
const int officeEndHour = 18;
const int officeEndMinute = 0;

// One record per employee per calendar day, keyed by "username_yyyy-MM-dd" so a second
// check-in the same day edits today's record instead of creating a duplicate.
class AttendanceRecord {
  final String id;
  final String employeeUsername;
  final String region;
  final String date; // yyyy-MM-dd
  final String checkInAt; // ISO 8601 timestamp
  final double? checkInLat;
  final double? checkInLng;
  String? checkOutAt;
  double? checkOutLat;
  double? checkOutLng;
  // Free-text reason captured at check-in time - primarily meant for late check-ins
  // (traffic, network issues, etc.) so a manager reviewing the Attendance Report can see
  // why, rather than just a bare "Late" chip with no context.
  String? remarks;

  AttendanceRecord({
    required this.id,
    required this.employeeUsername,
    required this.region,
    required this.date,
    required this.checkInAt,
    this.checkInLat,
    this.checkInLng,
    this.checkOutAt,
    this.checkOutLat,
    this.checkOutLng,
    this.remarks,
  });

  bool get isCheckedOut => checkOutAt != null;

  // Checked in after the 9:30 AM office start time.
  bool get isLate {
    final checkIn = DateTime.tryParse(checkInAt);
    if (checkIn == null) return false;
    final cutoff = DateTime(checkIn.year, checkIn.month, checkIn.day, officeStartHour, officeStartMinute);
    return checkIn.isAfter(cutoff);
  }

  // How long past the 6:00 PM office end time the check-out was, or null if they checked
  // out on time (or haven't checked out yet).
  Duration? get overtime {
    if (checkOutAt == null) return null;
    final checkOut = DateTime.tryParse(checkOutAt!);
    if (checkOut == null) return null;
    final cutoff = DateTime(checkOut.year, checkOut.month, checkOut.day, officeEndHour, officeEndMinute);
    if (!checkOut.isAfter(cutoff)) return null;
    return checkOut.difference(cutoff);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeUsername': employeeUsername,
        'region': region,
        'date': date,
        'checkInAt': checkInAt,
        'checkInLat': checkInLat,
        'checkInLng': checkInLng,
        'checkOutAt': checkOutAt,
        'checkOutLat': checkOutLat,
        'checkOutLng': checkOutLng,
        'remarks': remarks,
      };

  static AttendanceRecord fromMap(Map<String, dynamic> m) => AttendanceRecord(
        id: m['id'],
        employeeUsername: m['employeeUsername'] ?? '',
        region: m['region'] ?? '',
        date: m['date'] ?? '',
        checkInAt: m['checkInAt'] ?? '',
        checkInLat: (m['checkInLat'] as num?)?.toDouble(),
        checkInLng: (m['checkInLng'] as num?)?.toDouble(),
        checkOutAt: m['checkOutAt'],
        checkOutLat: (m['checkOutLat'] as num?)?.toDouble(),
        checkOutLng: (m['checkOutLng'] as num?)?.toDouble(),
        remarks: m['remarks'],
      );
}

final List<AttendanceRecord> sampleAttendance = [];

