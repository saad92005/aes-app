part of '../main.dart';

// ---------------- EMPLOYEE LEDGER SCREEN (Finance) ----------------
class LedgerScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const LedgerScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  bool _loadingEmployees = true;
  String _searchQuery = '';
  String? _selectedUsername;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
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
          ..sort((a, b) => (a['username'] as String).compareTo(b['username'] as String));
        _loadingEmployees = false;
      });
    }
  }

  List<LedgerEntry> _entriesFor(String username) =>
      (sampleLedgerEntries.where((e) => e.employeeUsername == username).toList()..sort((a, b) => b.id.compareTo(a.id)));

  // Available any time, not just after drilling into one employee - covers every entry
  // across every employee, with a running balance column so the sheet doubles as a snapshot
  // of who owes what as of the moment it's generated.
  Future<void> _exportAllCsv() async {
    final sorted = List<LedgerEntry>.from(sampleLedgerEntries)
      ..sort((a, b) {
        final byEmployee = a.employeeUsername.compareTo(b.employeeUsername);
        return byEmployee != 0 ? byEmployee : a.id.compareTo(b.id);
      });
    final runningBalance = <String, double>{};
    final rows = <List<String>>[
      ['Employee', 'Date', 'Category', 'Description', 'Type', 'Amount', 'Running Balance', 'Entered By'],
      for (final e in sorted)
        () {
          final delta = e.type == LedgerEntryType.debit ? e.amount : -e.amount;
          final balance = (runningBalance[e.employeeUsername] ?? 0) + delta;
          runningBalance[e.employeeUsername] = balance;
          return [
            e.employeeUsername,
            e.date,
            e.category,
            e.description,
            e.type == LedgerEntryType.debit ? 'Debit' : 'Credit',
            e.amount.toStringAsFixed(0),
            balance.toStringAsFixed(0),
            e.enteredByUsername,
          ];
        }(),
    ];
    await ExportService.exportRowsWithFormatChoice(context, title: 'Employee Ledger', rows: rows, filenameBase: 'AES_Employee_Ledger');
  }

  double _balanceFor(String username) {
    double balance = 0;
    for (final e in sampleLedgerEntries.where((e) => e.employeeUsername == username)) {
      balance += e.type == LedgerEntryType.debit ? e.amount : -e.amount;
    }
    return balance;
  }

  Future<void> _addEntry(String username) async {
    String category = ledgerCategories.first;
    LedgerEntryType type = LedgerEntryType.debit;
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String? error;
    // The actual Firestore write now happens while this dialog is still open (guarded by
    // isSubmitting) rather than after it closes - previously Confirm just popped the dialog
    // and the save ran afterward with the outer "Add Entry" button immediately tappable again,
    // so a second dialog could be opened and submitted before the first save had even finished.
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('New Ledger Entry - $username'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<LedgerEntryType>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true),
                      items: LedgerEntryType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                      onChanged: (v) => setDialogState(() => type = v ?? type),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                      items: ledgerCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setDialogState(() => category = v ?? category),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount (Rs)', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amount = double.tryParse(amountController.text.trim());
                          if (amount == null || amount <= 0) {
                            setDialogState(() => error = 'Enter an amount greater than 0');
                            return;
                          }
                          setDialogState(() {
                            error = null;
                            isSubmitting = true;
                          });
                          final entry = LedgerEntry(
                            employeeUsername: username,
                            category: category,
                            description: descController.text.trim(),
                            type: type,
                            amount: amount,
                            enteredByUsername: widget.currentUser.username,
                            region: widget.currentUser.region,
                          );
                          try {
                            await DataService.saveLedgerEntry(entry);
                            setState(() => sampleLedgerEntries.add(entry));
                            if (context.mounted) Navigator.pop(context);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Ledger entry saved successfully'), backgroundColor: AESColors.primaryGreen),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              error = 'Failed to save: $e';
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text(tr('Confirm')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete')),
        content: const Text('Delete this ledger entry? This cannot be undone.'),
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
      await DataService.deleteLedgerEntry(entry.id);
      setState(() => sampleLedgerEntries.removeWhere((e) => e.id == entry.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.perms.canManageLedger) {
      return Center(child: Text(tr('You do not have access to this section'), style: const TextStyle(color: AESColors.grey)));
    }
    if (_selectedUsername != null) return _buildDetail(_selectedUsername!);
    return _buildEmployeeList();
  }

  Widget _buildEmployeeList() {
    var employees = _employees;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      employees = employees.where((e) => (e['username'] as String).toLowerCase().contains(q)).toList();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ledger', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              OutlinedButton.icon(
                onPressed: sampleLedgerEntries.isEmpty ? null : _exportAllCsv,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(tr('Export Report')),
                style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('Cash advances, deductions, and reimbursements per employee'), style: const TextStyle(color: AESColors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          ListSearchField(
            controller: _searchController,
            hintText: 'Search employees...',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 16),
          if (_loadingEmployees)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AESColors.primaryGreen)))
          else if (employees.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No employee accounts yet'), style: const TextStyle(color: AESColors.grey))),
            )
          else
            for (final emp in employees) _buildEmployeeRow(emp),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> emp) {
    final username = emp['username'] as String;
    final balance = _balanceFor(username);
    final role = roleFromString(emp['role']).label;
    final designation = (emp['designation'] as String?)?.trim() ?? '';
    final subtitle = designation.isNotEmpty ? '$role · $designation' : role;
    final balanceColor = balance > 0 ? Colors.deepOrange : (balance < 0 ? AESColors.primaryGreen : AESColors.grey);
    final balanceLabel = balance > 0 ? 'Owes Company' : (balance < 0 ? 'Owed to Employee' : 'Settled');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedUsername = username),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Rs ${balance.abs().toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: balanceColor)),
                  Text(balanceLabel, style: TextStyle(fontSize: 11, color: balanceColor)),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AESColors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(String username) {
    final entries = _entriesFor(username);
    final balance = _balanceFor(username);
    final balanceColor = balance > 0 ? Colors.deepOrange : (balance < 0 ? AESColors.primaryGreen : AESColors.grey);
    final balanceLabel = balance > 0 ? 'Owes Company' : (balance < 0 ? 'Owed to Employee' : 'Settled');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AESColors.darkGreen),
                onPressed: () => setState(() => _selectedUsername = null),
              ),
              Expanded(
                child: Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ),
              ElevatedButton.icon(
                onPressed: () => _addEntry(username),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Add Entry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Current Balance'), style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                const SizedBox(height: 6),
                Text('Rs ${balance.abs().toStringAsFixed(0)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: balanceColor)),
                Text(balanceLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: balanceColor)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('History'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text(tr('No ledger entries yet'), style: const TextStyle(color: AESColors.grey))),
            )
          else
            for (final entry in entries) _buildEntryRow(entry),
        ],
      ),
    );
  }

  Widget _buildEntryRow(LedgerEntry entry) {
    final isDebit = entry.type == LedgerEntryType.debit;
    final color = isDebit ? Colors.deepOrange : AESColors.primaryGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(isDebit ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AESColors.darkGrey)),
                if (entry.description.isNotEmpty) Text(entry.description, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                Text('${entry.date} · by ${entry.enteredByUsername}', style: const TextStyle(fontSize: 11, color: AESColors.grey)),
              ],
            ),
          ),
          Text('Rs ${entry.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AESColors.grey),
            tooltip: 'Delete',
            onPressed: () => _deleteEntry(entry),
          ),
        ],
      ),
    );
  }
}
