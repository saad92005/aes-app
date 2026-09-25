part of '../main.dart';

// ---------------- PAYROLL REPORTS ----------------
// 9 report types, each exportable as CSV/Excel/PDF via the existing
// ExportService.exportRowsWithFormatChoice (rows[0] = header row) - period-scoped, picked with
// the same month selector pattern as Process Payroll.
class PayrollReportsScreen extends StatefulWidget {
  const PayrollReportsScreen({super.key});

  @override
  State<PayrollReportsScreen> createState() => _PayrollReportsScreenState();
}

class _PayrollReportsScreenState extends State<PayrollReportsScreen> {
  late DateTime _selectedMonth;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  String get _periodId =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  void _changeMonth(int delta) {
    setState(
      () => _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      ),
    );
  }

  List<PayrollRecord> get _records =>
      payrollRecordsForPeriod(_periodId)
        ..sort((a, b) => a.username.compareTo(b.username));

  // ---- 1. Payroll Summary Report ----
  List<List<String>> _payrollSummaryRows() {
    final r = _records;
    final totalGross = r.fold(0.0, (s, x) => s + x.grossSalary);
    final totalDeductions = r.fold(0.0, (s, x) => s + x.totalDeductions);
    final totalNet = r.fold(0.0, (s, x) => s + x.netSalary);
    return [
      ['Metric', 'Value'],
      ['Period', _monthLabel],
      ['Employees Paid', '${r.length}'],
      ['Total Gross Salary', totalGross.toStringAsFixed(0)],
      ['Total Deductions', totalDeductions.toStringAsFixed(0)],
      ['Total Net Salary', totalNet.toStringAsFixed(0)],
      [
        'Total Overtime Pay',
        r.fold(0.0, (s, x) => s + x.overtimePay).toStringAsFixed(0),
      ],
      [
        'Total Late Deductions',
        r.fold(0.0, (s, x) => s + x.lateDeduction).toStringAsFixed(0),
      ],
      [
        'Total Early Checkout Deductions',
        r.fold(0.0, (s, x) => s + x.earlyCheckoutDeduction).toStringAsFixed(0),
      ],
      [
        'Total Manual Deductions',
        r.fold(0.0, (s, x) => s + x.manualDeductionsTotal).toStringAsFixed(0),
      ],
    ];
  }

  // ---- 2. Employee-wise Payroll Report ----
  List<List<String>> _employeeWiseRows() {
    return [
      [
        'Employee',
        'Region',
        'Type',
        'Basic Salary',
        'Earned Basic',
        'Overtime Pay',
        'Gross',
        'Deductions',
        'Net Salary',
      ],
      for (final r in _records)
        [
          r.username,
          r.region,
          r.employeeType.label,
          r.basicSalary.toStringAsFixed(0),
          r.earnedBasicSalary.toStringAsFixed(0),
          r.overtimePay.toStringAsFixed(0),
          r.grossSalary.toStringAsFixed(0),
          r.totalDeductions.toStringAsFixed(0),
          r.netSalary.toStringAsFixed(0),
        ],
    ];
  }

  // ---- 3. Department-wise Payroll Report ----
  List<List<String>> _departmentWiseRows() {
    final byDept = <String, List<PayrollRecord>>{};
    for (final r in _records) {
      final profile = payrollProfileFor(r.username);
      final dept = profile != null && profile.department.isNotEmpty
          ? profile.department
          : 'Unassigned';
      byDept.putIfAbsent(dept, () => []).add(r);
    }
    return [
      [
        'Department',
        'Employees',
        'Total Gross',
        'Total Deductions',
        'Total Net',
      ],
      for (final entry in byDept.entries)
        [
          entry.key,
          '${entry.value.length}',
          entry.value.fold(0.0, (s, r) => s + r.grossSalary).toStringAsFixed(0),
          entry.value
              .fold(0.0, (s, r) => s + r.totalDeductions)
              .toStringAsFixed(0),
          entry.value.fold(0.0, (s, r) => s + r.netSalary).toStringAsFixed(0),
        ],
    ];
  }

  // ---- 4. Region-wise Payroll Report ----
  List<List<String>> _regionWiseRows() {
    final byRegion = <String, List<PayrollRecord>>{};
    for (final r in _records) {
      byRegion.putIfAbsent(r.region, () => []).add(r);
    }
    return [
      ['Region', 'Employees', 'Total Gross', 'Total Deductions', 'Total Net'],
      for (final entry in byRegion.entries)
        [
          entry.key,
          '${entry.value.length}',
          entry.value.fold(0.0, (s, r) => s + r.grossSalary).toStringAsFixed(0),
          entry.value
              .fold(0.0, (s, r) => s + r.totalDeductions)
              .toStringAsFixed(0),
          entry.value.fold(0.0, (s, r) => s + r.netSalary).toStringAsFixed(0),
        ],
    ];
  }

  // ---- 5. Attendance-Payroll Reconciliation Report ----
  List<List<String>> _attendanceReconciliationRows() {
    return [
      [
        'Employee',
        'Working Days',
        'Present',
        'Absent',
        'Paid Leave',
        'Unpaid Leave',
        'Holidays',
        'Late Days',
        'Early Checkout Days',
      ],
      for (final r in _records)
        [
          r.username,
          '${r.totalWorkingDays}',
          '${r.presentDays}',
          '${r.absentDays}',
          '${r.paidLeaveDays}',
          '${r.unpaidLeaveDays}',
          '${r.holidayDays}',
          '${r.lateDays}',
          '${r.earlyCheckoutDays}',
        ],
    ];
  }

  // ---- 6. Overtime Report ----
  List<List<String>> _overtimeRows() {
    final withOt = _records.where((r) => r.overtimeHours > 0).toList();
    return [
      ['Employee', 'Region', 'Overtime Hours', 'Hourly Rate', 'Overtime Pay'],
      for (final r in withOt)
        [
          r.username,
          r.region,
          r.overtimeHours.toStringAsFixed(1),
          r.hourlyRate.toStringAsFixed(2),
          r.overtimePay.toStringAsFixed(0),
        ],
    ];
  }

  // ---- 7. Deductions Report ----
  List<List<String>> _deductionsRows() {
    return [
      [
        'Employee',
        'Late Deduction',
        'Early Checkout Deduction',
        'Manual Deductions',
        'Total Deductions',
      ],
      for (final r in _records)
        [
          r.username,
          r.lateDeduction.toStringAsFixed(0),
          r.earlyCheckoutDeduction.toStringAsFixed(0),
          r.manualDeductionsTotal.toStringAsFixed(0),
          r.totalDeductions.toStringAsFixed(0),
        ],
    ];
  }

  // ---- 8. Salary History / Increment Report ----
  List<List<String>> _salaryHistoryRows() {
    final sorted = List<SalaryHistoryEntry>.from(sampleSalaryHistory)
      ..sort((a, b) => b.effectiveDateIso.compareTo(a.effectiveDateIso));
    return [
      [
        'Employee',
        'Old Salary',
        'New Salary',
        'Change',
        'Effective Date',
        'Changed By',
        'Reason',
      ],
      for (final h in sorted)
        [
          h.username,
          h.oldSalary.toStringAsFixed(0),
          h.newSalary.toStringAsFixed(0),
          (h.newSalary - h.oldSalary).toStringAsFixed(0),
          h.effectiveDateIso.split('T').first,
          h.changedByUsername,
          h.reason,
        ],
    ];
  }

  // ---- 9. Bank Transfer / Payment Advice Report ----
  List<List<String>> _bankTransferRows() {
    final bankPayments = _records.where((r) {
      final p = payrollProfileFor(r.username);
      return p != null && p.paymentMethod == 'Bank Transfer';
    }).toList();
    return [
      ['Employee', 'Bank Name', 'Account Number', 'Net Salary'],
      for (final r in bankPayments)
        [
          r.username,
          payrollProfileFor(r.username)?.bankName ?? '',
          payrollProfileFor(r.username)?.bankAccountNumber ?? '',
          r.netSalary.toStringAsFixed(0),
        ],
    ];
  }

  Future<void> _export(
    String title,
    List<List<String>> Function() rowsBuilder,
    String filenameBase,
  ) async {
    final rows = rowsBuilder();
    if (rows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data available for this report/period'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    await ExportService.exportRowsWithFormatChoice(
      context,
      title: '$title - $_monthLabel',
      rows: rows,
      filenameBase: '${filenameBase}_$_periodId',
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = <_ReportDef>[
      _ReportDef(
        'Payroll Summary',
        'Company-wide totals for the selected period.',
        Icons.summarize_outlined,
        () => _payrollSummaryRows(),
        'AES_Payroll_Summary',
      ),
      _ReportDef(
        'Employee-wise Payroll',
        'Per-employee salary breakdown.',
        Icons.people_alt_outlined,
        () => _employeeWiseRows(),
        'AES_Employee_Payroll',
      ),
      _ReportDef(
        'Department-wise Payroll',
        'Totals grouped by department.',
        Icons.apartment_outlined,
        () => _departmentWiseRows(),
        'AES_Department_Payroll',
      ),
      _ReportDef(
        'Region-wise Payroll',
        'Totals grouped by region.',
        Icons.map_outlined,
        () => _regionWiseRows(),
        'AES_Region_Payroll',
      ),
      _ReportDef(
        'Attendance-Payroll Reconciliation',
        'Attendance figures behind each payroll calculation.',
        Icons.fact_check_outlined,
        () => _attendanceReconciliationRows(),
        'AES_Attendance_Reconciliation',
      ),
      _ReportDef(
        'Overtime Report',
        'Employees with overtime hours/pay this period.',
        Icons.timer_outlined,
        () => _overtimeRows(),
        'AES_Overtime_Report',
      ),
      _ReportDef(
        'Deductions Report',
        'Late/early-checkout/manual deduction breakdown.',
        Icons.remove_circle_outline,
        () => _deductionsRows(),
        'AES_Deductions_Report',
      ),
      _ReportDef(
        'Salary History / Increments',
        'Every salary change ever recorded (all-time, not period-scoped).',
        Icons.trending_up,
        () => _salaryHistoryRows(),
        'AES_Salary_History',
      ),
      _ReportDef(
        'Bank Transfer / Payment Advice',
        'Disbursement list for Bank Transfer employees.',
        Icons.account_balance_outlined,
        () => _bankTransferRows(),
        'AES_Bank_Transfer_Advice',
      ),
    ];

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payroll Reports',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AESColors.darkGreen,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AESColors.lightGrey),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeMonth(-1),
                  ),
                  SizedBox(
                    width: 150,
                    child: Text(
                      _monthLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_records.length} payroll records for this period (Salary History report ignores this and covers all time).',
              style: const TextStyle(fontSize: 12, color: AESColors.grey),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 1000
                    ? 3
                    : (constraints.maxWidth > 650 ? 2 : 1);
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final r in reports)
                      SizedBox(
                        width:
                            (constraints.maxWidth - (14 * (cols - 1))) / cols,
                        child: _ReportCard(
                          def: r,
                          onExport: () =>
                              _export(r.title, r.rowsBuilder, r.filenameBase),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDef {
  final String title;
  final String description;
  final IconData icon;
  final List<List<String>> Function() rowsBuilder;
  final String filenameBase;
  _ReportDef(
    this.title,
    this.description,
    this.icon,
    this.rowsBuilder,
    this.filenameBase,
  );
}

class _ReportCard extends StatelessWidget {
  final _ReportDef def;
  final VoidCallback onExport;
  const _ReportCard({required this.def, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AESColors.lightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(def.icon, size: 18, color: AESColors.primaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  def.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AESColors.darkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            def.description,
            style: const TextStyle(fontSize: 12, color: AESColors.grey),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AESColors.primaryGreen,
                side: const BorderSide(color: AESColors.primaryGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
