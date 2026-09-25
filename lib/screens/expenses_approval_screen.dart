part of '../main.dart';

// ---------------- FINANCE: EXPENSES APPROVAL SCREEN ----------------
// Shared approve/reject logic - also used by the regional finance screens' Expenses tab
// (regional_finance_screen.dart) so both places save/notify/roll-back identically instead
// of maintaining two copies of the same Firestore-write-then-notify sequence.
Future<void> _notifyExpenseEmployee(ExpenseClaim expense, {required bool approved, String? note}) async {
  final now = DateTime.now();
  final timestamp =
      '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final notification = AppNotification(
    id: 'NOTIF-${_notificationCounter++}',
    recipientUsername: expense.employeeUsername,
    title: approved ? 'Expense Approved' : 'Expense Sent Back',
    message: approved
        ? 'Your expense ${expense.id} for Rs ${expense.amount.toStringAsFixed(0)} was approved by Finance'
        : 'Your expense ${expense.id} was sent back: ${note ?? ''}',
    workOrderId: expense.workOrderId,
    timestamp: timestamp,
  );
  await DataService.saveNotification(notification);
}

// Tells Finance a claim has cleared the manager stage and is ready for their final sign-off
// - region-scoped the same way _notifyAdminsOfLateCheckIn scopes attendance alerts, so a
// Multan claim doesn't page a Lahore-only Finance account.
Future<void> _notifyFinanceOfManagerApproval(ExpenseClaim expense) async {
  try {
    final allEmployees = await AuthService.listEmployees();
    final financeUsers = allEmployees.where((e) =>
        roleFromString(e['role']) == UserRole.finance && e['active'] == true && (e['region'] == 'All' || e['region'] == expense.region));
    final timestamp = _formatDateTimeDisplay(DateTime.now());
    for (final f in financeUsers) {
      final notification = AppNotification(
        id: 'NOTIF-${_notificationCounter++}',
        recipientUsername: f['username'],
        title: 'Expense Ready for Finance Approval',
        message:
            '${expense.employeeUsername}\'s expense ${expense.id} (Rs ${expense.amount.toStringAsFixed(0)}) was approved by the manager and is ready for your review',
        workOrderId: expense.workOrderId,
        timestamp: timestamp,
      );
      await DataService.saveNotification(notification);
    }
  } catch (_) {
    // Non-critical - the manager's approval already succeeded, don't block on this.
  }
}

// Stage 1: Operational Manager (or Head of Operations/CEO) sign-off - moves the claim on to
// Finance rather than approving it outright.
Future<void> _managerApproveExpenseClaim(ExpenseClaim expense) async {
  final previousStatus = expense.status;
  expense.status = ExpenseStatus.managerApproved;
  try {
    await DataService.saveExpense(expense);
    await _notifyFinanceOfManagerApproval(expense);
  } catch (e) {
    expense.status = previousStatus;
    rethrow;
  }
}

// Stage 2: Finance's final approval. Mutates and saves the claim, rolling the in-memory
// status back if the save fails so the UI never shows a decision that didn't actually
// persist.
Future<void> _approveExpenseClaim(ExpenseClaim expense) async {
  final previousStatus = expense.status;
  expense.status = ExpenseStatus.approved;
  try {
    await DataService.saveExpense(expense);
    await _notifyExpenseEmployee(expense, approved: true);
  } catch (e) {
    expense.status = previousStatus;
    rethrow;
  }
}

Future<void> _rejectExpenseClaim(ExpenseClaim expense, String note) async {
  final previousStatus = expense.status;
  final previousNote = expense.rejectionNote;
  expense.status = ExpenseStatus.rejected;
  expense.rejectionNote = note;
  try {
    await DataService.saveExpense(expense);
    await _notifyExpenseEmployee(expense, approved: false, note: note);
  } catch (e) {
    expense.status = previousStatus;
    expense.rejectionNote = previousNote;
    rethrow;
  }
}

Future<String?> _showRejectNoteDialog(BuildContext context) async {
  final noteController = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Reason for sending back'), style: TextStyle(fontSize: 16)),
      content: TextField(
        controller: noteController,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Explain what needs to be fixed...', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          onPressed: () {
            if (noteController.text.trim().isEmpty) return;
            Navigator.pop(context, noteController.text.trim());
          },
          child: Text(tr('Send Back')),
        ),
      ],
    ),
  );
}

class ExpensesApprovalScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const ExpensesApprovalScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<ExpensesApprovalScreen> createState() => _ExpensesApprovalScreenState();
}

class _ExpensesApprovalScreenState extends State<ExpensesApprovalScreen> {
  String _statusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExpenseClaim> get _filtered {
    // Every other list screen (Work Orders, Inventory, Attendance Report) restricts a
    // region-scoped user to their own region - this one didn't, so e.g. a Lahore-scoped
    // Back Office user could see every expense claim company-wide instead of just Lahore's.
    final regionScoped = widget.perms.seesAllRegions ? sampleExpenses : sampleExpenses.where((e) => e.region == widget.currentUser.region).toList();
    var all = regionScoped.reversed.toList();
    if (_statusFilter != 'All') {
      all = all.where((e) => e.status.label == _statusFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      all = all
          .where((e) =>
              e.siteName.toLowerCase().contains(q) ||
              e.employeeUsername.toLowerCase().contains(q) ||
              e.category.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q) ||
              e.workOrderId.toLowerCase().contains(q))
          .toList();
    }
    return all;
  }

