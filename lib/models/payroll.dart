part of '../main.dart';

// ---------------- PAYROLL: PROFILES, SCHEDULES, SETTINGS, SALARY HISTORY ----------------
// This is a payroll-specific classification (which schedule/pay-rules an employee falls
// under), deliberately separate from UserRole (which job function/permissions they have) -
// e.g. a Back Office person and a Finance person could both be "Office Staff" for payroll
// purposes despite having completely different UserRole values.
enum EmployeeType { fieldStaff, officeStaff, executiveStaff }

extension EmployeeTypeLabel on EmployeeType {
  String get label {
    switch (this) {
      case EmployeeType.fieldStaff:
        return 'Field Staff';
      case EmployeeType.officeStaff:
        return 'Office Staff';
      case EmployeeType.executiveStaff:
        return 'Executive Staff';
    }
  }
}

enum PayrollProfileStatus { active, inactive }

extension PayrollProfileStatusLabel on PayrollProfileStatus {
  String get label =>
      this == PayrollProfileStatus.active ? 'Active' : 'Inactive';
}

// One per employee, keyed by their existing username (the same identifier Attendance/Expense/
// Leave already use) - never a duplicate employee record. Everything here is payroll-specific
// data that has no equivalent in the `users` collection (Employee Type, salary, bank info,
// joining date) - the employee's name/role/region/designation are still read from
// AuthService.listEmployees(), not copied in here.
class PayrollProfile {
  final String username;
  EmployeeType employeeType;
  String department;
  String joiningDateIso;
  double basicMonthlySalary;
  bool overtimeEligible;
  // Null = use PayrollSettings.defaultOvertimeMultiplier. Set here only when this specific
  // employee's overtime rate deliberately differs from the company default.
  double? overtimeMultiplier;
  String paymentMethod; // e.g. "Bank Transfer", "Cash"
  String? bankName;
  String? bankAccountNumber;
  PayrollProfileStatus status;
  final String createdAt;
  String updatedAt;

  PayrollProfile({
    required this.username,
    required this.employeeType,
    this.department = '',
    required this.joiningDateIso,
    required this.basicMonthlySalary,
    this.overtimeEligible = true,
    this.overtimeMultiplier,
    this.paymentMethod = 'Bank Transfer',
    this.bankName,
    this.bankAccountNumber,
    this.status = PayrollProfileStatus.active,
    String? createdAt,
    String? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String(),
       updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'username': username,
    'employeeType': employeeType.name,
    'department': department,
    'joiningDateIso': joiningDateIso,
    'basicMonthlySalary': basicMonthlySalary,
    'overtimeEligible': overtimeEligible,
    'overtimeMultiplier': overtimeMultiplier,
    'paymentMethod': paymentMethod,
    'bankName': bankName,
    'bankAccountNumber': bankAccountNumber,
    'status': status.name,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  static PayrollProfile fromMap(Map<String, dynamic> m) => PayrollProfile(
    username: m['username'] ?? '',
    employeeType: EmployeeType.values.firstWhere(
      (t) => t.name == m['employeeType'],
      orElse: () => EmployeeType.fieldStaff,
    ),
    department: m['department'] ?? '',
    joiningDateIso: m['joiningDateIso'] ?? '',
    basicMonthlySalary: (m['basicMonthlySalary'] ?? 0).toDouble(),
    overtimeEligible: m['overtimeEligible'] ?? true,
    overtimeMultiplier: (m['overtimeMultiplier'] as num?)?.toDouble(),
    paymentMethod: m['paymentMethod'] ?? 'Bank Transfer',
    bankName: m['bankName'],
    bankAccountNumber: m['bankAccountNumber'],
    status: PayrollProfileStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => PayrollProfileStatus.active,
    ),
    createdAt: m['createdAt'],
    updatedAt: m['updatedAt'],
  );
}

final List<PayrollProfile> samplePayrollProfiles = [];

PayrollProfile? payrollProfileFor(String username) {
  for (final p in samplePayrollProfiles) {
    if (p.username == username) return p;
  }
  return null;
}

// One per EmployeeType - Admin-configurable, never hard-coded into the calculation engine.
// Seeded with the 3 defaults from the spec on first use (see PayrollSettingsScreen), same
// "seed once, fully editable after" pattern as the Chart of Accounts.
class WorkingSchedule {
  final EmployeeType employeeType; // also the document id
  int startMinuteOfDay; // minutes since midnight, e.g. 9:00 AM = 540
  int endMinuteOfDay;
  int gracePeriodMinutes;
  int breakDurationMinutes;
  // ISO weekday numbers actually worked (1 = Monday ... 7 = Sunday).
  List<int> workingDays;
  bool overtimeEligible;
  // Minutes past endMinuteOfDay before overtime starts counting - lets a schedule ignore a
  // few minutes of natural drift before treating it as real overtime.
  int overtimeStartThresholdMinutes;

