part of '../main.dart';

// ---------------- ACCOUNTING REPORTS (Trial Balance / Balance Sheet / P&L / Cash Flow) ----------------
class AccountingReportsScreen extends StatefulWidget {
  final int initialTabIndex;
  const AccountingReportsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AccountingReportsScreen> createState() => _AccountingReportsScreenState();
}

class _AccountingReportsScreenState extends State<AccountingReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (sampleAccounts.isEmpty) {
      return Material(
        color: AESColors.background,
        child: Center(
          child: Text(tr('Seed the Chart of Accounts first to see financial reports'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8))),
        ),
      );
    }
    return Material(
      color: AESColors.background,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AESColors.primaryGreen,
              unselectedLabelColor: AESColors.grey,
              indicatorColor: AESColors.primaryGreen,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Trial Balance'),
                Tab(text: 'Balance Sheet'),
                Tab(text: 'Profit & Loss'),
                Tab(text: 'Cash Flow'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                _TrialBalanceTab(),
                _BalanceSheetTab(),
                _ProfitAndLossTab(),
                _CashFlowTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _isoDate(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59).toIso8601String();
String _isoDateStart(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String();
String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _DatePickerField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(2015), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        child: Text(_fmtDate(value)),
      ),
    );
  }
}

// ---- Trial Balance ----
class _TrialBalanceTab extends StatefulWidget {
  const _TrialBalanceTab();
  @override
  State<_TrialBalanceTab> createState() => _TrialBalanceTabState();
}

