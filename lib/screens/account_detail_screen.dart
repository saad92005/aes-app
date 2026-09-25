part of '../main.dart';

// ---------------- ACCOUNT DETAIL SCREEN (Balance + Ledger/Transactions) ----------------
class AccountDetailScreen extends StatefulWidget {
  final Account account;
  final AppUser currentUser;
  const AccountDetailScreen({super.key, required this.account, required this.currentUser});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  bool _submittingOpeningBalance = false;

  List<({JournalEntry entry, JournalLine line})> get _entries {
    final result = <({JournalEntry entry, JournalLine line})>[];
    for (final entry in sampleJournalEntries) {
      for (final line in entry.lines) {
        if (line.accountCode == widget.account.code) result.add((entry: entry, line: line));
      }
    }
    result.sort((a, b) => a.entry.dateIso.compareTo(b.entry.dateIso));
    return result;
  }

  Future<void> _setOpeningBalance() async {
    final account = widget.account;
    if (hasOpeningBalanceEntry(account.code)) return;
    final amountController = TextEditingController();
    DateTime date = DateTime.now();
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set Opening Balance'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recorded as ${account.normalBalance.label} - the account\'s normal balance direction.',
                    style: const TextStyle(fontSize: 12, color: AESColors.grey),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Opening Balance Amount', border: const OutlineInputBorder(), isDense: true, errorText: error),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2015), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) setDialogState(() => date = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'As Of Date', border: OutlineInputBorder(), isDense: true),
                      child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      setDialogState(() => error = 'Enter an amount greater than 0');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;
    if (_submittingOpeningBalance) return;
    setState(() => _submittingOpeningBalance = true);

    final dateIso = date.toIso8601String();
    final dateStr = _formatDateTimeDisplay(date);
    final debitLine = account.normalBalance == NormalBalance.debit;
    final entry = JournalEntry(
      date: dateStr,
      dateIso: dateIso,
      memo: 'Opening balance - ${account.code} ${account.name}',
      createdByUsername: widget.currentUser.username,
      cashFlowActivity: CashFlowActivity.none,
      isOpeningBalance: true,
      lines: [
        JournalLine(
          accountCode: account.code,
          accountName: account.name,
          debit: debitLine ? amount : 0,
          credit: debitLine ? 0 : amount,
          description: 'Opening balance',
        ),
        JournalLine(
          accountCode: '3600',
          accountName: 'Opening Balance Equity',
          debit: debitLine ? 0 : amount,
          credit: debitLine ? amount : 0,
          description: 'Opening balance - ${account.code} ${account.name}',
        ),
      ],
    );
    try {
      await DataService.saveJournalEntry(entry);
      setState(() => sampleJournalEntries.add(entry));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening balance recorded'), backgroundColor: AESColors.primaryGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _submittingOpeningBalance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final entries = _entries;
    final hasChildren = childAccountsOf(account.code).isNotEmpty;
    final balance = hasChildren ? rollupAccountMovement(account.code) : directAccountMovement(account.code);
    final breadcrumb = accountAncestors(account).reversed.map((a) => a.name).join(' > ');
    double running = 0;

    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(
        backgroundColor: AESColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Text('${account.code} - ${account.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (breadcrumb.isNotEmpty) Text(breadcrumb, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text(account.type.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AESColors.darkGrey))),
                      if (!account.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AESColors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                          child: const Text('Inactive', style: TextStyle(fontSize: 10, color: AESColors.grey, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Current Balance', style: TextStyle(fontSize: 12, color: AESColors.grey)),
                  Text(
                    'Rs ${balance.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: balance < 0 ? Colors.redAccent : AESColors.darkGreen),
                  ),
                  Text('Normal balance: ${account.normalBalance.label}', style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                  if (account.bankName != null || account.bankAccountNumber != null) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    if (account.bankName != null) Text('Bank: ${account.bankName}', style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                    if (account.bankAccountNumber != null) Text('Account #: ${account.bankAccountNumber}', style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                  ],
                  if (account.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(account.description, style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                  ],
                  const SizedBox(height: 14),
                  if (!hasChildren)
                    hasOpeningBalanceEntry(account.code)
                        ? Text('Opening balance already recorded', style: TextStyle(fontSize: 12, color: AESColors.grey.withValues(alpha: 0.8)))
                        : OutlinedButton.icon(
                            onPressed: _submittingOpeningBalance ? null : _setOpeningBalance,
                            icon: _submittingOpeningBalance
                                ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.flag_outlined, size: 16),
                            label: Text(_submittingOpeningBalance ? 'Saving...' : 'Set Opening Balance'),
                            style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
                          ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(tr('General Ledger / Transactions'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text(tr('No transactions posted to this account yet'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8)))),
              )
            else
              ...entries.map((e) {
                running += e.line.debit - e.line.credit;
                final displayRunning = account.normalBalance == NormalBalance.debit ? running : -running;
                return PressableScale(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => JournalEntryDetailScreen(entry: e.entry, currentUser: widget.currentUser))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AESColors.lightGrey)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.entry.memo.isEmpty ? e.entry.id : e.entry.memo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AESColors.darkGrey)),
                              Text('${e.entry.date} · ${e.entry.id}${e.line.description.isNotEmpty ? ' · ${e.line.description}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              e.line.debit > 0 ? 'Dr ${e.line.debit.toStringAsFixed(2)}' : 'Cr ${e.line.credit.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: e.line.debit > 0 ? AESColors.darkGreen : Colors.redAccent),
                            ),
                            Text('Bal: ${displayRunning.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                          ],
                        ),
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
