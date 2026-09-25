part of '../main.dart';

// ---------------- PAYROLL PROCESSING: PERIODS & RECORDS ----------------
enum PayrollPeriodStatus {
  draft,
  processing,
  pendingReview,
  approved,
  finalized,
  paid,
}

extension PayrollPeriodStatusLabel on PayrollPeriodStatus {
  String get label {
    switch (this) {
      case PayrollPeriodStatus.draft:
        return 'Draft';
      case PayrollPeriodStatus.processing:
        return 'Processing';
      case PayrollPeriodStatus.pendingReview:
        return 'Pending Review';
      case PayrollPeriodStatus.approved:
        return 'Approved';
      case PayrollPeriodStatus.finalized:
        return 'Finalized';
      case PayrollPeriodStatus.paid:
        return 'Paid';
    }
  }

  Color get color {
    switch (this) {
      case PayrollPeriodStatus.draft:
        return const Color(0xFF9A9A9A);
      case PayrollPeriodStatus.processing:
        return const Color(0xFF2196F3);
      case PayrollPeriodStatus.pendingReview:
        return const Color(0xFFFF9800);
      case PayrollPeriodStatus.approved:
        return const Color(0xFF00897B);
      case PayrollPeriodStatus.finalized:
        return const Color(0xFF2E7D32);
      case PayrollPeriodStatus.paid:
        return AESColors.primaryGreen;
    }
  }

  // Once finalized (or paid), a period is locked - its records can't be recalculated or
  // edited without an explicit "Reopen Payroll" action (see PayrollProcessingScreen).
  bool get isLocked =>
      this == PayrollPeriodStatus.finalized || this == PayrollPeriodStatus.paid;
}

// One per calendar month, company-wide (id = "yyyy-MM", e.g. "2026-09") - a single payroll run
// covering every employee, same cadence a real company runs payroll on. Individual
// PayrollRecords within it still carry each employee's own region for filtering/reporting.
class PayrollPeriod {
  final String id; // "yyyy-MM"
  final String monthLabel; // "September 2026"
  PayrollPeriodStatus status;
  final String createdAt;
  final String createdByUsername;
  String? processedAt;
  String? processedByUsername;
  String? approvedAt;
  String? approvedByUsername;
  String? finalizedAt;
  String? finalizedByUsername;
  String? paidAt;
  String? paidByUsername;
  // Bumped every time this period is reopened after being finalized - lets the audit log and
  // UI distinguish "first calculation" from "reopened and recalculated".
  int reopenCount;

  PayrollPeriod({
    required this.id,
    required this.monthLabel,
    this.status = PayrollPeriodStatus.draft,
    String? createdAt,
    required this.createdByUsername,
    this.processedAt,
    this.processedByUsername,
    this.approvedAt,
    this.approvedByUsername,
    this.finalizedAt,
    this.finalizedByUsername,
    this.paidAt,
    this.paidByUsername,
    this.reopenCount = 0,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'monthLabel': monthLabel,
    'status': status.name,
    'createdAt': createdAt,
    'createdByUsername': createdByUsername,
    'processedAt': processedAt,
    'processedByUsername': processedByUsername,
    'approvedAt': approvedAt,
    'approvedByUsername': approvedByUsername,
    'finalizedAt': finalizedAt,
    'finalizedByUsername': finalizedByUsername,
    'paidAt': paidAt,
    'paidByUsername': paidByUsername,
    'reopenCount': reopenCount,
  };

  static PayrollPeriod fromMap(Map<String, dynamic> m) => PayrollPeriod(
    id: m['id'] ?? '',
    monthLabel: m['monthLabel'] ?? '',
    status: PayrollPeriodStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => PayrollPeriodStatus.draft,
    ),
    createdAt: m['createdAt'],
    createdByUsername: m['createdByUsername'] ?? '',
    processedAt: m['processedAt'],
    processedByUsername: m['processedByUsername'],
    approvedAt: m['approvedAt'],
    approvedByUsername: m['approvedByUsername'],
    finalizedAt: m['finalizedAt'],
    finalizedByUsername: m['finalizedByUsername'],
    paidAt: m['paidAt'],
    paidByUsername: m['paidByUsername'],
    reopenCount: m['reopenCount'] ?? 0,
  );
}

final List<PayrollPeriod> samplePayrollPeriods = [];

