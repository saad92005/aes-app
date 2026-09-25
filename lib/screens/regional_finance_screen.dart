part of '../main.dart';

// ---------------- REGIONAL FINANCE SCREEN (Quotations + Expenses + P&L, one region) ----------------
// One combined "finance hub" per region rather than three separate nav items, so everything
// finance-related for Multan (or Faisalabad) lives in one place instead of being scattered
// across the company-wide Quotations/Expense Approvals/P&L screens, which mix all regions
// together.
class RegionalFinanceScreen extends StatefulWidget {
  final String region;
  final AppUser currentUser;
  final Permissions perms;
  const RegionalFinanceScreen({super.key, required this.region, required this.currentUser, required this.perms});

  @override
  State<RegionalFinanceScreen> createState() => _RegionalFinanceScreenState();
}

class _RegionalFinanceScreenState extends State<RegionalFinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Text('${widget.region} Finance', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AESColors.primaryGreen,
          unselectedLabelColor: AESColors.grey,
          indicatorColor: AESColors.primaryGreen,
          tabs: const [Tab(text: 'Quotations'), Tab(text: 'Expenses'), Tab(text: 'P&L')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RegionalQuotationsTab(region: widget.region, perms: widget.perms),
              _RegionalExpensesTab(region: widget.region, perms: widget.perms),
              RegionalPnlScreen(region: widget.region),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegionalQuotationsTab extends StatefulWidget {
  final String region;
  final Permissions perms;
  const _RegionalQuotationsTab({required this.region, required this.perms});

  @override
  State<_RegionalQuotationsTab> createState() => _RegionalQuotationsTabState();
}

class _RegionalQuotationsTabState extends State<_RegionalQuotationsTab> {
  @override
  Widget build(BuildContext context) {
    final withQuotations = sampleWorkOrders.where((w) => w.region == widget.region && w.quotation != null).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${withQuotations.length} quotation${withQuotations.length == 1 ? '' : 's'} · ${widget.region}',
              style: const TextStyle(color: AESColors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          if (withQuotations.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No quotations for this region yet'), style: TextStyle(color: AESColors.grey))),
            )
          else
            ...withQuotations.map((w) => _QuotationListCard(
                  workOrder: w,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => WorkOrderDetailScreen(workOrder: w, perms: widget.perms)),
                    );
                    setState(() {});
                  },
                )),
        ],
      ),
    );
  }
}

class _RegionalExpensesTab extends StatefulWidget {
  final String region;
  final Permissions perms;
  const _RegionalExpensesTab({required this.region, required this.perms});

  @override
  State<_RegionalExpensesTab> createState() => _RegionalExpensesTabState();
}

class _RegionalExpensesTabState extends State<_RegionalExpensesTab> {
  String _statusFilter = 'All';

  List<ExpenseClaim> get _filtered {
    final regionScoped = sampleExpenses.where((e) => e.region == widget.region).toList().reversed.toList();
    if (_statusFilter == 'All') return regionScoped;
    return regionScoped.where((e) => e.status.label == _statusFilter).toList();
  }

  Future<void> _approve(ExpenseClaim expense) async {
    try {
      await _approveExpenseClaim(expense);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Expense approved')), backgroundColor: AESColors.darkGreen),
        );
      }
    } catch (e) {
      if (mounted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = _filtered;
    final pendingCount = sampleExpenses.where((e) => e.region == widget.region && e.status == ExpenseStatus.pending).length;
    final approvedTotal =
        sampleExpenses.where((e) => e.region == widget.region && e.status == ExpenseStatus.approved).fold<double>(0, (sum, e) => sum + e.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$pendingCount pending · Rs ${approvedTotal.toStringAsFixed(0)} approved total · ${widget.region}',
              style: const TextStyle(color: AESColors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          _FilterDropdown(
            label: 'Status',
            value: _statusFilter,
            options: const ['All', 'Pending', 'Manager Approved', 'Approved', 'Rejected'],
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          const SizedBox(height: 20),
          if (expenses.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No expenses for this region yet'), style: TextStyle(color: AESColors.grey))),
            )
          else
            // This hub is Finance-only, so it only ever acts at the final stage - a still-
            // pending claim shows up here as "awaiting the manager" with no action available
            // yet, exactly like Finance seeing it in the company-wide Expense Approvals screen.
            ...expenses.map((e) => _ApprovalExpenseCard(
                  expense: e,
                  canApprove: e.status == ExpenseStatus.managerApproved && widget.perms.canApproveExpenseStage2,
                  onApprove: () => _approve(e),
                  onReject: () => _reject(e),
                )),
        ],
      ),
    );
  }
}
