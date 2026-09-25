part of '../main.dart';

// ---------------- PAYROLL CALCULATION ENGINE ----------------
// The one place attendance/leave data gets turned into a salary figure. Pure computation - it
// never writes to Attendance or Leave (see architecture rule: Attendance is the source of
// truth for check-in/out, Payroll is the source of truth for salary - Payroll only ever READS
// the former). Called once per employee per period by PayrollProcessingScreen; the result is a
// PayrollRecord that can be freely re-run (recalculated) until the period is finalized, and is
// otherwise a frozen snapshot - a later change to the employee's basic salary or the working
// schedule never retroactively changes an already-calculated month.
class PayrollEngine {
  // Computes one employee's full payroll record for the given month. `monthStart` should be
  // the 1st of the payroll month; this reads exactly that calendar month's attendance/leave.
  // `asOf` is normally DateTime.now() - it stops counting present/absent/leave beyond today for
  // the current, still-in-progress month (so a payroll run mid-September doesn't mark the rest
  // of September as absent) - pass an explicit later date only in tests.
  static PayrollRecord calculate({
    required String periodId,
    required DateTime monthStart,
    required String username,
    required String region,
    required PayrollProfile profile,
    required WorkingSchedule schedule,
    required PayrollSettings settings,
    required List<AttendanceRecord> employeeAttendance,
    required List<LeaveRequest> employeeApprovedLeave,
    DateTime? asOf,
    List<PayrollLineItem>? carryAllowances,
    List<PayrollLineItem>? carryBonuses,
    List<PayrollLineItem>? carryManualDeductions,
  }) {
    final now = asOf ?? DateTime.now();
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final joiningDate = DateTime.tryParse(profile.joiningDateIso);

    final attendanceByDate = <String, AttendanceRecord>{
      for (final a in employeeAttendance) a.date: a,
    };

    String? approvedLeaveTypeOn(DateTime date) {
      for (final l in employeeApprovedLeave) {
        final start = DateTime.tryParse(l.startDate);
        final end = DateTime.tryParse(l.endDate);
        if (start == null || end == null) continue;
        if (!date.isBefore(start) && !date.isAfter(end)) return l.leaveType;
      }
      return null;
    }

    int totalWorkingDays = 0;
    int presentDays = 0;
    int absentDays = 0;
    int paidLeaveDays = 0;
    int unpaidLeaveDays = 0;
    int holidayDays = 0;
    int lateDays = 0;
    int lateMinutesTotal = 0;
    int earlyCheckoutDays = 0;
    int earlyCheckoutMinutesTotal = 0;
    double totalWorkedHours = 0;
    double overtimeHours = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthStart.year, monthStart.month, day);
      if (date.isAfter(now)) continue; // Future day - nothing to count yet.
      // Employee joined after this day, or (if joiningDate is unparseable) treat as always
      // employed rather than silently excluding every day.
      if (joiningDate != null &&
          date.isBefore(
            DateTime(joiningDate.year, joiningDate.month, joiningDate.day),
          ))
        continue;
      if (!schedule.workingDays.contains(date.weekday))
        continue; // Weekly off day.
      // Public/company holiday - a paid non-working day, distinct from a weekly off. Counted
      // separately from totalWorkingDays (which represents days the employee was actually
      // expected to work) but still paid, via earnedBasicSalary below.
      if (isHoliday(date, region)) {
        holidayDays++;
        continue;
      }

      totalWorkingDays++;
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final record = attendanceByDate[dateKey];

