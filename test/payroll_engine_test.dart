import 'package:flutter_test/flutter_test.dart';

import 'package:al_aresh_app/main.dart';

// September 2025 starts on a Monday. With the default Mon-Sat working week it has
// 26 working days (Sundays 7, 14, 21, 28 are off), which matches the default
// payrollWorkingDaysPerMonth of 26 - so a perfect month earns exactly the basic salary.
final month = DateTime(2025, 9, 1);
final endOfMonth = DateTime(2025, 9, 30, 23, 59);
const salary = 52000.0; // daily rate 2000, hourly rate 52000 / 240

final schedule = WorkingSchedule(
  employeeType: EmployeeType.officeStaff,
  startMinuteOfDay: 9 * 60,
  endMinuteOfDay: 17 * 60,
  gracePeriodMinutes: 10,
);

PayrollProfile profile({
  String joining = '2024-01-01',
  bool overtimeEligible = true,
}) =>
    PayrollProfile(
      username: 'test.user',
      employeeType: EmployeeType.officeStaff,
      joiningDateIso: joining,
      basicMonthlySalary: salary,
      overtimeEligible: overtimeEligible,
    );

String key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<DateTime> workingDays() => [
      for (int d = 1; d <= 30; d++)
        if (DateTime(2025, 9, d).weekday != DateTime.sunday) DateTime(2025, 9, d),
    ];

AttendanceRecord punch(DateTime day, {int inMin = 9 * 60, int? outMin = 17 * 60}) {
  final base = DateTime(day.year, day.month, day.day);
  return AttendanceRecord(
    id: key(day),
    employeeUsername: 'test.user',
    region: 'Lahore',
    date: key(day),
    checkInAt: base.add(Duration(minutes: inMin)).toIso8601String(),
    checkOutAt: outMin == null ? null : base.add(Duration(minutes: outMin)).toIso8601String(),
  );
}

LeaveRequest leave(String type, String start, String end) => LeaveRequest(
      id: '$type-$start',
      employeeUsername: 'test.user',
      region: 'Lahore',
      leaveType: type,
      startDate: start,
      endDate: end,
      status: LeaveStatus.approved,
      submittedAt: '2025-08-01',
    );

PayrollRecord run({
  List<AttendanceRecord> attendance = const [],
  List<LeaveRequest> leaves = const [],
  PayrollSettings? settings,
  PayrollProfile? employee,
  DateTime? asOf,
  List<PayrollLineItem>? manualDeductions,
}) =>
    PayrollEngine.calculate(
      periodId: '2025-09',
      monthStart: month,
      username: 'test.user',
      region: 'Lahore',
      profile: employee ?? profile(),
      schedule: schedule,
      settings: settings ?? PayrollSettings(),
      employeeAttendance: attendance,
      employeeApprovedLeave: leaves,
      asOf: asOf ?? endOfMonth,
      carryManualDeductions: manualDeductions,
    );

