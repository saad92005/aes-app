part of '../main.dart';

// ---------------- EMPLOYEE: MY EXPENSES SCREEN ----------------
class MyExpensesScreen extends StatefulWidget {
  final AppUser currentUser;
  const MyExpensesScreen({super.key, required this.currentUser});

  @override
  State<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends State<MyExpensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExpenseClaim> get _myExpenses {
    var claims = sampleExpenses.where((e) => e.employeeUsername == widget.currentUser.username).toList().reversed.toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      claims = claims
          .where((e) =>
              e.siteName.toLowerCase().contains(q) ||
              e.category.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q) ||
              e.workOrderId.toLowerCase().contains(q))
          .toList();
    }
    return claims;
  }

  // A synthetic, never-persisted "work order" for costs that aren't tied to any specific
  // site visit (petty cash, office supplies, travel between meetings, etc.) - back office
  // staff, managers, finance and the CEO don't get "assigned" work orders the way field
  // employees do, so without this option their work-order picker would just be empty and
  // they'd have no way to submit an expense at all.
  WorkOrder get _generalExpenseWorkOrder => WorkOrder(
        id: 'GENERAL',
        siteName: 'General / Office Expense',
        address: '',
        region: widget.currentUser.region,
        priority: 2,
        description: '',
        targetDate: '',
        reportedDate: '',
        status: WorkOrderStatus.pending,
      );

  List<WorkOrder> get _myWorkOrders {
    if (widget.currentUser.role == UserRole.employee) {
      return sampleWorkOrders.where((w) => w.assignedEmployeeUsername == widget.currentUser.username).toList();
    }
    final perms = Permissions(widget.currentUser);
    final regionScoped = perms.seesAllRegions
        ? sampleWorkOrders
        : sampleWorkOrders.where((w) => w.region == widget.currentUser.region).toList();
    return [_generalExpenseWorkOrder, ...regionScoped];
  }

  // Routes the "new expense" notification to whoever actually needs to act on it next.
  // Normally that's the region's Operational Manager (stage 1). But an Operational Manager
  // can't meaningfully review their own expense claim, so when the submitter IS the manager
  // who'd otherwise get this, the claim skips stage 1 entirely (see the status set in
  // _showExpenseDialog's save handler) and this notifies stage 2 directly instead: Finance
  // (region-scoped, same pattern as _notifyFinanceOfManagerApproval) and Head of Operations.
  Future<void> _notifyExpenseSubmission(ExpenseClaim expense, {required bool skippedManagerStage}) async {
    try {
      final allEmployees = await AuthService.listEmployees();
      final recipients = skippedManagerStage
          ? allEmployees.where((e) =>
              e['active'] == true &&
              ((roleFromString(e['role']) == UserRole.finance && (e['region'] == 'All' || e['region'] == expense.region)) ||
                  roleFromString(e['role']) == UserRole.headOfOperations))
          : allEmployees.where((e) =>
              e['active'] == true &&
              roleFromString(e['role']) == UserRole.operationalManager &&
              (e['region'] == 'All' || e['region'] == expense.region));
      final title = skippedManagerStage ? 'Expense Ready for Approval' : 'New Expense Submitted';
      final now = DateTime.now();
      final timestamp =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      for (final r in recipients) {
        final notification = AppNotification(
          id: 'NOTIF-${_notificationCounter++}',
          recipientUsername: r['username'],
          title: title,
          message: '${widget.currentUser.username} submitted Rs ${expense.amount.toStringAsFixed(0)} (${expense.items.length} item${expense.items.length == 1 ? '' : 's'}) for WO #${expense.workOrderId}',
          workOrderId: expense.workOrderId,
          timestamp: timestamp,
        );
        await DataService.saveNotification(notification);
      }
    } catch (_) {
      // Notification is best-effort; don't block expense submission if it fails.
    }
  }

  Future<void> _showExpenseDialog({ExpenseClaim? existing}) async {
    final myWorkOrders = _myWorkOrders;
    if (myWorkOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('You need an assigned work order before you can submit an expense')), backgroundColor: AESColors.darkGrey),
      );
      return;
    }

    final remarksController = TextEditingController(text: existing?.remarks ?? '');
    final itemDrafts = existing != null
        ? existing.items.map((i) => LineItemDraft(id: i.id, category: i.category, description: i.description, amount: i.amount.toStringAsFixed(0))).toList()
        : [LineItemDraft()];
    List<String> photos = existing != null ? await DataService.loadExpensePhotos(existing.id) : [];
    if (existing?.legacyReceiptPhotoUrl != null) photos = [existing!.legacyReceiptPhotoUrl!, ...photos];
    WorkOrder? linkedOrder = existing != null
        ? myWorkOrders.firstWhere((w) => w.id == existing.workOrderId, orElse: () => myWorkOrders.first)
        : myWorkOrders.first;
    bool isSubmitting = false;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(existing == null ? 'Submit Daily Expense' : 'Edit Expense',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<WorkOrder>(
                      initialValue: linkedOrder,
                      decoration: const InputDecoration(labelText: 'Work Order', border: OutlineInputBorder(), isDense: true),
                      items: myWorkOrders.map((w) => DropdownMenuItem(value: w, child: Text('WO #${w.id} - ${w.siteName}'))).toList(),
                      onChanged: (v) => setSheetState(() => linkedOrder = v),
                    ),
                    const SizedBox(height: 16),
                    Text(tr('Items'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                    const SizedBox(height: 8),
                    for (final draft in itemDrafts)
                      LineItemEditorRow(
                        draft: draft,
                        onChanged: () => setSheetState(() {}),
                        onRemove: itemDrafts.length > 1 ? () => setSheetState(() => itemDrafts.remove(draft)) : null,
                      ),
                    OutlinedButton.icon(
                      onPressed: () => setSheetState(() => itemDrafts.add(LineItemDraft())),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('Add Item')),
                      style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: remarksController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Remarks (optional)', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    Text(tr('Receipt Photos'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                    const SizedBox(height: 8),
                    PhotoPickerRow(
                      label: '',
                      photos: photos,
                      onPhotoAdded: (dataUrl) => setSheetState(() => photos.add(dataUrl)),
                      onRemove: (i) => setSheetState(() => photos.removeAt(i)),
                      onMultiplePhotosAdded: (dataUrls) => setSheetState(() => photos.addAll(dataUrls)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                          final resolvedItems = itemDrafts
                              .where((d) => d.descController.text.trim().isNotEmpty)
                              .map((d) => ExpenseLineItem(id: d.id, category: d.resolvedCategory, description: d.descController.text.trim(), amount: d.amountValue))
                              .toList();
                          if (linkedOrder == null || resolvedItems.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('Add at least one item with a description')), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          final now = DateTime.now();
                          final dateStr = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
                          final timestamp = '$dateStr ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                          // An Operational Manager submitting their own expense can't
                          // meaningfully review it themselves, so it skips the manager stage
                          // (see _notifyExpenseSubmission above) and goes straight to
                          // Finance/Head of Operations.
                          final skipsManagerStage = widget.currentUser.role == UserRole.operationalManager;
                          final expense = ExpenseClaim(
                            id: existing?.id ?? 'EXP-${_expenseCounter++}',
                            employeeUsername: widget.currentUser.username,
                            workOrderId: linkedOrder!.id,
                            siteName: linkedOrder!.siteName,
                            region: linkedOrder!.region,
                            items: resolvedItems,
                            date: existing?.date ?? dateStr,
                            remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                            status: skipsManagerStage ? ExpenseStatus.managerApproved : ExpenseStatus.pending,
                            submittedAt: existing?.submittedAt ?? timestamp,
                          );

                          try {
                            // Save to Firestore FIRST - only reflect it locally once we know
                            // it actually persisted, so a failed save can't look like a
                            // successful submission that then vanishes after logout.
                            await DataService.saveExpense(expense);
                            await DataService.saveExpensePhotos(expense.id, photos, widget.currentUser.username);
                            setState(() {
                              if (existing != null) {
                                final idx = sampleExpenses.indexWhere((e) => e.id == existing.id);
                                if (idx != -1) {
                                  sampleExpenses[idx] = expense;
                                } else {
                                  sampleExpenses.add(expense);
                                }
                              } else {
                                sampleExpenses.add(expense);
                              }
                            });
                            if (existing == null) await _notifyExpenseSubmission(expense, skippedManagerStage: skipsManagerStage);
                            if (context.mounted) Navigator.pop(context);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(existing == null ? tr('Expense submitted successfully') : tr('Expense updated')),
                                  backgroundColor: AESColors.primaryGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setSheetState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save expense: $e'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              )
                            : Text(existing == null ? tr('Submit Expense') : tr('Save Changes')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteExpense(ExpenseClaim expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete Expense')),
        content: Text('Delete ${expense.id}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataService.deleteExpense(expense.id);
      setState(() => sampleExpenses.removeWhere((e) => e.id == expense.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete expense: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = _myExpenses;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Expenses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: () => _showExpenseDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Submit Expense')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListSearchField(
            controller: _searchController,
            hintText: 'Search by site, category, description, WO#...',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 20),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _searchQuery.trim().isEmpty ? 'No expenses submitted yet' : 'No expenses match your search',
                  style: const TextStyle(color: AESColors.grey),
                ),
              ),
            )
          else
            ...expenses.map((e) => _MyExpenseCard(expense: e, onEdit: () => _showExpenseDialog(existing: e), onDelete: () => _deleteExpense(e))),
        ],
      ),
    );
  }
}

class _MyExpenseCard extends StatelessWidget {
  final ExpenseClaim expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MyExpenseCard({required this.expense, required this.onEdit, required this.onDelete});

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
                    for (final item in expense.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('${item.category} · ${item.description} · Rs ${item.amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AESColors.darkGrey)),
                      ),
                    const SizedBox(height: 4),
                    Text('${expense.id} · ${expense.date} · WO #${expense.workOrderId}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
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
          if (expense.status == ExpenseStatus.rejected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(expense.rejectionNote ?? 'Rejected by Finance', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                  ),
                ],
              ),
            ),
          ],
          // Editable/deletable while pending (correct a mistake before the manager reviews
          // it) or after being rejected (fix it up and resubmit, or just delete it) - locked
          // once a manager has approved it (undermining their review) or Finance has given
          // final approval.
          if (expense.status == ExpenseStatus.pending || expense.status == ExpenseStatus.rejected) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                    child: Text(tr('Delete')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                    child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
                    child: Text(expense.status == ExpenseStatus.rejected ? 'Edit & Resubmit' : 'Edit'),
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

class _StatusChip extends StatelessWidget {
  final ExpenseStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(tr(status.label), style: TextStyle(color: status.color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}