      if (record != null && record.checkInAt.isNotEmpty) {
        presentDays++;
        final checkIn = DateTime.tryParse(record.checkInAt);
        if (checkIn != null) {
          final scheduledStart = DateTime(
            date.year,
            date.month,
            date.day,
          ).add(Duration(minutes: schedule.startMinuteOfDay));
          final lateMinutes =
              checkIn.difference(scheduledStart).inMinutes -
              schedule.gracePeriodMinutes;
          if (lateMinutes > 0) {
            lateDays++;
            lateMinutesTotal += lateMinutes;
          }

          if (record.checkOutAt != null) {
            final checkOut = DateTime.tryParse(record.checkOutAt!);
            if (checkOut != null && checkOut.isAfter(checkIn)) {
              totalWorkedHours += checkOut.difference(checkIn).inMinutes / 60.0;

              // Scheduled end anchored to the check-in's own date, then compared with full
              // DateTime arithmetic (not modular minute-of-day) - this handles an overnight
              // shift correctly without special-casing it, since a checkout after midnight is
              // just a later DateTime, not a smaller one.
              final scheduledEnd = DateTime(
                date.year,
                date.month,
                date.day,
              ).add(Duration(minutes: schedule.endMinuteOfDay));
              final earlyMinutes = scheduledEnd.difference(checkOut).inMinutes;
              if (earlyMinutes > 0) {
                earlyCheckoutDays++;
                earlyCheckoutMinutesTotal += earlyMinutes;
              }
              final otMinutes =
                  checkOut.difference(scheduledEnd).inMinutes -
                  schedule.overtimeStartThresholdMinutes;
              if (otMinutes > 0 &&
                  profile.overtimeEligible &&
                  schedule.overtimeEligible) {
                overtimeHours += otMinutes / 60.0;
              }
            }
          }
        }
      } else {
        final leaveType = approvedLeaveTypeOn(date);
        if (leaveType == null) {
          absentDays++;
        } else if (leaveType == 'Unpaid') {
          unpaidLeaveDays++;
        } else {
          paidLeaveDays++;
        }
      }
    }

    final hourlyRate = settings.hourlyRateDivisor > 0
        ? profile.basicMonthlySalary / settings.hourlyRateDivisor
        : 0.0;
    final dailyRate = settings.payrollWorkingDaysPerMonth > 0
        ? profile.basicMonthlySalary / settings.payrollWorkingDaysPerMonth
        : 0.0;
    final earnedBasicSalary =
        dailyRate * (presentDays + paidLeaveDays + holidayDays);

    final otMultiplier =
        profile.overtimeMultiplier ?? settings.defaultOvertimeMultiplier;
    final overtimePay = profile.overtimeEligible
        ? hourlyRate * overtimeHours * otMultiplier
        : 0.0;

    double deductionFor(
      DeductionMethod method,
      int minutesTotal,
      int occurrences,
      double perMinuteRate,
      double fixedAmount,
      int freeOccurrences,
    ) {
      switch (method) {
        case DeductionMethod.none:
          return 0;
        case DeductionMethod.perMinute:
          return minutesTotal * perMinuteRate;
        case DeductionMethod.hourly:
          return (minutesTotal / 60.0) * hourlyRate;
        case DeductionMethod.fixed:
          return occurrences * fixedAmount;
        case DeductionMethod.progressive:
          final billable = occurrences - freeOccurrences;
          return billable > 0 ? billable * fixedAmount : 0;
      }
    }

    final lateDeduction = deductionFor(
      settings.lateDeductionMethod,
      lateMinutesTotal,
      lateDays,
      settings.lateDeductionPerMinuteRate,
      settings.lateDeductionFixedAmount,
      settings.lateProgressiveFreeOccurrences,
    );
    final earlyCheckoutDeduction = settings.earlyCheckoutDeductionEnabled
        ? deductionFor(
            settings.earlyCheckoutDeductionMethod,
            earlyCheckoutMinutesTotal,
            earlyCheckoutDays,
            settings.earlyCheckoutDeductionPerMinuteRate,
            settings.earlyCheckoutDeductionFixedAmount,
            0,
          )
        : 0.0;

    final allowances = carryAllowances ?? <PayrollLineItem>[];
    final bonuses = carryBonuses ?? <PayrollLineItem>[];
    final manualDeductions = carryManualDeductions ?? <PayrollLineItem>[];
    final allowancesTotal = allowances.fold(0.0, (s, a) => s + a.amount);
    final bonusTotal = bonuses.fold(0.0, (s, b) => s + b.amount);
    final manualDeductionsTotal = manualDeductions.fold(
      0.0,
      (s, d) => s + d.amount,
    );

    final grossSalary =
        earnedBasicSalary + overtimePay + allowancesTotal + bonusTotal;
    final totalDeductions =
        lateDeduction + earlyCheckoutDeduction + manualDeductionsTotal;
    // Negative salary prevention (section 23) - a month with enormous manual deductions can
    // never produce a negative net salary; it floors at zero instead.
    final netSalary = (grossSalary - totalDeductions) < 0
        ? 0.0
        : (grossSalary - totalDeductions);

    return PayrollRecord(
      periodId: periodId,
      username: username,
      region: region,
      employeeType: profile.employeeType,
      basicSalary: profile.basicMonthlySalary,
      totalCalendarDays: daysInMonth,
      totalWorkingDays: totalWorkingDays,
      presentDays: presentDays,
      absentDays: absentDays,
      paidLeaveDays: paidLeaveDays,
      unpaidLeaveDays: unpaidLeaveDays,
      holidayDays: holidayDays,
      lateDays: lateDays,
      lateMinutesTotal: lateMinutesTotal,
      earlyCheckoutDays: earlyCheckoutDays,
      earlyCheckoutMinutesTotal: earlyCheckoutMinutesTotal,
      totalWorkedHours: totalWorkedHours,
      overtimeHours: overtimeHours,
      hourlyRate: hourlyRate,
      dailyRate: dailyRate,
      earnedBasicSalary: earnedBasicSalary,
      overtimePay: overtimePay,
      allowances: allowances,
      bonuses: bonuses,
      manualDeductions: manualDeductions,
      lateDeduction: lateDeduction,
      earlyCheckoutDeduction: earlyCheckoutDeduction,
      grossSalary: grossSalary,
      totalDeductions: totalDeductions,
      netSalary: netSalary,
    );
  }
}