  WorkingSchedule({
    required this.employeeType,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    this.gracePeriodMinutes = 10,
    this.breakDurationMinutes = 60,
    List<int>? workingDays,
    this.overtimeEligible = true,
    this.overtimeStartThresholdMinutes = 0,
  }) : workingDays = workingDays ?? const [1, 2, 3, 4, 5, 6];

  String get startTimeLabel => _minutesToClock(startMinuteOfDay);
  String get endTimeLabel => _minutesToClock(endMinuteOfDay);

  Map<String, dynamic> toMap() => {
    'employeeType': employeeType.name,
    'startMinuteOfDay': startMinuteOfDay,
    'endMinuteOfDay': endMinuteOfDay,
    'gracePeriodMinutes': gracePeriodMinutes,
    'breakDurationMinutes': breakDurationMinutes,
    'workingDays': workingDays,
    'overtimeEligible': overtimeEligible,
    'overtimeStartThresholdMinutes': overtimeStartThresholdMinutes,
  };

  static WorkingSchedule fromMap(Map<String, dynamic> m) => WorkingSchedule(
    employeeType: EmployeeType.values.firstWhere(
      (t) => t.name == m['employeeType'],
      orElse: () => EmployeeType.fieldStaff,
    ),
    startMinuteOfDay: m['startMinuteOfDay'] ?? 540,
    endMinuteOfDay: m['endMinuteOfDay'] ?? 1080,
    gracePeriodMinutes: m['gracePeriodMinutes'] ?? 10,
    breakDurationMinutes: m['breakDurationMinutes'] ?? 60,
    workingDays: List<int>.from(m['workingDays'] ?? const [1, 2, 3, 4, 5, 6]),
    overtimeEligible: m['overtimeEligible'] ?? true,
    overtimeStartThresholdMinutes: m['overtimeStartThresholdMinutes'] ?? 0,
  );
}

String _minutesToClock(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final period = h >= 12 ? 'PM' : 'AM';
  final displayHour = h % 12 == 0 ? 12 : h % 12;
  return '$displayHour:${m.toString().padLeft(2, '0')} $period';
}

final List<WorkingSchedule> sampleWorkingSchedules = [];

WorkingSchedule? workingScheduleFor(EmployeeType type) {
  for (final s in sampleWorkingSchedules) {
    if (s.employeeType == type) return s;
  }
  return null;
}

List<WorkingSchedule> buildDefaultWorkingSchedules() => [
  // Field Staff: 9:00 AM - 6:00 PM
  WorkingSchedule(
    employeeType: EmployeeType.fieldStaff,
    startMinuteOfDay: 9 * 60,
    endMinuteOfDay: 18 * 60,
  ),
  // Office Staff: 9:30 AM - 6:00 PM
  WorkingSchedule(
    employeeType: EmployeeType.officeStaff,
    startMinuteOfDay: 9 * 60 + 30,
    endMinuteOfDay: 18 * 60,
  ),
  // Executive Staff: configurable - seeded the same as Office Staff as a starting point,
  // with overtime off by default (per the spec's "Executive Staff can be marked Overtime
  // Eligible = NO" example) until Admin adjusts it.
  WorkingSchedule(
    employeeType: EmployeeType.executiveStaff,
    startMinuteOfDay: 9 * 60 + 30,
    endMinuteOfDay: 18 * 60,
    overtimeEligible: false,
  ),
];

enum HourlyRateMethod { monthlyHoursDirect, daysPerMonthTimesHoursPerDay }

enum DeductionMethod { none, perMinute, hourly, fixed, progressive }

extension DeductionMethodLabel on DeductionMethod {
  String get label {
    switch (this) {
      case DeductionMethod.none:
        return 'No Deduction';
      case DeductionMethod.perMinute:
        return 'Per-Minute Deduction';
      case DeductionMethod.hourly:
        return 'Hourly Deduction';
      case DeductionMethod.fixed:
        return 'Fixed Deduction (per occurrence)';
      case DeductionMethod.progressive:
        return 'Progressive Deduction';
    }
  }
}

// Singleton (one document, id "global") - every number the calculation engine uses that isn't
// specific to one employee or one schedule lives here, so nothing is hard-coded.
class PayrollSettings {
  HourlyRateMethod hourlyRateMethod;
  double
  monthlyWorkingHours; // used when hourlyRateMethod == monthlyHoursDirect
  double
  workingDaysPerMonthForHourlyRate; // used when hourlyRateMethod == daysPerMonthTimesHoursPerDay
  double
  hoursPerWorkingDay; // used when hourlyRateMethod == daysPerMonthTimesHoursPerDay

