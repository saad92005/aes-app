part of '../main.dart';

// ---------------- FINANCE DASHBOARD ----------------
// Every figure here is read straight from the same accounting engine the rest of the module
// uses (rollupAccountMovement / computeNetProfit / customerArBalance / customerAging) - there
// is no separate calculation anywhere on this screen, so it can never disagree with the
// Trial Balance, Balance Sheet, P&L, or a customer's own ledger. Sections for Accounts
// Payable/Vendor Advances/Project Profitability are deliberately left off rather than filled
// with numbers sourced from VendorBill/ExpenseClaim (which don't post to the ledger yet) -
// mixing ledger-true and non-ledger-true figures on one dashboard is exactly the "disconnected
// financial screens" problem this module was built to get rid of. They'll appear once the
// AP/Vendor and Project Accounting phases land on the same engine.
class FinanceDashboardScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const FinanceDashboardScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  void _openReports(int tabIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AESColors.background,
          appBar: AppBar(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, title: const Text('Accounting Reports')),
          body: AccountingReportsScreen(initialTabIndex: tabIndex),
        ),
      ),
    );
  }

  void _openAccount(String code) {
    final account = accountByCode(code);
    if (account == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => AccountDetailScreen(account: account, currentUser: widget.currentUser)));
  }

  @override
  Widget build(BuildContext context) {
    if (sampleAccounts.isEmpty) {
      return Material(
        color: AESColors.background,
        child: Center(
          child: Text(tr('Seed the Chart of Accounts first (Chart of Accounts screen) to see the Finance Dashboard'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8))),
        ),
      );
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);
    final asOfIso = _isoDate(now);
    final monthStartIso = _isoDateStart(monthStart);
    final yearStartIso = _isoDateStart(yearStart);

    final cashBalance = rollupAccountMovement('1110', to: asOfIso) + rollupAccountMovement('1120', to: asOfIso);
    final arBalance = rollupAccountMovement(arControlAccountCode, to: asOfIso);
    double overdueReceivables = 0;
    for (final c in sampleCustomers) {
      final aging = customerAging(c.id, asOf: now);
      overdueReceivables += aging.days30 + aging.days60 + aging.days90 + aging.over90;
    }
    final revenueThisMonth = accountTypeMovement(AccountType.revenue, from: monthStartIso, to: asOfIso);
    final netProfitThisMonth = computeNetProfit(from: monthStartIso, to: asOfIso);
    final netProfitYtd = computeNetProfit(from: yearStartIso, to: asOfIso);

    // Same reconciliation check as the Trial Balance tab - a quick "is the ledger healthy"
    // signal right on the landing screen.
    double totalDebit = 0, totalCredit = 0;
    for (final acc in sampleAccounts.where((a) => childAccountsOf(a.code).isEmpty)) {
      final movement = directAccountMovement(acc.code, to: asOfIso);
      if (movement.abs() < 0.01) continue;
      if (acc.normalBalance == NormalBalance.debit) {
        movement > 0 ? totalDebit += movement : totalCredit += -movement;
      } else {
        movement > 0 ? totalCredit += movement : totalDebit += -movement;
      }
    }
    final ledgerBalanced = (totalDebit - totalCredit).abs() < 0.01;

    final cashAccounts = [
      ...sampleAccounts.where((a) => a.code == '1110'),
      ...childAccountsOf('1120'),
    ].where((a) => a.isActive).toList();

    final topCustomers = List.of(sampleCustomers)..sort((a, b) => customerArBalance(b.id).compareTo(customerArBalance(a.id)));
    final topCustomersWithBalance = topCustomers.where((c) => customerArBalance(c.id).abs() >= 0.01).take(5).toList();

    final overdueInvoices = sampleInvoices.where((i) => i.status == InvoiceStatus.posted && i.effectiveStatus == InvoiceDisplayStatus.overdue).toList()
      ..sort((a, b) => (a.dueDateIso ?? '').compareTo(b.dueDateIso ?? ''));

    final upcomingCutoff = now.add(const Duration(days: 7));
    final upcomingInvoices = sampleInvoices.where((i) {
      if (i.status != InvoiceStatus.posted) return false;
      if (i.effectiveStatus == InvoiceDisplayStatus.paid || i.effectiveStatus == InvoiceDisplayStatus.overdue) return false;
      final due = i.dueDateIso != null ? DateTime.tryParse(i.dueDateIso!) : null;
      return due != null && !due.isBefore(now) && !due.isAfter(upcomingCutoff);
    }).toList()
      ..sort((a, b) => (a.dueDateIso ?? '').compareTo(b.dueDateIso ?? ''));

    final recentEntries = List.of(sampleJournalEntries)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentEntriesTop = recentEntries.take(8).toList();

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Finance Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
            const SizedBox(height: 4),
            Text('As of ${_fmtDate(now)}', style: const TextStyle(color: AESColors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _KpiTile(label: 'Cash & Bank Balance', value: cashBalance, onTap: () => _openAccount('1110')),
                _KpiTile(label: 'Accounts Receivable', value: arBalance, onTap: () => _openAccount(arControlAccountCode)),
                _KpiTile(label: 'Overdue Receivables', value: overdueReceivables, warn: overdueReceivables > 0, onTap: () => _openReports(1)),
                _KpiTile(label: 'Revenue (This Month)', value: revenueThisMonth, onTap: () => _openReports(2)),
                _KpiTile(label: 'Net Profit (This Month)', value: netProfitThisMonth, onTap: () => _openReports(2)),
                _KpiTile(label: 'Net Profit (Year to Date)', value: netProfitYtd, onTap: () => _openReports(2)),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openReports(0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(ledgerBalanced ? Icons.check_circle : Icons.error, size: 16, color: ledgerBalanced ? AESColors.primaryGreen : Colors.redAccent),
                    const SizedBox(width: 6),
                    Text(
                      ledgerBalanced ? 'Trial balance is in balance' : 'Trial balance does NOT balance - tap to review',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ledgerBalanced ? AESColors.primaryGreen : Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _twoColumn(
              _panel('Bank & Cash Balances', _bankBalancesList(cashAccounts)),
              _panel('Top Customers by Outstanding Balance', _topCustomersList(topCustomersWithBalance)),
            ),
            const SizedBox(height: 16),
            _twoColumn(
              _panel('Overdue Invoices', _invoiceList(overdueInvoices, emptyText: 'No overdue invoices')),
              _panel('Upcoming Receipts (Next 7 Days)', _invoiceList(upcomingInvoices, emptyText: 'Nothing due in the next 7 days')),
            ),
            const SizedBox(height: 16),
            _panel('Recent Journal Entries', _recentEntriesList(recentEntriesTop)),
          ],
        ),
      ),
    );
  }

  // Side-by-side on wide screens, stacked on narrow ones - same LayoutBuilder threshold
  // pattern used elsewhere in the app (see InventoryScreen) rather than a MediaQuery check,
  // so this responds to the space actually available to it, not the whole window.
  Widget _twoColumn(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, const SizedBox(height: 16), right],
        );
      },
    );
  }

  Widget _panel(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _bankBalancesList(List<Account> accounts) {
    if (accounts.isEmpty) return Text(tr('No bank/cash accounts yet'), style: TextStyle(fontSize: 12, color: AESColors.grey.withValues(alpha: 0.8)));
    return Column(
      children: [
        for (final a in accounts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              onTap: () => _openAccount(a.code),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(a.bankName != null ? '${a.name} (${a.bankName})' : a.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                  Text(rollupAccountMovement(a.code).toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _topCustomersList(List<Customer> customers) {
    if (customers.isEmpty) return Text(tr('No outstanding customer balances'), style: TextStyle(fontSize: 12, color: AESColors.grey.withValues(alpha: 0.8)));
    return Column(
      children: [
        for (final c in customers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerDetailScreen(customer: c, currentUser: widget.currentUser, perms: widget.perms))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                  Text(customerArBalance(c.id).toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _invoiceList(List<Invoice> invoices, {required String emptyText}) {
    if (invoices.isEmpty) return Text(tr(emptyText), style: TextStyle(fontSize: 12, color: AESColors.grey.withValues(alpha: 0.8)));
    return Column(
      children: [
        for (final inv in invoices.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              onTap: () {
                final customer = inv.customerId != null ? customerById(inv.customerId!) : null;
                if (customer != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerDetailScreen(customer: customer, currentUser: widget.currentUser, perms: widget.perms)));
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${inv.id} · ${inv.clientName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        Text('Due ${inv.dueDateIso?.substring(0, 10) ?? '-'}', style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                      ],
                    ),
                  ),
                  Text((inv.totalWithTax - invoiceAmountPaid(inv.id)).toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _recentEntriesList(List<JournalEntry> entries) {
    if (entries.isEmpty) return Text(tr('No journal entries yet'), style: TextStyle(fontSize: 12, color: AESColors.grey.withValues(alpha: 0.8)));
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => JournalEntryDetailScreen(entry: e, currentUser: widget.currentUser))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('${e.id} · ${e.memo.isEmpty ? '(no memo)' : e.memo}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  Text('${e.date} · Rs ${e.totalDebit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final double value;
  final bool warn;
  final VoidCallback onTap;
  const _KpiTile({required this.label, required this.value, this.warn = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
            const SizedBox(height: 8),
            Text(
              'Rs ${value.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: warn ? Colors.redAccent : AESColors.darkGreen),
            ),
          ],
        ),
      ),
    );
  }
}
