part of '../main.dart';

// ---------------- COMPANY-WIDE P&L (all 3 regions) - Finance/CEO only ----------------
// A region switcher over the same RegionalPnlScreen used inside each region's own Finance
// hub - kept separate from those hubs since only Finance ("accountant") and CEO ("admin")
// get to compare all three regions side by side in one place; other roles only ever see
// their own region's Finance hub.
class CompanyPnlScreen extends StatefulWidget {
  const CompanyPnlScreen({super.key});

  @override
  State<CompanyPnlScreen> createState() => _CompanyPnlScreenState();
}

class _CompanyPnlScreenState extends State<CompanyPnlScreen> {
  String _region = 'Lahore';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Company P&L', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              const SizedBox(width: 8),
              for (final r in const ['Lahore', 'Multan', 'Faisalabad'])
                ChoiceChip(
                  label: Text(r),
                  selected: _region == r,
                  onSelected: (_) => setState(() => _region = r),
                  selectedColor: AESColors.primaryGreen,
                  labelStyle: TextStyle(color: _region == r ? Colors.white : AESColors.darkGrey, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        Expanded(child: RegionalPnlScreen(region: _region)),
      ],
    );
  }
}

// ---------------- REGIONAL PROFIT & LOSS SCREEN ----------------
// Revenue = invoiced amounts (Invoice.totalAmount, only ever created from quotations that
// were actually sent to a client). Costs = vendor bills + APPROVED expense claims only -
// a pending or rejected claim isn't a real cost yet. All three models already carry a
// `region` field (added for exactly this kind of region-scoped reporting), so this is pure
// aggregation over data that's already loaded in memory (sampleInvoices, sampleVendorBills,
// sampleExpenses) - no new Firestore collection or query needed.
class RegionalPnlScreen extends StatelessWidget {
  final String region;
  const RegionalPnlScreen({super.key, required this.region});

  // Both VendorBill.date and ExpenseClaim.date are stamped as 'dd-MM-yyyy' (see
  // my_expenses_screen.dart/vendor_bills_screens.dart), while Invoice.month is already
  // 'yyyy-MM' - this normalizes the former to match so all three can be grouped by the same
  // month key.
  static String? _monthKeyFromDdMmYyyy(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final day = parts[0], month = parts[1], year = parts[2];
    if (day.length != 2 || month.length != 2 || year.length != 4) return null;
    return '$year-$month';
  }

  @override
  Widget build(BuildContext context) {
    final invoices = sampleInvoices.where((i) => i.region == region).toList();
    final bills = sampleVendorBills.where((b) => b.region == region).toList();
    final approvedExpenses = sampleExpenses.where((e) => e.region == region && e.status == ExpenseStatus.approved).toList();

    final months = <String>{
      ...invoices.map((i) => i.month),
      ...bills.map((b) => _monthKeyFromDdMmYyyy(b.date)).whereType<String>(),
      ...approvedExpenses.map((e) => _monthKeyFromDdMmYyyy(e.date)).whereType<String>(),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    double revenueFor(String month) => invoices.where((i) => i.month == month).fold(0.0, (sum, i) => sum + i.totalAmount);
    double billsFor(String month) =>
        bills.where((b) => _monthKeyFromDdMmYyyy(b.date) == month).fold(0.0, (sum, b) => sum + b.amount);
    double expensesFor(String month) =>
        approvedExpenses.where((e) => _monthKeyFromDdMmYyyy(e.date) == month).fold(0.0, (sum, e) => sum + e.amount);

    final totalRevenue = invoices.fold(0.0, (sum, i) => sum + i.totalAmount);
    final totalBills = bills.fold(0.0, (sum, b) => sum + b.amount);
    final totalExpenses = approvedExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalCosts = totalBills + totalExpenses;
    final netProfit = totalRevenue - totalCosts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$region Profit & Loss', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
          const SizedBox(height: 4),
          const Text(
            'Revenue from issued invoices, minus vendor bills and approved expense claims for this region.',
            style: TextStyle(color: AESColors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Revenue', value: totalRevenue, color: AESColors.primaryGreen)),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(label: 'Costs', value: totalCosts, color: const Color(0xFFE34948))),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(label: 'Net Profit', value: netProfit, color: netProfit >= 0 ? AESColors.primaryGreen : const Color(0xFFE34948))),
            ],
          ),
          const SizedBox(height: 24),
          Text(tr('By Month'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
          const SizedBox(height: 10),
          if (months.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No invoices, vendor bills, or approved expenses recorded for this region yet'), style: TextStyle(color: AESColors.grey))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(tr('Month'))),
                  DataColumn(label: Text(tr('Revenue')), numeric: true),
                  DataColumn(label: Text('Vendor Bills'), numeric: true),
                  DataColumn(label: Text('Expenses'), numeric: true),
                  DataColumn(label: Text(tr('Profit')), numeric: true),
                ],
                rows: [
                  for (final month in months)
                    DataRow(cells: [
                      DataCell(Text(month)),
                      DataCell(Text('Rs ${revenueFor(month).toStringAsFixed(0)}')),
                      DataCell(Text('Rs ${billsFor(month).toStringAsFixed(0)}')),
                      DataCell(Text('Rs ${expensesFor(month).toStringAsFixed(0)}')),
                      DataCell(Text(
                        'Rs ${(revenueFor(month) - billsFor(month) - expensesFor(month)).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: (revenueFor(month) - billsFor(month) - expensesFor(month)) >= 0 ? AESColors.primaryGreen : const Color(0xFFE34948),
                        ),
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AESColors.grey)),
          const SizedBox(height: 6),
          Text('Rs ${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
