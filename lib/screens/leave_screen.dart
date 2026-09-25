part of '../main.dart';

// ---------------- EMPLOYEE: MY LEAVE SCREEN ----------------
class MyLeaveScreen extends StatefulWidget {
  final AppUser currentUser;
  const MyLeaveScreen({super.key, required this.currentUser});

  @override
  State<MyLeaveScreen> createState() => _MyLeaveScreenState();
}

class _MyLeaveScreenState extends State<MyLeaveScreen> {
  List<LeaveRequest> get _myLeaves => sampleLeaves.where((l) => l.employeeUsername == widget.currentUser.username).toList().reversed.toList();

  // Fans out to every role that must be alerted on a new leave application - back office,
  // operational manager, head of operations, and finally the CEO. AppNotification is
  // single-recipient, so this loops and writes one notification doc per matching user
  // (same pattern as MyExpensesScreen._notifyFinance).
  Future<void> _notifyManagement(LeaveRequest leave) async {
    try {
      final allEmployees = await AuthService.listEmployees();
      final alertRoles = {UserRole.backOffice, UserRole.operationalManager, UserRole.headOfOperations, UserRole.ceo};
      final recipients = allEmployees.where((e) => alertRoles.contains(roleFromString(e['role'])) && e['active'] == true);
      final now = DateTime.now();
      final timestamp =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      for (final r in recipients) {
        final notification = AppNotification(
          id: 'NOTIF-${_notificationCounter++}',
          recipientUsername: r['username'],
          title: 'New Leave Application',
          message: '${widget.currentUser.username} applied for ${leave.numberOfDays} day${leave.numberOfDays == 1 ? '' : 's'} of ${leave.leaveType} leave (${leave.startDate} to ${leave.endDate})',
          timestamp: timestamp,
        );
        await DataService.saveNotification(notification);
      }
    } catch (_) {
      // Notification is best-effort; don't block the leave application if it fails.
    }
  }

