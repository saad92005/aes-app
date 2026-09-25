part of '../main.dart';

// ---------------- PAYSLIPS ----------------
// Payroll managers (canManagePayroll) can browse any employee's payslips across every period.
// Everyone else (canViewOwnPayslips) only ever sees their own - never another employee's salary
// data, even if they can see that employee elsewhere in the app (e.g. attendance).
class PayslipsScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const PayslipsScreen({
    super.key,
    required this.currentUser,
    required this.perms,
  });

  @override
  State<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen> {
  String? _selectedUsername;
  PayrollRecord? _openRecord;
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _canBrowseAll => widget.perms.canManagePayroll;

  @override
  void initState() {
    super.initState();
    if (_canBrowseAll) {
      _loadEmployees();
    } else {
      _selectedUsername = widget.currentUser.username;
      _loading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final list = await AuthService.listEmployees();
    if (mounted) {
      setState(() {
        _employees = list.where((e) => e['active'] == true).toList()
          ..sort(
            (a, b) =>
                (a['username'] as String).compareTo(b['username'] as String),
          );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: AESColors.primaryGreen),
      );

    if (_openRecord != null) {
      return _PayslipDetailView(
        record: _openRecord!,
        onBack: () => setState(() => _openRecord = null),
      );
    }

    if (_canBrowseAll && _selectedUsername == null) {
      final q = _searchQuery.trim().toLowerCase();
      final filtered = q.isEmpty
          ? _employees
          : _employees
                .where(
                  (e) => (e['username'] as String).toLowerCase().contains(q),
                )
                .toList();
      return Material(
        color: AESColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payslips',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AESColors.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select an employee to view their payslip history.',
                style: TextStyle(color: AESColors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListSearchField(
                controller: _searchController,
                hintText: 'Search employees...',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 20),
              ...filtered.map((e) {
                final username = e['username'] as String;
                final count = samplePayrollRecords
                    .where((r) => r.username == username)
                    .length;
                return PressableScale(
                  onTap: () => setState(() => _selectedUsername = username),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AESColors.darkGreen,
                                ),
                              ),
                              Text(
                                '${e['region']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AESColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$count payslip${count == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AESColors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: AESColors.grey),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    final username = _selectedUsername!;
    final records =
        samplePayrollRecords.where((r) => r.username == username).toList()
          ..sort((a, b) => b.periodId.compareTo(a.periodId));

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_canBrowseAll)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _selectedUsername = null),
                  ),
                Text(
                  _canBrowseAll ? 'Payslips - $username' : 'My Payslips',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AESColors.darkGreen,
                  ),
                ),
              ],
            ),
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
                        'No payslips available yet.',
                        style: TextStyle(color: AESColors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...records.map((r) {
                final period = payrollPeriodById(r.periodId);
                return PressableScale(
                  onTap: () => setState(() => _openRecord = r),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                period?.monthLabel ?? r.periodId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AESColors.darkGreen,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Net Pay: Rs ${r.netSalary.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AESColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (period != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: period.status.color.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              period.status.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: period.status.color,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: AESColors.grey),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _PayslipDetailView extends StatelessWidget {
  final PayrollRecord record;
  final VoidCallback onBack;
  const _PayslipDetailView({required this.record, required this.onBack});

  Future<void> _downloadPdf(BuildContext context) async {
    final period = payrollPeriodById(record.periodId);
    try {
      final bytes = await ExportService.payslipPdfBytes(record, period);
      final name = 'Payslip_${record.username}_${record.periodId}.pdf';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, name: name, mimeType: 'application/pdf'),
          ],
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name ready to share/download'),
            backgroundColor: AESColors.darkGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate payslip: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AESColors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AESColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AESColors.darkGreen,
            ),
          ),
          const Divider(height: 18),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = payrollPeriodById(record.periodId);
    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Payslip - ${period?.monthLabel ?? record.periodId}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AESColors.darkGreen,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _downloadPdf(context),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Download PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AESColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  '${record.username} · ${record.region} · ${record.employeeType.label}',
                  style: const TextStyle(fontSize: 12, color: AESColors.grey),
                ),
              ),
              const SizedBox(height: 20),
              _sectionCard('Attendance Summary', [
                _row('Total Working Days', '${record.totalWorkingDays}'),
                _row('Present Days', '${record.presentDays}'),
                _row('Absent Days', '${record.absentDays}'),
                _row('Paid Leave Days', '${record.paidLeaveDays}'),
                _row('Unpaid Leave Days', '${record.unpaidLeaveDays}'),
                _row(
                  'Late Days',
                  '${record.lateDays} (${record.lateMinutesTotal} min)',
                ),
                _row(
                  'Early Checkout Days',
                  '${record.earlyCheckoutDays} (${record.earlyCheckoutMinutesTotal} min)',
                ),
                _row(
                  'Total Worked Hours',
                  record.totalWorkedHours.toStringAsFixed(1),
                ),
                _row('Overtime Hours', record.overtimeHours.toStringAsFixed(1)),
              ]),
              _sectionCard('Earnings', [
                _row(
                  'Basic Salary',
                  'Rs ${record.basicSalary.toStringAsFixed(0)}',
                ),
                _row(
                  'Earned Basic (Attendance-Adjusted)',
                  'Rs ${record.earnedBasicSalary.toStringAsFixed(0)}',
                ),
                _row(
                  'Overtime Pay',
                  'Rs ${record.overtimePay.toStringAsFixed(0)}',
                ),
                for (final a in record.allowances)
                  _row(
                    'Allowance: ${a.label}',
                    'Rs ${a.amount.toStringAsFixed(0)}',
                  ),
                for (final b in record.bonuses)
                  _row(
                    'Bonus: ${b.label}',
                    'Rs ${b.amount.toStringAsFixed(0)}',
                  ),
                const Divider(height: 18),
                _row(
                  'Gross Salary',
                  'Rs ${record.grossSalary.toStringAsFixed(0)}',
                  bold: true,
                  color: AESColors.darkGreen,
                ),
              ]),
              _sectionCard('Deductions', [
                _row(
                  'Late Deduction',
                  'Rs ${record.lateDeduction.toStringAsFixed(0)}',
                ),
                _row(
                  'Early Checkout Deduction',
                  'Rs ${record.earlyCheckoutDeduction.toStringAsFixed(0)}',
                ),
                for (final d in record.manualDeductions)
                  _row(d.label, 'Rs ${d.amount.toStringAsFixed(0)}'),
                const Divider(height: 18),
                _row(
                  'Total Deductions',
                  'Rs ${record.totalDeductions.toStringAsFixed(0)}',
                  bold: true,
                  color: Colors.redAccent,
                ),
              ]),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AESColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Salary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs ${record.netSalary.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Generated: ${record.calculatedAt.split('T').first} · Status: ${period?.status.label ?? '-'}',
                style: const TextStyle(fontSize: 11, color: AESColors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
