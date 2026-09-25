part of '../main.dart';

// ---------------- HOLIDAY CALENDAR ----------------
// Company-wide or region-specific paid non-working days - PayrollEngine reads this (never
// writes it) so a public holiday is neither counted as Absent nor requires an attendance
// check-in, without needing to touch Attendance itself.
class Holiday {
  final String id; // "HOL-{n}"
  String name;
  String dateIso; // yyyy-MM-dd
  String region; // 'All' or a specific region

  Holiday({
    required this.id,
    required this.name,
    required this.dateIso,
    this.region = 'All',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'dateIso': dateIso,
    'region': region,
  };

  static Holiday fromMap(Map<String, dynamic> m) => Holiday(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    dateIso: m['dateIso'] ?? '',
    region: m['region'] ?? 'All',
  );
}

int _holidayCounter = 1;
final List<Holiday> sampleHolidays = [];
String nextHolidayId() => 'HOL-${_holidayCounter++}';

bool isHoliday(DateTime date, String region) {
  final key =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return sampleHolidays.any(
    (h) => h.dateIso == key && (h.region == 'All' || h.region == region),
  );
}

// ---------------- PAYROLL AUDIT LOG ----------------
// Append-only trail of every payroll-affecting action (profile changes, schedule/settings
// changes, calculation runs, status transitions, reopens, ad-hoc allowance/bonus/deduction
// adjustments) - "Payroll information must be restricted to authorized users" plus a full
// audit trail per the spec. Never edited or deleted, only appended to.
class PayrollAuditEntry {
  final String id; // "PAYAUDIT-{n}"
  final String action;
  final String performedByUsername;
  final String? targetUsername;
  final String? periodId;
  final String details;
  final String createdAt;

  PayrollAuditEntry({
    String? id,
    required this.action,
    required this.performedByUsername,
    this.targetUsername,
    this.periodId,
    this.details = '',
    String? createdAt,
  }) : id = id ?? 'PAYAUDIT-${_payrollAuditCounter++}',
       createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action,
    'performedByUsername': performedByUsername,
    'targetUsername': targetUsername,
    'periodId': periodId,
    'details': details,
    'createdAt': createdAt,
  };

  static PayrollAuditEntry fromMap(Map<String, dynamic> m) => PayrollAuditEntry(
    id: m['id'],
    action: m['action'] ?? '',
    performedByUsername: m['performedByUsername'] ?? '',
    targetUsername: m['targetUsername'],
    periodId: m['periodId'],
    details: m['details'] ?? '',
    createdAt: m['createdAt'],
  );
}

int _payrollAuditCounter = 1;
final List<PayrollAuditEntry> samplePayrollAuditLog = [];

// Fire-and-forget helper used by every payroll mutation point - appends locally (so the
// screen's own list/UI can reflect it immediately) and persists to Firestore. Never awaited
// by callers for its own sake; a failure here must never block the actual payroll action.
Future<void> logPayrollAudit({
  required String action,
  required String performedByUsername,
  String? targetUsername,
  String? periodId,
  String details = '',
}) async {
  final entry = PayrollAuditEntry(
    action: action,
    performedByUsername: performedByUsername,
    targetUsername: targetUsername,
    periodId: periodId,
    details: details,
  );
  samplePayrollAuditLog.add(entry);
  try {
    await DataService.savePayrollAuditEntry(entry);
  } catch (_) {
    // Audit logging must never block or fail the actual payroll operation it's recording.
  }
}