  Future<void> _showLeaveDialog({LeaveRequest? existing}) async {
    String leaveType = existing?.leaveType ?? leaveTypes.first;
    DateTime? startDate = existing != null ? DateTime.tryParse(existing.startDate) : null;
    DateTime? endDate = existing != null ? DateTime.tryParse(existing.endDate) : null;
    final remarksController = TextEditingController(text: existing?.remarks ?? '');
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(existing == null ? 'Apply for Leave' : 'Edit Leave Application',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: leaveType,
                      decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder(), isDense: true),
                      items: leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setSheetState(() => leaveType = v ?? leaveType),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setSheetState(() => startDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder(), isDense: true),
                        child: Text(startDate == null ? 'Select date' : '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? startDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setSheetState(() => endDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'End Date', border: OutlineInputBorder(), isDense: true),
                        child: Text(endDate == null ? 'Select date' : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: remarksController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Remarks', hintText: 'Reason for leave...', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                        // Disabled the instant a submit starts (via isSubmitting -> null onPressed)
                        // and only re-enabled on failure - a repeated tap while the first request is
                        // still in flight, or a slow network stretching that flight time, previously
                        // hit this handler again and created the same leave application multiple times.
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (startDate == null || endDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(tr('Select both a start and end date')), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                if (endDate!.isBefore(startDate!)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(tr('End date cannot be before start date')), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                setSheetState(() => isSubmitting = true);
                                String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                final now = DateTime.now();
                                final leave = LeaveRequest(
                                  id: existing?.id ?? 'LEAVE-${_leaveCounter++}',
                                  employeeUsername: widget.currentUser.username,
                                  region: widget.currentUser.region,
                                  leaveType: leaveType,
                                  startDate: isoDate(startDate!),
                                  endDate: isoDate(endDate!),
                                  remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                                  submittedAt: existing?.submittedAt ?? now.toIso8601String(),
                                );
                                try {
                                  await DataService.saveLeave(leave);
                                  setState(() {
                                    if (existing != null) {
                                      final idx = sampleLeaves.indexWhere((l) => l.id == existing.id);
                                      if (idx != -1) sampleLeaves[idx] = leave;
                                    } else {
                                      sampleLeaves.add(leave);
                                    }
                                  });
                                  if (existing == null) await _notifyManagement(leave);
                                  if (context.mounted) Navigator.pop(context);
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text(existing == null ? tr('Leave application submitted successfully') : tr('Leave application updated')),
                                        backgroundColor: AESColors.primaryGreen,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    setSheetState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to submit leave application: $e'), backgroundColor: Colors.redAccent),
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
                            : Text(existing == null ? tr('Submit Application') : tr('Save Changes')),
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

  Future<void> _deleteLeave(LeaveRequest leave) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete Leave Application')),
        content: Text('Delete ${leave.id}? This cannot be undone.'),
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
      await DataService.deleteLeave(leave.id);
      setState(() => sampleLeaves.removeWhere((l) => l.id == leave.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete leave application: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaves = _myLeaves;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('My Leave'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: () => _showLeaveDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Apply for Leave')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (leaves.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No leave applications yet'), style: TextStyle(color: AESColors.grey))),
            )
          else
            ...leaves.map((l) => _LeaveCard(
                  leave: l,
                  onEdit: () => _showLeaveDialog(existing: l),
                  onDelete: () => _deleteLeave(l),
                )),
        ],
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveRequest leave;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _LeaveCard({required this.leave, required this.onEdit, required this.onDelete});

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${leave.leaveType} Leave · ${leave.numberOfDays} day${leave.numberOfDays == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey)),
                    const SizedBox(height: 4),
                    Text('${leave.id} · ${leave.startDate} to ${leave.endDate}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                    if (leave.remarks != null && leave.remarks!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Remarks: ${leave.remarks}', style: const TextStyle(fontSize: 12, color: AESColors.grey, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: leave.status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(tr(leave.status.label), style: TextStyle(color: leave.status.color, fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            ],
          ),
          if (leave.status == LeaveStatus.rejected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(leave.rejectionNote ?? 'Rejected', style: const TextStyle(fontSize: 12, color: Colors.redAccent))),
                ],
              ),
            ),
          ],
          // Only while still pending - once a manager has decided, the application is locked
          // the same way an approved expense/completed work order is.
          if (leave.status == LeaveStatus.pending) ...[
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
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
                    child: Text(tr('Edit')),
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

// ---------------- LEAVE APPROVAL SCREEN (Back Office / Manager / Head of Ops / CEO) ----------------
class LeaveApprovalScreen extends StatefulWidget {
  final AppUser currentUser;
  const LeaveApprovalScreen({super.key, required this.currentUser});

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  String _statusFilter = 'All';

  List<LeaveRequest> get _filtered {
    final all = sampleLeaves.reversed.toList();
    if (_statusFilter == 'All') return all;
    return all.where((l) => l.status.label == _statusFilter).toList();
  }

  Future<void> _notifyEmployee(LeaveRequest leave, {required bool approved, String? note}) async {
    final now = DateTime.now();
    final timestamp =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final notification = AppNotification(
      id: 'NOTIF-${_notificationCounter++}',
      recipientUsername: leave.employeeUsername,
      title: approved ? 'Leave Approved' : 'Leave Rejected',
      message: approved
          ? 'Your ${leave.leaveType} leave (${leave.startDate} to ${leave.endDate}) was approved'
          : 'Your ${leave.leaveType} leave (${leave.startDate} to ${leave.endDate}) was rejected: ${note ?? ''}',
      timestamp: timestamp,
    );
    await DataService.saveNotification(notification);
  }

  Future<void> _approve(LeaveRequest leave) async {
    setState(() => leave.status = LeaveStatus.approved);
    try {
      await DataService.saveLeave(leave);
      await _notifyEmployee(leave, approved: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Leave approved')), backgroundColor: AESColors.darkGreen));
      }
    } catch (e) {
      setState(() => leave.status = LeaveStatus.pending);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _reject(LeaveRequest leave) async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Reason for rejection'), style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Explain why this is being rejected...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              if (noteController.text.trim().isEmpty) return;
              Navigator.pop(context, noteController.text.trim());
            },
            child: Text(tr('Reject')),
          ),
        ],
      ),
    );
    if (note == null) return;

    setState(() {
      leave.status = LeaveStatus.rejected;
      leave.rejectionNote = note;
    });
    try {
      await DataService.saveLeave(leave);
      await _notifyEmployee(leave, approved: false, note: note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Leave rejected')), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaves = _filtered;
    final pendingCount = sampleLeaves.where((l) => l.status == LeaveStatus.pending).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Leave Applications'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
        const SizedBox(height: 4),
        Text('$pendingCount pending', style: const TextStyle(color: AESColors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        _FilterDropdown(
          label: 'Status',
          value: _statusFilter,
          options: const ['All', 'Pending', 'Approved', 'Rejected'],
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(height: 20),
        if (leaves.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text(tr('No leave applications to show'), style: TextStyle(color: AESColors.grey))),
          )
        else
          for (final leave in leaves)
            Container(
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(leave.employeeUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                            const SizedBox(height: 2),
                            Text('${leave.leaveType} Leave · ${leave.numberOfDays} day${leave.numberOfDays == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                            const SizedBox(height: 4),
                            Text('${leave.id} · ${leave.startDate} to ${leave.endDate}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                            if (leave.remarks != null && leave.remarks!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Remarks: ${leave.remarks}', style: const TextStyle(fontSize: 12, color: AESColors.grey, fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: leave.status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(tr(leave.status.label), style: TextStyle(color: leave.status.color, fontWeight: FontWeight.w600, fontSize: 11)),
                      ),
                    ],
                  ),
                  if (leave.status == LeaveStatus.pending) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                            onPressed: () => _approve(leave),
                            child: Text(tr('Approve')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                            onPressed: () => _reject(leave),
                            child: Text(tr('Reject')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}
