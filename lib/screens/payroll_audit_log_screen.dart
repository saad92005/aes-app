part of '../main.dart';

// ---------------- PAYROLL AUDIT LOG ----------------
// Read-only view of every logged payroll action (see logPayrollAudit in payroll_extras.dart) -
// same canManagePayroll gate as the rest of the admin payroll screens, most recent first.
class PayrollAuditLogScreen extends StatefulWidget {
  const PayrollAuditLogScreen({super.key});

  @override
  State<PayrollAuditLogScreen> createState() => _PayrollAuditLogScreenState();
}

class _PayrollAuditLogScreenState extends State<PayrollAuditLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconFor(String action) {
    if (action.contains('Calculated')) return Icons.calculate_outlined;
    if (action.contains('Status Changed')) return Icons.swap_horiz;
    if (action.contains('Reopened')) return Icons.lock_open;
    if (action.contains('Salary')) return Icons.trending_up;
    if (action.contains('Profile')) return Icons.badge_outlined;
    if (action.contains('Schedule')) return Icons.schedule_outlined;
    if (action.contains('Holiday')) return Icons.event_busy;
    if (action.contains('Rules') || action.contains('Settings'))
      return Icons.tune_outlined;
    if (action.contains('Adjustments')) return Icons.tune;
    return Icons.receipt_long_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.trim().toLowerCase();
    final entries = List<PayrollAuditEntry>.from(samplePayrollAuditLog)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final filtered = q.isEmpty
        ? entries
        : entries.where((e) {
            return e.action.toLowerCase().contains(q) ||
                e.performedByUsername.toLowerCase().contains(q) ||
                (e.targetUsername ?? '').toLowerCase().contains(q) ||
                e.details.toLowerCase().contains(q);
          }).toList();

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payroll Audit Log',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AESColors.darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${entries.length} recorded actions.',
              style: const TextStyle(color: AESColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ListSearchField(
              controller: _searchController,
              hintText: 'Search by action, employee, or details...',
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 20),
            if (filtered.isEmpty)
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
                        'No payroll actions recorded yet.',
                        style: TextStyle(color: AESColors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AESColors.lightGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _iconFor(e.action),
                          size: 18,
                          color: AESColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.action,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AESColors.darkGrey,
                                    ),
                                  ),
                                ),
                                Text(
                                  e.createdAt
                                      .replaceFirst('T', ' ')
                                      .split('.')
                                      .first,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AESColors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'By ${e.performedByUsername}${e.targetUsername != null ? ' · For ${e.targetUsername}' : ''}${e.periodId != null ? ' · Period ${e.periodId}' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AESColors.grey,
                              ),
                            ),
                            if (e.details.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                e.details,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AESColors.darkGrey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