class _TrialBalanceTabState extends State<_TrialBalanceTab> {
  DateTime _asOf = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final asOfIso = _isoDate(_asOf);
    final leaf = sampleAccounts.where((a) => childAccountsOf(a.code).isEmpty).toList()..sort((a, b) => a.code.compareTo(b.code));
    final rows = <({Account account, double debit, double credit})>[];
    double totalDebit = 0, totalCredit = 0;
    for (final acc in leaf) {
      final movement = directAccountMovement(acc.code, to: asOfIso);
      if (movement.abs() < 0.01) continue;
      final debit = acc.normalBalance == NormalBalance.debit ? (movement > 0 ? movement : 0.0) : (movement < 0 ? -movement : 0.0);
      final credit = acc.normalBalance == NormalBalance.credit ? (movement > 0 ? movement : 0.0) : (movement < 0 ? -movement : 0.0);
      rows.add((account: acc, debit: debit, credit: credit));
      totalDebit += debit;
      totalCredit += credit;
    }
    final balanced = (totalDebit - totalCredit).abs() < 0.01;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 220, child: _DatePickerField(label: 'As Of Date', value: _asOf, onChanged: (d) => setState(() => _asOf = d))),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AESColors.lightGrey)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Account')),
                  DataColumn(label: Text('Debit'), numeric: true),
                  DataColumn(label: Text('Credit'), numeric: true),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text(r.account.code)),
                      DataCell(Text(r.account.name)),
                      DataCell(Text(r.debit > 0 ? r.debit.toStringAsFixed(2) : '')),
                      DataCell(Text(r.credit > 0 ? r.credit.toStringAsFixed(2) : '')),
                    ]),
                  DataRow(cells: [
                    const DataCell(Text('')),
                    const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(totalDebit.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(totalCredit.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            balanced ? 'Debits equal credits - trial balance is in balance.' : 'Debits and credits do NOT match - check recent journal entries.',
            style: TextStyle(color: balanced ? AESColors.primaryGreen : Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---- Balance Sheet ----
class _BalanceSheetTab extends StatefulWidget {
  const _BalanceSheetTab();
  @override
  State<_BalanceSheetTab> createState() => _BalanceSheetTabState();
}

class _BalanceSheetTabState extends State<_BalanceSheetTab> {
  DateTime _asOf = DateTime.now();

  Widget _section(String title, AccountType type, String asOfIso) {
    final topLevel = sampleAccounts.where((a) => a.parentCode == null && a.type == type).toList()..sort((a, b) => a.code.compareTo(b.code));
    double total = 0;
    final rows = <Widget>[];
    void walk(Account acc, int depth) {
      final movement = rollupAccountMovement(acc.code, to: asOfIso);
      if (movement.abs() >= 0.01) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: depth * 16.0, top: 4, bottom: 4),
          child: Row(
            children: [
              Expanded(child: Text('${acc.code} - ${acc.name}', style: TextStyle(fontSize: 13, fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.normal))),
              Text(movement.toStringAsFixed(2), style: const TextStyle(fontSize: 13)),
            ],
          ),
        ));
      }
      for (final child in childAccountsOf(acc.code)) {
        walk(child, depth + 1);
      }
    }

    for (final t in topLevel) {
      total += rollupAccountMovement(t.code, to: asOfIso);
      walk(t, 0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AESColors.lightGrey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.darkGreen)),
          const SizedBox(height: 8),
          if (rows.isEmpty) Text('No activity', style: TextStyle(fontSize: 12, color: AESColors.grey.withValues(alpha: 0.8))) else ...rows,
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Total $title', style: const TextStyle(fontWeight: FontWeight.bold)), Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asOfIso = _isoDate(_asOf);
    double assetsTotal = 0, liabilitiesTotal = 0, equityTotal = 0;
    for (final a in sampleAccounts.where((a) => a.parentCode == null)) {
      final movement = rollupAccountMovement(a.code, to: asOfIso);
      if (a.type == AccountType.asset) assetsTotal += movement;
      if (a.type == AccountType.liability) liabilitiesTotal += movement;
      if (a.type == AccountType.equity) equityTotal += movement;
    }
    final netProfit = computeNetProfit(to: asOfIso);
    final liabilitiesPlusEquity = liabilitiesTotal + equityTotal + netProfit;
    final balanced = (assetsTotal - liabilitiesPlusEquity).abs() < 0.01;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 220, child: _DatePickerField(label: 'As Of Date', value: _asOf, onChanged: (d) => setState(() => _asOf = d))),
          const SizedBox(height: 16),
          _section('Assets', AccountType.asset, asOfIso),
          _section('Liabilities', AccountType.liability, asOfIso),
          _section('Equity', AccountType.equity, asOfIso),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AESColors.lightGrey)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Year Profit / Loss (Unposted)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(netProfit.toStringAsFixed(2), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: balanced ? AESColors.primaryGreen.withValues(alpha: 0.08) : Colors.redAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Assets'), Text(assetsTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Liabilities + Equity'), Text(liabilitiesPlusEquity.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 6),
                Text(
                  balanced ? 'Balance sheet balances.' : 'Balance sheet does NOT balance - check recent journal entries.',
                  style: TextStyle(color: balanced ? AESColors.primaryGreen : Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Profit & Loss ----
class _ProfitAndLossTab extends StatefulWidget {
  const _ProfitAndLossTab();
  @override
  State<_ProfitAndLossTab> createState() => _ProfitAndLossTabState();
}

class _ProfitAndLossTabState extends State<_ProfitAndLossTab> {
  DateTime _from = DateTime(DateTime.now().year, 1, 1);
  DateTime _to = DateTime.now();

  Widget _line(String label, double value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
            Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final fromIso = _isoDateStart(_from);
    final toIso = _isoDate(_to);
    final revenue = accountTypeMovement(AccountType.revenue, from: fromIso, to: toIso);
    final cogs = accountTypeMovement(AccountType.costOfSales, from: fromIso, to: toIso);
    final grossProfit = revenue - cogs;
    final expenses = accountTypeMovement(AccountType.expense, from: fromIso, to: toIso);
    final operatingProfit = grossProfit - expenses;
    final otherIncome = accountTypeMovement(AccountType.otherIncome, from: fromIso, to: toIso);
    final otherExpense = accountTypeMovement(AccountType.otherExpense, from: fromIso, to: toIso);
    final netProfit = operatingProfit + otherIncome - otherExpense;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _DatePickerField(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
              const SizedBox(width: 12),
              Expanded(child: _DatePickerField(label: 'To', value: _to, onChanged: (d) => setState(() => _to = d))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AESColors.lightGrey)),
            child: Column(
              children: [
                _line('Revenue', revenue),
                _line('Cost of Sales', cogs),
                const Divider(),
                _line('Gross Profit', grossProfit, bold: true),
                const SizedBox(height: 6),
                _line('Operating Expenses', expenses),
                const Divider(),
                _line('Operating Profit', operatingProfit, bold: true),
                const SizedBox(height: 6),
                _line('Other Income', otherIncome),
                _line('Other Expenses', otherExpense),
                const Divider(),
                _line('Net Profit', netProfit, bold: true, color: netProfit >= 0 ? AESColors.primaryGreen : Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Cash Flow Statement ----
class _CashFlowTab extends StatefulWidget {
  const _CashFlowTab();
  @override
  State<_CashFlowTab> createState() => _CashFlowTabState();
}

class _CashFlowTabState extends State<_CashFlowTab> {
  DateTime _from = DateTime(DateTime.now().year, 1, 1);
  DateTime _to = DateTime.now();

  double _cashMovementForActivity(CashFlowActivity activity, String fromIso, String toIso) {
    double total = 0;
    for (final entry in sampleJournalEntries) {
      if (entry.cashFlowActivity != activity) continue;
      if (entry.dateIso.compareTo(fromIso) < 0 || entry.dateIso.compareTo(toIso) > 0) continue;
      for (final line in entry.lines) {
        if (!isCashOrBankAccount(line.accountCode)) continue;
        total += line.debit - line.credit;
      }
    }
    return total;
  }

  double _totalCashBalance(String toIso) {
    double total = 0;
    for (final a in sampleAccounts.where((a) => a.code == '1110' || a.code == '1120')) {
      total += rollupAccountMovement(a.code, to: toIso);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final fromIso = _isoDateStart(_from);
    final toIso = _isoDate(_to);
    final dayBeforeFrom = _from.subtract(const Duration(days: 1));
    final operating = _cashMovementForActivity(CashFlowActivity.operating, fromIso, toIso);
    final investing = _cashMovementForActivity(CashFlowActivity.investing, fromIso, toIso);
    final financing = _cashMovementForActivity(CashFlowActivity.financing, fromIso, toIso);
    final uncategorized = _cashMovementForActivity(CashFlowActivity.none, fromIso, toIso);
    final netChange = operating + investing + financing + uncategorized;
    final opening = _totalCashBalance(_isoDate(dayBeforeFrom));
    final closing = opening + netChange;

    Widget line(String label, double value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
              Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _DatePickerField(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
              const SizedBox(width: 12),
              Expanded(child: _DatePickerField(label: 'To', value: _to, onChanged: (d) => setState(() => _to = d))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AESColors.lightGrey)),
            child: Column(
              children: [
                line('Operating Activities', operating),
                line('Investing Activities', investing),
                line('Financing Activities', financing),
                if (uncategorized.abs() >= 0.01) line('Uncategorized Cash Movement', uncategorized),
                const Divider(),
                line('Net Change in Cash', netChange, bold: true),
                const SizedBox(height: 10),
                line('Opening Cash Balance', opening),
                line('Closing Cash Balance', closing, bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