  double payrollWorkingDaysPerMonth; // divisor for daily rate, e.g. 26

  double
  defaultOvertimeMultiplier; // 1.0 / 1.5 / 2.0 - used unless a profile overrides it

  DeductionMethod lateDeductionMethod;
  double lateDeductionPerMinuteRate; // used when method == perMinute
  double lateDeductionFixedAmount; // used when method == fixed or progressive
  int lateProgressiveFreeOccurrences; // used when method == progressive

  bool earlyCheckoutDeductionEnabled;
  DeductionMethod earlyCheckoutDeductionMethod;
  double earlyCheckoutDeductionPerMinuteRate;
  double earlyCheckoutDeductionFixedAmount;

  PayrollSettings({
    this.hourlyRateMethod = HourlyRateMethod.monthlyHoursDirect,
    this.monthlyWorkingHours = 240,
    this.workingDaysPerMonthForHourlyRate = 26,
    this.hoursPerWorkingDay = 8,
    this.payrollWorkingDaysPerMonth = 26,
    this.defaultOvertimeMultiplier = 1.5,
    this.lateDeductionMethod = DeductionMethod.none,
    this.lateDeductionPerMinuteRate = 0,
    this.lateDeductionFixedAmount = 0,
    this.lateProgressiveFreeOccurrences = 3,
    this.earlyCheckoutDeductionEnabled = false,
    this.earlyCheckoutDeductionMethod = DeductionMethod.none,
    this.earlyCheckoutDeductionPerMinuteRate = 0,
    this.earlyCheckoutDeductionFixedAmount = 0,
  });

  double get hourlyRateDivisor =>
      hourlyRateMethod == HourlyRateMethod.monthlyHoursDirect
      ? monthlyWorkingHours
      : (workingDaysPerMonthForHourlyRate * hoursPerWorkingDay);

  Map<String, dynamic> toMap() => {
    'hourlyRateMethod': hourlyRateMethod.name,
    'monthlyWorkingHours': monthlyWorkingHours,
    'workingDaysPerMonthForHourlyRate': workingDaysPerMonthForHourlyRate,
    'hoursPerWorkingDay': hoursPerWorkingDay,
    'payrollWorkingDaysPerMonth': payrollWorkingDaysPerMonth,
    'defaultOvertimeMultiplier': defaultOvertimeMultiplier,
    'lateDeductionMethod': lateDeductionMethod.name,
    'lateDeductionPerMinuteRate': lateDeductionPerMinuteRate,
    'lateDeductionFixedAmount': lateDeductionFixedAmount,
    'lateProgressiveFreeOccurrences': lateProgressiveFreeOccurrences,
    'earlyCheckoutDeductionEnabled': earlyCheckoutDeductionEnabled,
    'earlyCheckoutDeductionMethod': earlyCheckoutDeductionMethod.name,
    'earlyCheckoutDeductionPerMinuteRate': earlyCheckoutDeductionPerMinuteRate,
    'earlyCheckoutDeductionFixedAmount': earlyCheckoutDeductionFixedAmount,
  };

