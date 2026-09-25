part of '../main.dart';

// ---------------- JOURNAL ENTRIES / GENERAL LEDGER SCREEN ----------------
class JournalEntriesScreen extends StatefulWidget {
  final AppUser currentUser;
  const JournalEntriesScreen({super.key, required this.currentUser});

  @override
  State<JournalEntriesScreen> createState() => _JournalEntriesScreenState();
}

class _JournalEntriesScreenState extends State<JournalEntriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leafAccounts = sampleAccounts.where((a) => a.isActive && childAccountsOf(a.code).isEmpty).toList();
    final q = _searchQuery.trim().toLowerCase();
    var entries = List<JournalEntry>.from(sampleJournalEntries)..sort((a, b) => b.dateIso.compareTo(a.dateIso));
    if (q.isNotEmpty) {
      entries = entries
          .where((e) => e.id.toLowerCase().contains(q) || e.memo.toLowerCase().contains(q) || e.lines.any((l) => l.accountName.toLowerCase().contains(q) || l.accountCode.contains(q)))
          .toList();
    }

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Journal Entries', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                ElevatedButton.icon(
                  onPressed: leafAccounts.length < 2
                      ? null
                      : () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => NewJournalEntryScreen(currentUser: widget.currentUser)));
                          setState(() {});
                        },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('New Journal Entry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AESColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            if (leafAccounts.length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Add at least 2 active leaf accounts to the Chart of Accounts before posting journal entries.', style: TextStyle(fontSize: 12, color: AESColors.grey)),
              ),
            const SizedBox(height: 16),
            ListSearchField(
              controller: _searchController,
              hintText: 'Search by entry #, memo, or account...',
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 20),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(tr('No journal entries yet'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8)))),
              )
            else
              ...entries.map((e) => PressableScale(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => JournalEntryDetailScreen(entry: e, currentUser: widget.currentUser)));
                      setState(() {});
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))]),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(e.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                                    const SizedBox(width: 8),
                                    if (e.isOpeningBalance)
                                      _Tag(label: 'Opening Balance', color: AESColors.grey)
                                    else if (e.isReversal)
                                      _Tag(label: 'Reversal', color: Colors.orange)
                                    else if (e.hasBeenReversed)
                                      _Tag(label: 'Reversed', color: Colors.redAccent),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(e.memo.isEmpty ? '(no memo)' : e.memo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AESColors.darkGrey)),
                                Text('${e.date} · ${e.lines.length} lines · by ${e.createdByUsername}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                              ],
                            ),
                          ),
                          Text('Rs ${e.totalDebit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AESColors.darkGrey)),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _JournalLineDraft {
  String? accountCode;
  final TextEditingController debitController = TextEditingController();
  final TextEditingController creditController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  double get debit => double.tryParse(debitController.text.trim()) ?? 0;
  double get credit => double.tryParse(creditController.text.trim()) ?? 0;
}

// ---------------- NEW JOURNAL ENTRY (full screen - proper double-entry posting form) ----------------
class NewJournalEntryScreen extends StatefulWidget {
  final AppUser currentUser;
  const NewJournalEntryScreen({super.key, required this.currentUser});

  @override
  State<NewJournalEntryScreen> createState() => _NewJournalEntryScreenState();
}

