part of '../main.dart';

// ---------------- PROCESS PAYROLL ----------------
// One payroll run per calendar month, company-wide. Draft -> Processing -> Pending Review ->
// Approved -> Finalized -> Paid, with an explicit Reopen action (CEO only) once
// Finalized/Paid - see PayrollPeriodStatus.isLocked. Calculating never touches Attendance or
// Leave records; it only reads them (PayrollEngine.calculate).
class ProcessPayrollScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const ProcessPayrollScreen({
    super.key,
    required this.currentUser,
    required this.perms,
  });

  @override
  State<ProcessPayrollScreen> createState() => _ProcessPayrollScreenState();
}

class _ProcessPayrollScreenState extends State<ProcessPayrollScreen> {
  late DateTime _selectedMonth;
  bool _calculating = false;
  bool _busy = false;

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

  PayrollPeriod? get _period => payrollPeriodById(_periodId);

  void _changeMonth(int deltaMonths) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + deltaMonths,
      );
    });
  }

  Future<void> _calculatePayroll() async {
    if (_calculating) return;
    setState(() => _calculating = true);
    try {
      var period = _period;
      final existingRecords = payrollRecordsForPeriod(_periodId);
      final carryLineItems = <String, PayrollRecord>{
        for (final r in existingRecords) r.username: r,
      };

      final activeProfiles = samplePayrollProfiles
          .where((p) => p.status == PayrollProfileStatus.active)
          .toList();
      final results = <PayrollRecord>[];

      for (final profile in activeProfiles) {
        final schedule = workingScheduleFor(profile.employeeType);
        if (schedule == null)
          continue; // No schedule configured for this employee type yet.
        final allEmployees = await AuthService.listEmployees();
        Map<String, dynamic>? employee;
        for (final e in allEmployees) {
          if (e['username'] == profile.username) {
            employee = e;
            break;
          }
        }
        final region = employee != null
            ? (employee['region'] ?? 'All') as String
            : 'All';
        final employeeAttendance = sampleAttendance
            .where((a) => a.employeeUsername == profile.username)
            .toList();
        final employeeApprovedLeave = sampleLeaves
            .where(
              (l) =>
                  l.employeeUsername == profile.username &&
                  l.status == LeaveStatus.approved,
            )
            .toList();
        final carry = carryLineItems[profile.username];

        final record = PayrollEngine.calculate(
          periodId: _periodId,
          monthStart: _selectedMonth,
          username: profile.username,
          region: region,
          profile: profile,
          schedule: schedule,
          settings: samplePayrollSettings,
          employeeAttendance: employeeAttendance,
          employeeApprovedLeave: employeeApprovedLeave,
          carryAllowances: carry?.allowances,
          carryBonuses: carry?.bonuses,
          carryManualDeductions: carry?.manualDeductions,
        );
        results.add(record);
        await DataService.savePayrollRecord(record);
      }

      period ??= PayrollPeriod(
        id: _periodId,
        monthLabel: _monthLabel,
        createdByUsername: widget.currentUser.username,
      );
      if (period.status == PayrollPeriodStatus.draft)
        period.status = PayrollPeriodStatus.processing;
      period.processedAt = DateTime.now().toIso8601String();
      period.processedByUsername = widget.currentUser.username;
      await DataService.savePayrollPeriod(period);
      await logPayrollAudit(
        action: 'Payroll Calculated',
        performedByUsername: widget.currentUser.username,
        periodId: _periodId,
        details: 'Calculated for ${results.length} employees',
      );

      if (mounted) {
        setState(() {
          samplePayrollRecords.removeWhere((r) => r.periodId == _periodId);
          samplePayrollRecords.addAll(results);
          final idx = samplePayrollPeriods.indexWhere((p) => p.id == _periodId);
          if (idx != -1) {
            samplePayrollPeriods[idx] = period!;
          } else {
            samplePayrollPeriods.add(period!);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calculated payroll for ${results.length} employees'),
            backgroundColor: AESColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calculation failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _advanceStatus(PayrollPeriodStatus newStatus) async {
    final period = _period;
    if (period == null || _busy) return;
    setState(() => _busy = true);
    try {
      period.status = newStatus;
      final now = DateTime.now().toIso8601String();
      switch (newStatus) {
        case PayrollPeriodStatus.pendingReview:
          break;
        case PayrollPeriodStatus.approved:
          period.approvedAt = now;
          period.approvedByUsername = widget.currentUser.username;
          break;
        case PayrollPeriodStatus.finalized:
          period.finalizedAt = now;
          period.finalizedByUsername = widget.currentUser.username;
          break;
        case PayrollPeriodStatus.paid:
          period.paidAt = now;
          period.paidByUsername = widget.currentUser.username;
          break;
        default:
          break;
      }
      await DataService.savePayrollPeriod(period);
      await logPayrollAudit(
        action: 'Payroll Status Changed',
        performedByUsername: widget.currentUser.username,
        periodId: _periodId,
        details: '-> ${newStatus.label}',
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopenPeriod() async {
    final period = _period;
    if (period == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Payroll?'),
        content: Text(
          'This will unlock $_monthLabel for editing and set it back to Approved. This action is logged (reopen #${period.reopenCount + 1}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      period.status = PayrollPeriodStatus.approved;
      period.reopenCount += 1;
      await DataService.savePayrollPeriod(period);
      await logPayrollAudit(
        action: 'Payroll Reopened',
        performedByUsername: widget.currentUser.username,
        periodId: _periodId,
        details: 'Reopen #${period.reopenCount}',
      );
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editLineItems(PayrollRecord record) async {
    final period = _period;
    if (period == null || period.status.isLocked) return;
    final allowances = List<PayrollLineItem>.from(record.allowances);
    final bonuses = List<PayrollLineItem>.from(record.bonuses);
    final deductions = List<PayrollLineItem>.from(record.manualDeductions);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget lineItemSection(
              String title,
              List<PayrollLineItem> items,
              Color color,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: color, size: 20),
                        onPressed: () {
                          setDialogState(
                            () => items.add(
                              PayrollLineItem(label: '', amount: 0),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final labelController = TextEditingController(
                      text: item.label,
                    );
                    final amountController = TextEditingController(
                      text: item.amount == 0
                          ? ''
                          : item.amount.toStringAsFixed(0),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: labelController,
                              decoration: const InputDecoration(
                                hintText: 'Label',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => item.label = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Amount',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) =>
                                  item.amount = double.tryParse(v) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                setDialogState(() => items.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
              );
            }

            return AlertDialog(
              title: Text('Adjustments - ${record.username}'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      lineItemSection(
                        'Allowances',
                        allowances,
                        AESColors.primaryGreen,
                      ),
                      lineItemSection(
                        'Bonuses',
                        bonuses,
                        const Color(0xFF2196F3),
                      ),
                      lineItemSection(
                        'Manual Deductions',
                        deductions,
                        Colors.redAccent,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AESColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final profile = payrollProfileFor(record.username);
                    final schedule = profile != null
                        ? workingScheduleFor(profile.employeeType)
                        : null;
                    if (profile == null || schedule == null) {
                      Navigator.pop(context);
                      return;
                    }
                    final recalculated = PayrollEngine.calculate(
                      periodId: record.periodId,
                      monthStart: _selectedMonth,
                      username: record.username,
                      region: record.region,
                      profile: profile,
                      schedule: schedule,
                      settings: samplePayrollSettings,
                      employeeAttendance: sampleAttendance
                          .where((a) => a.employeeUsername == record.username)
                          .toList(),
                      employeeApprovedLeave: sampleLeaves
                          .where(
                            (l) =>
                                l.employeeUsername == record.username &&
                                l.status == LeaveStatus.approved,
                          )
                          .toList(),
                      carryAllowances: allowances
                          .where((a) => a.label.trim().isNotEmpty)
                          .toList(),
                      carryBonuses: bonuses
                          .where((b) => b.label.trim().isNotEmpty)
                          .toList(),
                      carryManualDeductions: deductions
                          .where((d) => d.label.trim().isNotEmpty)
                          .toList(),
                    );
                    await DataService.savePayrollRecord(recalculated);
                    await logPayrollAudit(
                      action: 'Payroll Adjustments Edited',
                      performedByUsername: widget.currentUser.username,
                      targetUsername: record.username,
                      periodId: record.periodId,
                      details:
                          'Allowances: Rs ${recalculated.allowancesTotal.toStringAsFixed(0)}, Bonuses: Rs ${recalculated.bonusTotal.toStringAsFixed(0)}, Manual Deductions: Rs ${recalculated.manualDeductionsTotal.toStringAsFixed(0)}',
                    );
                    if (mounted) {
                      setState(() {
                        final idx = samplePayrollRecords.indexWhere(
                          (r) => r.id == recalculated.id,
                        );
                        if (idx != -1) samplePayrollRecords[idx] = recalculated;
                      });
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save & Recalculate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statusActionButton() {
    final period = _period;
    if (period == null) return const SizedBox.shrink();
    switch (period.status) {
      case PayrollPeriodStatus.draft:
      case PayrollPeriodStatus.processing:
        return ElevatedButton.icon(
          onPressed: _busy
              ? null
              : () => _advanceStatus(PayrollPeriodStatus.pendingReview),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Submit for Review'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF9800),
            foregroundColor: Colors.white,
          ),
        );
      case PayrollPeriodStatus.pendingReview:
        return ElevatedButton.icon(
          onPressed: _busy
              ? null
              : () => _advanceStatus(PayrollPeriodStatus.approved),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
          ),
        );
      case PayrollPeriodStatus.approved:
        return ElevatedButton.icon(
          onPressed: _busy
              ? null
              : () => _advanceStatus(PayrollPeriodStatus.finalized),
          icon: const Icon(Icons.lock, size: 18),
          label: const Text('Finalize Payroll'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
        );
      case PayrollPeriodStatus.finalized:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _advanceStatus(PayrollPeriodStatus.paid),
              icon: const Icon(Icons.payments, size: 18),
              label: const Text('Mark as Paid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AESColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
            if (widget.perms.canReopenPayroll) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _reopenPeriod,
                icon: const Icon(
                  Icons.lock_open,
                  size: 18,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Reopen',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ],
          ],
        );
      case PayrollPeriodStatus.paid:
        return widget.perms.canReopenPayroll
            ? OutlinedButton.icon(
                onPressed: _busy ? null : _reopenPeriod,
                icon: const Icon(
                  Icons.lock_open,
                  size: 18,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Reopen',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                ),
              )
            : const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _period;
    final records = payrollRecordsForPeriod(_periodId)
      ..sort((a, b) => a.username.compareTo(b.username));
    final locked = period?.status.isLocked ?? false;
    final totalNet = records.fold(0.0, (s, r) => s + r.netSalary);

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Process Payroll',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AESColors.darkGreen,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
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
                if (period != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: period.status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      period.status.label,
                      style: TextStyle(
                        color: period.status.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (!locked)
                  ElevatedButton.icon(
                    onPressed: _calculating ? null : _calculatePayroll,
                    icon: _calculating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.calculate, size: 18),
                    label: Text(
                      records.isEmpty ? 'Calculate Payroll' : 'Recalculate All',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AESColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                _statusActionButton(),
              ],
            ),
            if (locked) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This payroll period is locked. Use Reopen Payroll to make further changes.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: AESColors.grey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No payroll calculated for this month yet.',
                        style: TextStyle(color: AESColors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    '${records.length} employees',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AESColors.darkGrey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Total Net Pay: Rs ${totalNet.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AESColors.darkGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AESColors.lightGreen.withValues(alpha: 0.3),
                  ),
                  columns: const [
                    DataColumn(label: Text('Employee')),
                    DataColumn(label: Text('Region')),
                    DataColumn(label: Text('Present')),
                    DataColumn(label: Text('Absent')),
                    DataColumn(label: Text('OT Hrs')),
                    DataColumn(label: Text('Gross'), numeric: true),
                    DataColumn(label: Text('Deductions'), numeric: true),
                    DataColumn(label: Text('Net Salary'), numeric: true),
                    DataColumn(label: Text('')),
                  ],
                  rows: records.map((r) {
                    return DataRow(
                      cells: [
                        DataCell(Text(r.username)),
                        DataCell(Text(r.region)),
                        DataCell(Text('${r.presentDays}')),
                        DataCell(Text('${r.absentDays}')),
                        DataCell(Text(r.overtimeHours.toStringAsFixed(1))),
                        DataCell(
                          Text('Rs ${r.grossSalary.toStringAsFixed(0)}'),
                        ),
                        DataCell(
                          Text(
                            'Rs ${r.totalDeductions.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        DataCell(
                          Text(
                            'Rs ${r.netSalary.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AESColors.darkGreen,
                            ),
                          ),
                        ),
                        DataCell(
                          locked
                              ? const SizedBox.shrink()
                              : IconButton(
                                  icon: const Icon(Icons.tune, size: 18),
                                  tooltip:
                                      'Adjust allowances/bonuses/deductions',
                                  onPressed: () => _editLineItems(r),
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