  static PayrollSettings fromMap(Map<String, dynamic> m) => PayrollSettings(
    hourlyRateMethod: HourlyRateMethod.values.firstWhere(
      (h) => h.name == m['hourlyRateMethod'],
      orElse: () => HourlyRateMethod.monthlyHoursDirect,
    ),
    monthlyWorkingHours: (m['monthlyWorkingHours'] ?? 240).toDouble(),
    workingDaysPerMonthForHourlyRate:
        (m['workingDaysPerMonthForHourlyRate'] ?? 26).toDouble(),
    hoursPerWorkingDay: (m['hoursPerWorkingDay'] ?? 8).toDouble(),
    payrollWorkingDaysPerMonth: (m['payrollWorkingDaysPerMonth'] ?? 26)
        .toDouble(),
    defaultOvertimeMultiplier: (m['defaultOvertimeMultiplier'] ?? 1.5)
        .toDouble(),
    lateDeductionMethod: DeductionMethod.values.firstWhere(
      (d) => d.name == m['lateDeductionMethod'],
      orElse: () => DeductionMethod.none,
    ),
    lateDeductionPerMinuteRate: (m['lateDeductionPerMinuteRate'] ?? 0)
        .toDouble(),
    lateDeductionFixedAmount: (m['lateDeductionFixedAmount'] ?? 0).toDouble(),
    lateProgressiveFreeOccurrences: m['lateProgressiveFreeOccurrences'] ?? 3,
    earlyCheckoutDeductionEnabled: m['earlyCheckoutDeductionEnabled'] ?? false,
    earlyCheckoutDeductionMethod: DeductionMethod.values.firstWhere(
      (d) => d.name == m['earlyCheckoutDeductionMethod'],
      orElse: () => DeductionMethod.none,
    ),
    earlyCheckoutDeductionPerMinuteRate:
        (m['earlyCheckoutDeductionPerMinuteRate'] ?? 0).toDouble(),
    earlyCheckoutDeductionFixedAmount:
        (m['earlyCheckoutDeductionFixedAmount'] ?? 0).toDouble(),
  );
}

PayrollSettings samplePayrollSettings = PayrollSettings();

// Append-only - a new entry every time a profile's basicMonthlySalary changes. Historical
// payroll records already store their own basicSalary snapshot at calculation time, so this
// log never needs to be consulted to keep past payroll correct - it exists purely as a
// auditable record of raise/change history (section 20).
class SalaryHistoryEntry {
  final String id;
  final String username;
  final double oldSalary;
  final double newSalary;
  final String effectiveDateIso;
  final String changedByUsername;
  final String reason;
  final String createdAt;

  SalaryHistoryEntry({
    String? id,
    required this.username,
    required this.oldSalary,
    required this.newSalary,
    required this.effectiveDateIso,
    required this.changedByUsername,
    this.reason = '',
    String? createdAt,
  }) : id = id ?? 'SALHIST-${_salaryHistoryCounter++}',
       createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'username': username,
    'oldSalary': oldSalary,
    'newSalary': newSalary,
    'effectiveDateIso': effectiveDateIso,
    'changedByUsername': changedByUsername,
    'reason': reason,
    'createdAt': createdAt,
  };

  static SalaryHistoryEntry fromMap(Map<String, dynamic> m) =>
      SalaryHistoryEntry(
        id: m['id'],
        username: m['username'] ?? '',
        oldSalary: (m['oldSalary'] ?? 0).toDouble(),
        newSalary: (m['newSalary'] ?? 0).toDouble(),
        effectiveDateIso: m['effectiveDateIso'] ?? '',
        changedByUsername: m['changedByUsername'] ?? '',
        reason: m['reason'] ?? '',
        createdAt: m['createdAt'],
      );
}

int _salaryHistoryCounter = 1;
final List<SalaryHistoryEntry> sampleSalaryHistory = [];