class _NewJournalEntryScreenState extends State<NewJournalEntryScreen> {
  DateTime _date = DateTime.now();
  final TextEditingController _memoController = TextEditingController();
  CashFlowActivity _activity = CashFlowActivity.operating;
  final List<_JournalLineDraft> _lines = [_JournalLineDraft(), _JournalLineDraft()];
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _memoController.dispose();
    for (final l in _lines) {
      l.debitController.dispose();
      l.creditController.dispose();
      l.descController.dispose();
    }
    super.dispose();
  }

  double get _totalDebit => _lines.fold(0.0, (s, l) => s + l.debit);
  double get _totalCredit => _lines.fold(0.0, (s, l) => s + l.credit);
  bool get _isBalanced => (_totalDebit - _totalCredit).abs() < 0.01 && _totalDebit > 0;

  Future<void> _post() async {
    if (_isSubmitting) return;
    final usedLines = _lines.where((l) => l.accountCode != null && (l.debit > 0 || l.credit > 0)).toList();
    if (usedLines.length < 2) {
      setState(() => _error = 'Add at least 2 lines with an account and an amount');
      return;
    }
    for (final l in usedLines) {
      if (l.debit > 0 && l.credit > 0) {
        setState(() => _error = 'A line cannot have both a debit and a credit - use two separate lines');
        return;
      }
      final account = accountByCode(l.accountCode!);
      if (account == null || !account.isActive) {
        setState(() => _error = 'One of the selected accounts is no longer active');
        return;
      }
    }
    final totalDebit = usedLines.fold(0.0, (s, l) => s + l.debit);
    final totalCredit = usedLines.fold(0.0, (s, l) => s + l.credit);
    if ((totalDebit - totalCredit).abs() >= 0.01) {
      setState(() => _error = 'Total debits must equal total credits before posting');
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    final entry = JournalEntry(
      date: _formatDateTimeDisplay(_date),
      dateIso: _date.toIso8601String(),
      memo: _memoController.text.trim(),
      createdByUsername: widget.currentUser.username,
      cashFlowActivity: _activity,
      lines: usedLines
          .map((l) => JournalLine(
                accountCode: l.accountCode!,
                accountName: accountByCode(l.accountCode!)!.name,
                debit: l.debit,
                credit: l.credit,
                description: l.descController.text.trim(),
              ))
          .toList(),
    );
    try {
      await DataService.saveJournalEntry(entry);
      setState(() => sampleJournalEntries.add(entry));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leafAccounts = sampleAccounts.where((a) => a.isActive && childAccountsOf(a.code).isEmpty).toList()..sort((a, b) => a.code.compareTo(b.code));
    final diff = _totalDebit - _totalCredit;

    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, title: const Text('New Journal Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2015), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), isDense: true),
                      child: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<CashFlowActivity>(
                    initialValue: _activity,
                    decoration: const InputDecoration(labelText: 'Cash Flow Activity', border: OutlineInputBorder(), isDense: true),
                    items: CashFlowActivity.values.map((a) => DropdownMenuItem(value: a, child: Text(a.label, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _activity = v ?? _activity),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: 'Memo / Description', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 20),
            Text(tr('Lines'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.darkGreen)),
            const SizedBox(height: 10),
            for (int i = 0; i < _lines.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AESColors.lightGrey)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _lines[i].accountCode,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder(), isDense: true),
                            items: leafAccounts.map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} - ${a.name}', overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _lines[i].accountCode = v),
                          ),
                        ),
                        if (_lines.length > 2) IconButton(icon: const Icon(Icons.close, size: 18, color: AESColors.grey), onPressed: () => setState(() => _lines.removeAt(i))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lines[i].debitController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Debit', border: OutlineInputBorder(), isDense: true),
                            onChanged: (v) {
                              if (v.trim().isNotEmpty) _lines[i].creditController.clear();
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lines[i].creditController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Credit', border: OutlineInputBorder(), isDense: true),
                            onChanged: (v) {
                              if (v.trim().isNotEmpty) _lines[i].debitController.clear();
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _lines[i].descController,
                      decoration: const InputDecoration(labelText: 'Line memo (optional)', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _lines.add(_JournalLineDraft())),
              icon: const Icon(Icons.add, size: 16),
              label: Text(tr('Add Line')),
              style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _isBalanced ? AESColors.primaryGreen : AESColors.lightGrey)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Debit'), Text(_totalDebit.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Credit'), Text(_totalCredit.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))]),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Difference'),
                      Text(diff.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: diff.abs() < 0.01 ? AESColors.primaryGreen : Colors.redAccent)),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: !_isBalanced || _isSubmitting ? null : _post,
                style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : Text(tr('Post Journal Entry')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- JOURNAL ENTRY DETAIL (read-only + Reverse) ----------------
class JournalEntryDetailScreen extends StatefulWidget {
  final JournalEntry entry;
  final AppUser? currentUser;
  const JournalEntryDetailScreen({super.key, required this.entry, this.currentUser});

  @override
  State<JournalEntryDetailScreen> createState() => _JournalEntryDetailScreenState();
}

class _JournalEntryDetailScreenState extends State<JournalEntryDetailScreen> {
  bool _reversing = false;

  Future<void> _reverse() async {
    if (_reversing || widget.entry.hasBeenReversed) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reverse Journal Entry'),
        content: const Text('This posts a new journal entry with every debit and credit swapped, offsetting this one. The original entry is never edited or deleted - this is how corrections work in proper double-entry bookkeeping.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _reversing = true);
    final original = widget.entry;
    final now = DateTime.now();
    final reversal = JournalEntry(
      date: _formatDateTimeDisplay(now),
      dateIso: now.toIso8601String(),
      memo: 'Reversal of ${original.id}${original.memo.isNotEmpty ? ' - ${original.memo}' : ''}',
      createdByUsername: widget.currentUser?.username ?? original.createdByUsername,
      cashFlowActivity: original.cashFlowActivity,
      isReversal: true,
      reversalOfEntryId: original.id,
      lines: original.lines.map((l) => JournalLine(accountCode: l.accountCode, accountName: l.accountName, debit: l.credit, credit: l.debit, description: l.description)).toList(),
    );
    try {
      await DataService.saveJournalEntry(reversal);
      original.reversedByEntryId = reversal.id;
      await DataService.saveJournalEntry(original);
      setState(() => sampleJournalEntries.add(reversal));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reversal posted'), backgroundColor: AESColors.primaryGreen));
      }
    } catch (e) {
      original.reversedByEntryId = '';
      if (mounted) {
        setState(() => _reversing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reverse: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, title: Text(entry.id)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.memo.isEmpty ? '(no memo)' : entry.memo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
            const SizedBox(height: 4),
            Text('${entry.date} · Posted by ${entry.createdByUsername} · ${entry.cashFlowActivity.label}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
            if (entry.isOpeningBalance) Padding(padding: const EdgeInsets.only(top: 6), child: _Tag(label: 'Opening Balance', color: AESColors.grey)),
            if (entry.isReversal) Padding(padding: const EdgeInsets.only(top: 6), child: _Tag(label: 'Reversal of ${entry.reversalOfEntryId}', color: Colors.orange)),
            if (entry.hasBeenReversed) Padding(padding: const EdgeInsets.only(top: 6), child: _Tag(label: 'Reversed by ${entry.reversedByEntryId}', color: Colors.redAccent)),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AESColors.lightGrey)),
              child: Column(
                children: [
                  for (final line in entry.lines)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${line.accountCode} - ${line.accountName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AESColors.darkGrey)),
                                if (line.description.isNotEmpty) Text(line.description, style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                              ],
                            ),
                          ),
                          SizedBox(width: 90, child: Text(line.debit > 0 ? line.debit.toStringAsFixed(2) : '', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(width: 90, child: Text(line.credit > 0 ? line.credit.toStringAsFixed(2) : '', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 90, child: Text(entry.totalDebit.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                        SizedBox(width: 90, child: Text(entry.totalCredit.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!entry.hasBeenReversed)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _reversing ? null : _reverse,
                  icon: _reversing ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.undo, size: 16),
                  label: Text(_reversing ? 'Reversing...' : 'Reverse Entry'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