void main() {
  setUp(sampleHolidays.clear);

  test('a perfect month earns exactly the basic salary', () {
    final r = run(attendance: workingDays().map(punch).toList());
    expect(r.totalWorkingDays, 26);
    expect(r.presentDays, 26);
    expect(r.absentDays, 0);
    expect(r.lateDays, 0);
    expect(r.dailyRate, 2000);
    expect(r.netSalary, closeTo(salary, 0.001));
  });

  test('days with no attendance and no leave are absent and unpaid', () {
    final days = workingDays();
    final r = run(attendance: days.take(20).map(punch).toList());
    expect(r.presentDays, 20);
    expect(r.absentDays, 6);
    expect(r.earnedBasicSalary, 20 * 2000);
  });

  test('approved paid leave is paid, unpaid leave is not', () {
    final days = workingDays();
    final r = run(
      attendance: days.skip(4).map(punch).toList(), // misses Sep 1-4
      leaves: [leave('Annual', '2025-09-01', '2025-09-02'), leave('Unpaid', '2025-09-03', '2025-09-04')],
    );
    expect(r.paidLeaveDays, 2);
    expect(r.unpaidLeaveDays, 2);
    expect(r.absentDays, 0);
    expect(r.earnedBasicSalary, (22 + 2) * 2000);
  });

  test('lateness beyond the grace period is deducted per minute', () {
    final days = workingDays();
    final r = run(
      // Sep 1: in at 09:25 -> 25 min late minus 10 min grace = 15 billable minutes.
      attendance: [punch(days.first, inMin: 9 * 60 + 25), ...days.skip(1).map(punch)],
      settings: PayrollSettings(
        lateDeductionMethod: DeductionMethod.perMinute,
        lateDeductionPerMinuteRate: 10,
      ),
    );
    expect(r.lateDays, 1);
    expect(r.lateMinutesTotal, 15);
    expect(r.lateDeduction, 150);
    expect(r.netSalary, closeTo(salary - 150, 0.001));
  });

  test('arriving inside the grace period is not late', () {
    final days = workingDays();
    final r = run(attendance: [punch(days.first, inMin: 9 * 60 + 10), ...days.skip(1).map(punch)]);
    expect(r.lateDays, 0);
  });

  test('progressive deduction forgives the first N late days', () {
    final days = workingDays();
    final r = run(
      attendance: [
        ...days.take(5).map((d) => punch(d, inMin: 9 * 60 + 30)),
        ...days.skip(5).map(punch),
      ],
      settings: PayrollSettings(
        lateDeductionMethod: DeductionMethod.progressive,
        lateDeductionFixedAmount: 500,
        lateProgressiveFreeOccurrences: 3,
      ),
    );
    expect(r.lateDays, 5);
    expect(r.lateDeduction, 2 * 500);
  });

  test('overtime is paid at the multiplier, only for eligible employees', () {
    final days = workingDays();
    final attendance = [punch(days.first, outMin: 19 * 60), ...days.skip(1).map(punch)];

    final eligible = run(attendance: attendance);
    expect(eligible.overtimeHours, 2);
    expect(eligible.overtimePay, closeTo(salary / 240 * 2 * 1.5, 0.001));

    final notEligible = run(attendance: attendance, employee: profile(overtimeEligible: false));
    expect(notEligible.overtimePay, 0);
  });

  test('early checkout is only deducted when enabled', () {
    final days = workingDays();
    final attendance = [punch(days.first, outMin: 16 * 60), ...days.skip(1).map(punch)];
    expect(run(attendance: attendance).earlyCheckoutDeduction, 0);

    final r = run(
      attendance: attendance,
      settings: PayrollSettings(
        earlyCheckoutDeductionEnabled: true,
        earlyCheckoutDeductionMethod: DeductionMethod.fixed,
        earlyCheckoutDeductionFixedAmount: 300,
      ),
    );
    expect(r.earlyCheckoutDays, 1);
    expect(r.earlyCheckoutMinutesTotal, 60);
    expect(r.earlyCheckoutDeduction, 300);
  });

  test('days before the joining date are not counted', () {
    final r = run(employee: profile(joining: '2025-09-15'));
    // Sep 15-30 minus Sundays 21 and 28 = 14 working days, all absent.
    expect(r.totalWorkingDays, 14);
    expect(r.absentDays, 14);
  });

  test('a mid-month run does not mark future days absent', () {
    final r = run(asOf: DateTime(2025, 9, 10, 12));
    // Sep 1-10 minus Sunday 7 = 9 working days.
    expect(r.totalWorkingDays, 9);
    expect(r.absentDays, 9);
  });

  test('a public holiday is paid but not a working day', () {
    sampleHolidays.add(Holiday(id: 'h1', name: 'Test holiday', dateIso: '2025-09-05'));
    final days = workingDays().where((d) => d.day != 5);
    final r = run(attendance: days.map(punch).toList());
    expect(r.holidayDays, 1);
    expect(r.totalWorkingDays, 25);
    expect(r.absentDays, 0);
    expect(r.netSalary, closeTo(salary, 0.001));
  });

  test('net salary never goes negative', () {
    final r = run(manualDeductions: [PayrollLineItem(label: 'Advance recovery', amount: 1e6)]);
    expect(r.netSalary, 0);
  });
}