PayrollPeriod? payrollPeriodById(String id) {
  for (final p in samplePayrollPeriods) {
    if (p.id == id) return p;
  }
  return null;
}

// A single ad-hoc allowance / bonus / deduction line added during payroll review - the
// lightweight version of sections 11-13 (dedicated allowance/bonus/deduction management with
// reusable templates is a later phase; this is the minimum needed for a real payroll run to
// actually include them now).
class PayrollLineItem {
  String label;
  double amount;
  String note;

  PayrollLineItem({required this.label, required this.amount, this.note = ''});

  Map<String, dynamic> toMap() => {
    'label': label,
    'amount': amount,
    'note': note,
  };
  static PayrollLineItem fromMap(Map<String, dynamic> m) => PayrollLineItem(
    label: m['label'] ?? '',
    amount: (m['amount'] ?? 0).toDouble(),
    note: m['note'] ?? '',
  );
}

// One per employee per PayrollPeriod - the actual computed result. Everything here is a
// snapshot at calculation time (basicSalary, employeeType, etc.) so a later change to the
// employee's profile never retroactively changes an already-processed month, per "historical
// payroll must never change" (section 20) and "payroll should not modify attendance" (25).
class PayrollRecord {
  final String id; // "{periodId}_{username}"
  final String periodId;
  final String username;
  final String region;
  final EmployeeType employeeType;
  final double basicSalary;

  // Attendance summary (read from Attendance/Leave at calculation time, never written back).
  final int totalCalendarDays;
  final int totalWorkingDays;
  final int presentDays;
  final int absentDays;
  final int paidLeaveDays;
  final int unpaidLeaveDays;
  final int holidayDays;
  final int lateDays;
  final int lateMinutesTotal;
  final int earlyCheckoutDays;
  final int earlyCheckoutMinutesTotal;
  final double totalWorkedHours;
  final double overtimeHours;

  // Calculated figures.
  final double hourlyRate;
  final double dailyRate;
  final double earnedBasicSalary;
  final double overtimePay;
  List<PayrollLineItem> allowances;
  List<PayrollLineItem> bonuses;
  List<PayrollLineItem> manualDeductions;
  final double lateDeduction;
  final double earlyCheckoutDeduction;
  final double grossSalary;
  final double totalDeductions;
  final double netSalary;

  final String calculatedAt;

  PayrollRecord({
    required this.periodId,
    required this.username,
    required this.region,
    required this.employeeType,
    required this.basicSalary,
    required this.totalCalendarDays,
    required this.totalWorkingDays,
    required this.presentDays,
    required this.absentDays,
    required this.paidLeaveDays,
    required this.unpaidLeaveDays,
    this.holidayDays = 0,
    required this.lateDays,
    required this.lateMinutesTotal,
    required this.earlyCheckoutDays,
    required this.earlyCheckoutMinutesTotal,
    required this.totalWorkedHours,
    required this.overtimeHours,
    required this.hourlyRate,
    required this.dailyRate,
    required this.earnedBasicSalary,
    required this.overtimePay,
    List<PayrollLineItem>? allowances,
    List<PayrollLineItem>? bonuses,
    List<PayrollLineItem>? manualDeductions,
    required this.lateDeduction,
    required this.earlyCheckoutDeduction,
    required this.grossSalary,
    required this.totalDeductions,
    required this.netSalary,
    String? calculatedAt,
  }) : id = '${periodId}_$username',
       allowances = allowances ?? [],
       bonuses = bonuses ?? [],
       manualDeductions = manualDeductions ?? [],
       calculatedAt = calculatedAt ?? DateTime.now().toIso8601String();

  double get allowancesTotal => allowances.fold(0.0, (s, a) => s + a.amount);
  double get bonusTotal => bonuses.fold(0.0, (s, b) => s + b.amount);
  double get manualDeductionsTotal =>
      manualDeductions.fold(0.0, (s, d) => s + d.amount);

