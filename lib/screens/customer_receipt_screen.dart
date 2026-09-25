part of '../main.dart';

// ---------------- CUSTOMER RECEIPTS LIST ----------------
class CustomerReceiptsListScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const CustomerReceiptsListScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<CustomerReceiptsListScreen> createState() => _CustomerReceiptsListScreenState();
}

class _CustomerReceiptsListScreenState extends State<CustomerReceiptsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var receipts = widget.perms.seesAllRegions ? sampleCustomerReceipts : sampleCustomerReceipts.where((r) => r.region == 'All' || r.region == widget.currentUser.region).toList();
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      receipts = receipts.where((r) {
        final customer = customerById(r.customerId);
        return r.id.toLowerCase().contains(q) || r.referenceNumber.toLowerCase().contains(q) || (customer?.name.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    receipts = List.of(receipts)..sort((a, b) => b.dateIso.compareTo(a.dateIso));

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
                const Text('Customer Receipts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                ElevatedButton.icon(
                  onPressed: sampleCustomers.isEmpty
                      ? null
                      : () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerReceiptFormScreen(currentUser: widget.currentUser)));
                          setState(() {});
                        },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('Record Receipt')),
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ],
            ),
            if (sampleCustomers.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('Add a customer first (Customers screen).', style: TextStyle(fontSize: 12, color: AESColors.grey))),
            const SizedBox(height: 16),
            ListSearchField(controller: _searchController, hintText: 'Search by receipt #, reference, or customer...', onChanged: (v) => setState(() => _searchQuery = v)),
            const SizedBox(height: 20),
            if (receipts.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text(tr('No receipts recorded yet'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8)))))
            else
              ...receipts.map((r) {
                final customer = customerById(r.customerId);
                return PressableScale(
                  onTap: r.journalEntryId == null
                      ? null
                      : () {
                          JournalEntry? entry;
                          for (final e in sampleJournalEntries) {
                            if (e.id == r.journalEntryId) {
                              entry = e;
                              break;
                            }
                          }
                          if (entry != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => JournalEntryDetailScreen(entry: entry!, currentUser: widget.currentUser)));
                          }
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
                              Text(customer?.name ?? '(unknown customer)', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                              Text('${r.id} · ${r.date} · ${r.method.label}${r.referenceNumber.isNotEmpty ? ' · ${r.referenceNumber}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                              if (r.unallocatedAmount.abs() >= 0.01) Text('Unallocated: Rs ${r.unallocatedAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text('Rs ${r.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.primaryGreen)),
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

// ---------------- RECORD CUSTOMER RECEIPT (the non-accountant-friendly flow) ----------------
class CustomerReceiptFormScreen extends StatefulWidget {
  final AppUser currentUser;
  final String? presetCustomerId;
  const CustomerReceiptFormScreen({super.key, required this.currentUser, this.presetCustomerId});

  @override
  State<CustomerReceiptFormScreen> createState() => _CustomerReceiptFormScreenState();
}

class _CustomerReceiptFormScreenState extends State<CustomerReceiptFormScreen> {
  String? _customerId;
  final TextEditingController _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _bankAccountCode;
  PaymentMethod _method = PaymentMethod.bankTransfer;
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  // invoiceId -> allocated amount controller
  final Map<String, TextEditingController> _allocationControllers = {};
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _customerId = widget.presetCustomerId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    for (final c in _allocationControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Invoice> get _outstandingInvoices {
    if (_customerId == null) return [];
    return sampleInvoices.where((i) => i.customerId == _customerId && i.status == InvoiceStatus.posted && (i.totalWithTax - invoiceAmountPaid(i.id)).abs() >= 0.01).toList()
      ..sort((a, b) => (a.dueDateIso ?? '').compareTo(b.dueDateIso ?? ''));
  }

  TextEditingController _controllerFor(String invoiceId) => _allocationControllers.putIfAbsent(invoiceId, () => TextEditingController());

  double get _totalAllocated {
    double total = 0;
    for (final inv in _outstandingInvoices) {
      total += double.tryParse(_controllerFor(inv.id).text.trim()) ?? 0;
    }
    return total;
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;
  double get _unallocated => _amount - _totalAllocated;

  void _autoAllocate() {
    double remaining = _amount;
    for (final inv in _outstandingInvoices) {
      final outstanding = inv.totalWithTax - invoiceAmountPaid(inv.id);
      final toAllocate = remaining >= outstanding ? outstanding : remaining;
      _controllerFor(inv.id).text = toAllocate > 0 ? toAllocate.toStringAsFixed(2) : '';
      remaining -= toAllocate;
      if (remaining <= 0) remaining = 0;
    }
    setState(() {});
  }

  Future<void> _post() async {
    if (_isSubmitting) return;
    if (_customerId == null) {
      setState(() => _error = 'Select a customer');
      return;
    }
    if (_amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    if (_bankAccountCode == null) {
      setState(() => _error = 'Select a bank/cash account');
      return;
    }
    if (_totalAllocated - _amount > 0.01) {
      setState(() => _error = 'Allocated amount cannot exceed the receipt amount');
      return;
    }
    for (final inv in _outstandingInvoices) {
      final allocated = double.tryParse(_controllerFor(inv.id).text.trim()) ?? 0;
      final outstanding = inv.totalWithTax - invoiceAmountPaid(inv.id);
      if (allocated - outstanding > 0.01) {
        setState(() => _error = 'Allocation to ${inv.id} exceeds its outstanding amount');
        return;
      }
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    final customer = customerById(_customerId!)!;
    final bankAccount = accountByCode(_bankAccountCode!)!;
    final now = DateTime.now();
    final entry = JournalEntry(
      date: _formatDateTimeDisplay(_date),
      dateIso: _date.toIso8601String(),
      memo: 'Receipt from ${customer.name}',
      createdByUsername: widget.currentUser.username,
      cashFlowActivity: CashFlowActivity.operating,
      lines: [
        JournalLine(accountCode: bankAccount.code, accountName: bankAccount.name, debit: _amount, description: 'Receipt from ${customer.name}'),
        JournalLine(accountCode: arControlAccountCode, accountName: accountByCode(arControlAccountCode)?.name ?? 'Accounts Receivable', credit: _amount, customerId: customer.id, description: 'Receipt from ${customer.name}'),
      ],
    );

    final allocations = <ReceiptAllocation>[
      for (final inv in _outstandingInvoices)
        if ((double.tryParse(_controllerFor(inv.id).text.trim()) ?? 0) > 0) ReceiptAllocation(invoiceId: inv.id, amount: double.parse(_controllerFor(inv.id).text.trim())),
    ];

    final receipt = CustomerReceipt(
      customerId: customer.id,
      date: _formatDateTimeDisplay(_date),
      dateIso: _date.toIso8601String(),
      amount: _amount,
      bankAccountCode: bankAccount.code,
      method: _method,
      referenceNumber: _referenceController.text.trim(),
      notes: _notesController.text.trim(),
      allocations: allocations,
      createdByUsername: widget.currentUser.username,
      createdAt: now.toIso8601String(),
      journalEntryId: entry.id,
      region: customer.region,
    );

    try {
      await DataService.saveJournalEntry(entry);
      await DataService.saveCustomerReceipt(receipt);
      setState(() {
        sampleJournalEntries.add(entry);
        sampleCustomerReceipts.add(receipt);
      });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post receipt: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = List.of(sampleCustomers)..sort((a, b) => a.name.compareTo(b.name));
    final bankAccounts = sampleAccounts.where((a) => a.isActive && isCashOrBankAccount(a.code) && childAccountsOf(a.code).isEmpty).toList()..sort((a, b) => a.code.compareTo(b.code));
    final customer = _customerId != null ? customerById(_customerId!) : null;
    final outstanding = _outstandingInvoices;

    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, title: const Text('Record Customer Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder(), isDense: true),
                items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.company.isNotEmpty ? '${c.name} (${c.company})' : c.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: widget.presetCustomerId != null ? null : (v) => setState(() => _customerId = v),
              ),
              if (customer != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AESColors.lightGrey)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Outstanding Balance', style: TextStyle(fontSize: 12, color: AESColors.grey)),
                      Text('Rs ${customerArBalance(customer.id).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: bankAccounts.any((a) => a.code == _bankAccountCode) ? _bankAccountCode : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Deposit To (Bank/Cash)', border: OutlineInputBorder(), isDense: true),
                      items: bankAccounts.map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} - ${a.name}', overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _bankAccountCode = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<PaymentMethod>(
                      initialValue: _method,
                      decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder(), isDense: true),
                      items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.label))).toList(),
                      onChanged: (v) => setState(() => _method = v ?? _method),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(labelText: 'Reference Number (optional)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder(), isDense: true),
              ),
              if (customer != null && outstanding.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tr('Allocate to Invoices'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                    TextButton(onPressed: _amount > 0 ? _autoAllocate : null, child: Text(tr('Auto-Allocate (Oldest First)'))),
                  ],
                ),
                for (final inv in outstanding)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${inv.id} - ${inv.month}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('Outstanding: Rs ${(inv.totalWithTax - invoiceAmountPaid(inv.id)).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _controllerFor(inv.id),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Allocate', border: OutlineInputBorder(), isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (customer != null && _amount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AESColors.lightGrey)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Unallocated Amount', style: TextStyle(fontSize: 12)),
                      Text(
                        _unallocated.toStringAsFixed(2),
                        style: TextStyle(fontWeight: FontWeight.bold, color: _unallocated.abs() < 0.01 ? AESColors.primaryGreen : (_unallocated < 0 ? Colors.redAccent : Colors.orange)),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _post,
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text(tr('Post Receipt')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
