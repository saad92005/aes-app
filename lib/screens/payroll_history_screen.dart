part of '../main.dart';

// ---------------- PAYROLL HISTORY ----------------
// Read-only browse of past payroll periods and their per-employee records - no editing here
// even for an unlocked period (use Process Payroll for that); this screen is purely for
// looking back at what's already been run.
class PayrollHistoryScreen extends StatefulWidget {
  final AppUser currentUser;
  const PayrollHistoryScreen({super.key, required this.currentUser});

  @override
  State<PayrollHistoryScreen> createState() => _PayrollHistoryScreenState();
}

class _PayrollHistoryScreenState extends State<PayrollHistoryScreen> {
  String? _selectedPeriodId;

  @override
  Widget build(BuildContext context) {
    final periods = List<PayrollPeriod>.from(samplePayrollPeriods)
      ..sort((a, b) => b.id.compareTo(a.id));

    if (_selectedPeriodId != null) {
      final period = payrollPeriodById(_selectedPeriodId!);
      if (period == null) {
        _selectedPeriodId = null;
      } else {
        return _PeriodDetailView(
          period: period,
          onBack: () => setState(() => _selectedPeriodId = null),
        );
      }
    }

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payroll History',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AESColors.darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Past payroll runs, most recent first.',
              style: TextStyle(color: AESColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (periods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: AESColors.grey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No payroll periods yet.',
                        style: TextStyle(color: AESColors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...periods.map((p) {
                final records = payrollRecordsForPeriod(p.id);
                final totalNet = records.fold(0.0, (s, r) => s + r.netSalary);
                return PressableScale(
                  onTap: () => setState(() => _selectedPeriodId = p.id),
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
                                p.monthLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AESColors.darkGreen,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${records.length} employees${p.reopenCount > 0 ? ' · Reopened ${p.reopenCount}x' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AESColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Rs ${totalNet.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AESColors.darkGrey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: p.status.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p.status.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.status.color,
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

class _PeriodDetailView extends StatelessWidget {
  final PayrollPeriod period;
  final VoidCallback onBack;
  const _PeriodDetailView({required this.period, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final records = payrollRecordsForPeriod(period.id)
      ..sort((a, b) => a.username.compareTo(b.username));
    final totalNet = records.fold(0.0, (s, r) => s + r.netSalary);
    final totalGross = records.fold(0.0, (s, r) => s + r.grossSalary);
    final totalDeductions = records.fold(0.0, (s, r) => s + r.totalDeductions);

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                Text(
                  period.monthLabel,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AESColors.darkGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: period.status.color.withValues(alpha: 0.12),
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
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  'Total Gross',
                  totalGross,
                  const Color(0xFF2196F3),
                ),
                _summaryCard(
                  'Total Deductions',
                  totalDeductions,
                  Colors.redAccent,
                ),
                _summaryCard('Total Net Pay', totalNet, AESColors.primaryGreen),
              ],
            ),
            const SizedBox(height: 20),
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
                ],
                rows: records.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r.username)),
                      DataCell(Text(r.region)),
                      DataCell(Text('${r.presentDays}')),
                      DataCell(Text('${r.absentDays}')),
                      DataCell(Text(r.overtimeHours.toStringAsFixed(1))),
                      DataCell(Text('Rs ${r.grossSalary.toStringAsFixed(0)}')),
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
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, double value, Color color) {
    return Container(
      width: 200,
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
            label,
            style: const TextStyle(fontSize: 12, color: AESColors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs ${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