  Future<void> _approve(ExpenseClaim expense) async {
    setState(() {});
    try {
      // Which stage this claim is actually sitting in decides what "Approve" does - a
      // pending claim goes to the manager stage, a manager-approved one goes to Finance's
      // final approval. The button is only ever shown when the viewer can act on whichever
      // stage the claim is currently in (see _ApprovalExpenseCard's canApprove below).
      final movedToFinal = expense.status == ExpenseStatus.managerApproved;
      if (movedToFinal) {
        await _approveExpenseClaim(expense);
      } else {
        await _managerApproveExpenseClaim(expense);
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(movedToFinal ? 'Expense approved' : 'Sent to Finance for final approval')),
            backgroundColor: AESColors.darkGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _reject(ExpenseClaim expense) async {
    final note = await _showRejectNoteDialog(context);
    if (note == null) return;
    try {
      await _rejectExpenseClaim(expense, note);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Sent back to employee')), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    // The report only includes expenses Finance has already decided on (approved or
    // rejected) - items still awaiting a decision aren't final yet, so they're left out.
    // One row per line item (not per claim) so a multi-item claim's individual amounts are
    // still visible in the report, not collapsed into one combined cell.
    final decided = sampleExpenses.where((e) => e.status == ExpenseStatus.approved || e.status == ExpenseStatus.rejected).toList();
    final rows = <List<String>>[
      ['Expense ID', 'Employee', 'Work Order', 'Site', 'Category', 'Description', 'Amount', 'Date', 'Status', 'Remarks', 'Rejection Note'],
      for (final e in decided)
        for (final item in e.items)
          [
            e.id,
            e.employeeUsername,
            e.workOrderId,
            e.siteName,
            item.category,
            item.description,
            item.amount.toStringAsFixed(0),
            e.date,
            e.status.label,
            e.remarks ?? '',
            e.status == ExpenseStatus.rejected ? (e.rejectionNote ?? '') : '',
          ],
    ];

    await ExportService.exportRowsWithFormatChoice(context, title: 'Expense Report', rows: rows, filenameBase: 'AES_Expense_Report');
  }

  @override
  Widget build(BuildContext context) {
    final expenses = _filtered;
    final pendingCount = sampleExpenses.where((e) => e.status == ExpenseStatus.pending).length;
    final approvedTotal = sampleExpenses.where((e) => e.status == ExpenseStatus.approved).fold<double>(0, (sum, e) => sum + e.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expenses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(tr('Export Report')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$pendingCount pending · Rs ${approvedTotal.toStringAsFixed(0)} approved total',
              style: const TextStyle(color: AESColors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          ListSearchField(
            controller: _searchController,
            hintText: 'Search by employee, site, category, description...',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 12),
          _FilterDropdown(
            label: 'Status',
            value: _statusFilter,
            options: const ['All', 'Pending', 'Manager Approved', 'Approved', 'Rejected'],
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          const SizedBox(height: 20),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _searchQuery.trim().isEmpty ? 'No expenses to show' : 'No expenses match your search',
                  style: const TextStyle(color: AESColors.grey),
                ),
              ),
            )
          else
            ...expenses.map((e) => _ApprovalExpenseCard(
                  expense: e,
                  canApprove: e.status == ExpenseStatus.pending
                      ? widget.perms.canApproveExpenseStage1
                      : e.status == ExpenseStatus.managerApproved
                          ? widget.perms.canApproveExpenseStage2
                          : false,
                  onApprove: () => _approve(e),
                  onReject: () => _reject(e),
                )),
        ],
      ),
    );
  }
}

class _ApprovalExpenseCard extends StatelessWidget {
  final ExpenseClaim expense;
  final bool canApprove;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ApprovalExpenseCard({required this.expense, required this.canApprove, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReceiptPhotosThumb(parentCollection: 'expenses', parentId: expense.id, legacyUrl: expense.legacyReceiptPhotoUrl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.employeeUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                    const SizedBox(height: 4),
                    for (final item in expense.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('${item.category} · ${item.description} · Rs ${item.amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                      ),
                    const SizedBox(height: 4),
                    Text('${expense.id} · ${expense.date} · WO #${expense.workOrderId} - ${expense.siteName}',
                        style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                    if (expense.remarks != null && expense.remarks!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Remarks: ${expense.remarks}', style: const TextStyle(fontSize: 12, color: AESColors.grey, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Rs ${expense.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.primaryGreen)),
                  const SizedBox(height: 6),
                  _StatusChip(status: expense.status),
                ],
              ),
            ],
          ),
          if (canApprove && (expense.status == ExpenseStatus.pending || expense.status == ExpenseStatus.managerApproved)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                    onPressed: onApprove,
                    child: Text(tr(expense.status == ExpenseStatus.managerApproved ? 'Approve (Finance)' : 'Approve (Send to Finance)')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                    onPressed: onReject,
                    child: Text(tr('Reject & Send Back')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