  Map<String, dynamic> toMap() => {
    'id': id,
    'periodId': periodId,
    'username': username,
    'region': region,
    'employeeType': employeeType.name,
    'basicSalary': basicSalary,
    'totalCalendarDays': totalCalendarDays,
    'totalWorkingDays': totalWorkingDays,
    'presentDays': presentDays,
    'absentDays': absentDays,
    'paidLeaveDays': paidLeaveDays,
    'unpaidLeaveDays': unpaidLeaveDays,
    'holidayDays': holidayDays,
    'lateDays': lateDays,
    'lateMinutesTotal': lateMinutesTotal,
    'earlyCheckoutDays': earlyCheckoutDays,
    'earlyCheckoutMinutesTotal': earlyCheckoutMinutesTotal,
    'totalWorkedHours': totalWorkedHours,
    'overtimeHours': overtimeHours,
    'hourlyRate': hourlyRate,
    'dailyRate': dailyRate,
    'earnedBasicSalary': earnedBasicSalary,
    'overtimePay': overtimePay,
    'allowances': allowances.map((a) => a.toMap()).toList(),
    'bonuses': bonuses.map((b) => b.toMap()).toList(),
    'manualDeductions': manualDeductions.map((d) => d.toMap()).toList(),
    'lateDeduction': lateDeduction,
    'earlyCheckoutDeduction': earlyCheckoutDeduction,
    'grossSalary': grossSalary,
    'totalDeductions': totalDeductions,
    'netSalary': netSalary,
    'calculatedAt': calculatedAt,
  };

  static PayrollRecord fromMap(Map<String, dynamic> m) => PayrollRecord(
    periodId: m['periodId'] ?? '',
    username: m['username'] ?? '',
    region: m['region'] ?? 'All',
    employeeType: EmployeeType.values.firstWhere(
      (t) => t.name == m['employeeType'],
      orElse: () => EmployeeType.fieldStaff,
    ),
    basicSalary: (m['basicSalary'] ?? 0).toDouble(),
    totalCalendarDays: m['totalCalendarDays'] ?? 0,
    totalWorkingDays: m['totalWorkingDays'] ?? 0,
    presentDays: m['presentDays'] ?? 0,
    absentDays: m['absentDays'] ?? 0,
    paidLeaveDays: m['paidLeaveDays'] ?? 0,
    unpaidLeaveDays: m['unpaidLeaveDays'] ?? 0,
    holidayDays: m['holidayDays'] ?? 0,
    lateDays: m['lateDays'] ?? 0,
    lateMinutesTotal: m['lateMinutesTotal'] ?? 0,
    earlyCheckoutDays: m['earlyCheckoutDays'] ?? 0,
    earlyCheckoutMinutesTotal: m['earlyCheckoutMinutesTotal'] ?? 0,
    totalWorkedHours: (m['totalWorkedHours'] ?? 0).toDouble(),
    overtimeHours: (m['overtimeHours'] ?? 0).toDouble(),
    hourlyRate: (m['hourlyRate'] ?? 0).toDouble(),
    dailyRate: (m['dailyRate'] ?? 0).toDouble(),
    earnedBasicSalary: (m['earnedBasicSalary'] ?? 0).toDouble(),
    overtimePay: (m['overtimePay'] ?? 0).toDouble(),
    allowances: (m['allowances'] as List<dynamic>? ?? [])
        .map((a) => PayrollLineItem.fromMap(Map<String, dynamic>.from(a)))
        .toList(),
    bonuses: (m['bonuses'] as List<dynamic>? ?? [])
        .map((b) => PayrollLineItem.fromMap(Map<String, dynamic>.from(b)))
        .toList(),
    manualDeductions: (m['manualDeductions'] as List<dynamic>? ?? [])
        .map((d) => PayrollLineItem.fromMap(Map<String, dynamic>.from(d)))
        .toList(),
    lateDeduction: (m['lateDeduction'] ?? 0).toDouble(),
    earlyCheckoutDeduction: (m['earlyCheckoutDeduction'] ?? 0).toDouble(),
    grossSalary: (m['grossSalary'] ?? 0).toDouble(),
    totalDeductions: (m['totalDeductions'] ?? 0).toDouble(),
    netSalary: (m['netSalary'] ?? 0).toDouble(),
    calculatedAt: m['calculatedAt'],
  );
}

final List<PayrollRecord> samplePayrollRecords = [];

List<PayrollRecord> payrollRecordsForPeriod(String periodId) =>
    samplePayrollRecords.where((r) => r.periodId == periodId).toList();

PayrollRecord? payrollRecordFor(String periodId, String username) {
  for (final r in samplePayrollRecords) {
    if (r.periodId == periodId && r.username == username) return r;
  }
  return null;
}
