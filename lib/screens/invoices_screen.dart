part of '../main.dart';

// ---------------- INVOICES ----------------
// A "sent quotation" (QuotationData.sentAt != null) is the unit an invoice bundles.
// Grouping key is the free-text client name+company recorded on each quotation - there's no
// separate client entity in this app.
class _SentQuotationRef {
  final WorkOrder workOrder;
  final QuotationData quotation;
  const _SentQuotationRef(this.workOrder, this.quotation);

  String get monthKey => quotation.sentAt!.substring(0, 7); // 'YYYY-MM'
  String get clientKey => '${quotation.clientName}|${quotation.clientCompany}';
}

List<_SentQuotationRef> _allSentQuotations(Permissions perms, AppUser currentUser) {
  final orders = perms.seesAllRegions ? sampleWorkOrders : sampleWorkOrders.where((w) => w.region == currentUser.region).toList();
  return [
    for (final w in orders)
      if (w.quotation != null && w.quotation!.sentAt != null) _SentQuotationRef(w, w.quotation!),
  ];
}

class InvoicesListScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const InvoicesListScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  bool _busy = false;

  List<Invoice> get _invoices {
    final visible = widget.perms.seesAllRegions ? sampleInvoices : sampleInvoices.where((i) => i.region == widget.currentUser.region).toList();
    return visible.reversed.toList();
  }

  Future<void> _openGenerateScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GenerateInvoiceScreen(currentUser: widget.currentUser, perms: widget.perms)),
    );
    setState(() {});
  }

  Future<void> _postInvoice(Invoice invoice) async {
    if (_busy) return;
    if (sampleAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seed the Chart of Accounts first (Chart of Accounts screen) before posting invoices'), backgroundColor: AESColors.darkGrey),
      );
      return;
    }
    String revenueAccountCode = invoice.revenueAccountCode;
    double taxRate = invoice.taxRatePercent;
    int dueDays = customerById(invoice.customerId ?? '')?.paymentTermsDays ?? 30;
    final revenueAccounts = sampleAccounts.where((a) => a.isActive && a.type == AccountType.revenue && childAccountsOf(a.code).isEmpty).toList()..sort((a, b) => a.code.compareTo(b.code));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Post Invoice ${invoice.id}'),
              // maxWidth (not a fixed width) so this shrinks to fit on a phone-width screen
              // instead of forcing 420 logical pixels and overflowing past the viewport edge.
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Posts: Debit Accounts Receivable, Credit Revenue${taxRate > 0 ? ', Credit VAT Payable' : ''} - Rs ${invoice.totalWithTax.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                    const SizedBox(height: 14),
                    if (revenueAccounts.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: revenueAccounts.any((a) => a.code == revenueAccountCode) ? revenueAccountCode : revenueAccounts.first.code,
                        decoration: const InputDecoration(labelText: 'Revenue Account', border: OutlineInputBorder(), isDense: true),
                        items: revenueAccounts.map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} - ${a.name}', overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setDialogState(() => revenueAccountCode = v ?? revenueAccountCode),
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: taxRate.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tax / VAT Rate (%)', border: OutlineInputBorder(), isDense: true),
                      onChanged: (v) => taxRate = double.tryParse(v.trim()) ?? 0,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: dueDays.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Payment Due (days from today)', border: OutlineInputBorder(), isDense: true),
                      onChanged: (v) => dueDays = int.tryParse(v.trim()) ?? dueDays,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _busy = true);

    // Legacy invoices generated before Customers existed have no customerId yet - resolve
    // (find-or-create) one now, the same way GenerateInvoiceScreen does for new invoices.
    Customer? customer = customerById(invoice.customerId ?? '');
    if (customer == null) {
      customer = findOrBuildCustomer(name: invoice.clientName, company: invoice.clientCompany, region: invoice.region);
      if (!sampleCustomers.any((c) => c.id == customer!.id)) {
        try {
          await DataService.saveCustomer(customer);
          sampleCustomers.add(customer);
        } catch (e) {
          if (mounted) {
            setState(() => _busy = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save customer: $e'), backgroundColor: Colors.redAccent));
          }
          return;
        }
      }
    }

    final now = DateTime.now();
    final dueDate = now.add(Duration(days: dueDays));
    final revenueAccount = accountByCode(revenueAccountCode);
    final taxAccount = accountByCode('2160');
    final taxAmount = invoice.totalAmount * (taxRate / 100);

    final entry = JournalEntry(
      date: _formatDateTimeDisplay(now),
      dateIso: now.toIso8601String(),
      memo: 'Invoice ${invoice.id} - ${invoice.clientName}',
      createdByUsername: widget.currentUser.username,
      cashFlowActivity: CashFlowActivity.none,
      lines: [
        JournalLine(accountCode: arControlAccountCode, accountName: accountByCode(arControlAccountCode)?.name ?? 'Accounts Receivable', debit: invoice.totalAmount + taxAmount, customerId: customer.id, description: 'Invoice ${invoice.id}'),
        JournalLine(accountCode: revenueAccountCode, accountName: revenueAccount?.name ?? 'Revenue', credit: invoice.totalAmount, description: 'Invoice ${invoice.id}'),
        if (taxAmount > 0) JournalLine(accountCode: '2160', accountName: taxAccount?.name ?? 'VAT / GST Payable', credit: taxAmount, description: 'Invoice ${invoice.id}'),
      ],
    );

    try {
      await DataService.saveJournalEntry(entry);
      invoice
        ..customerId = customer.id
        ..status = InvoiceStatus.posted
        ..dueDateIso = dueDate.toIso8601String()
        ..revenueAccountCode = revenueAccountCode
        ..taxRatePercent = taxRate
        ..postedAt = now.toIso8601String()
        ..postedByUsername = widget.currentUser.username
        ..journalEntryId = entry.id;
      await DataService.saveInvoice(invoice);
      setState(() => sampleJournalEntries.add(entry));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice posted'), backgroundColor: AESColors.primaryGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post invoice: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelInvoice(Invoice invoice) async {
    if (_busy) return;
    if (invoiceAmountPaid(invoice.id) > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This invoice already has payments applied - it cannot be cancelled directly.'), backgroundColor: AESColors.darkGrey),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Invoice'),
        content: Text('Cancel ${invoice.id}? This reverses its accounting entry - the invoice and its journal entry both stay on record, marked cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);

    JournalEntry? original;
    for (final e in sampleJournalEntries) {
      if (e.id == invoice.journalEntryId) {
        original = e;
        break;
      }
    }
    final now = DateTime.now();
    try {
      if (original != null && !original.hasBeenReversed) {
        final reversal = JournalEntry(
          date: _formatDateTimeDisplay(now),
          dateIso: now.toIso8601String(),
          memo: 'Cancellation of ${original.id} - ${original.memo}',
          createdByUsername: widget.currentUser.username,
          cashFlowActivity: original.cashFlowActivity,
          isReversal: true,
          reversalOfEntryId: original.id,
          lines: original.lines
              .map((l) => JournalLine(accountCode: l.accountCode, accountName: l.accountName, debit: l.credit, credit: l.debit, description: l.description, customerId: l.customerId, vendorId: l.vendorId, projectId: l.projectId))
              .toList(),
        );
        await DataService.saveJournalEntry(reversal);
        original.reversedByEntryId = reversal.id;
        await DataService.saveJournalEntry(original);
        sampleJournalEntries.add(reversal);
      }
      invoice
        ..status = InvoiceStatus.cancelled
        ..cancelledAt = now.toIso8601String()
        ..cancelledByUsername = widget.currentUser.username;
      await DataService.saveInvoice(invoice);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice cancelled'), backgroundColor: AESColors.primaryGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadInvoice(Invoice invoice) async {
    final bytes = await ExportService.rowsToPdfBytes('Invoice ${invoice.id} - ${invoice.clientName}', [
      ['Description', 'Unit', 'Qty', 'Rate', 'Amount', 'Quotation'],
      for (final item in invoice.lineItems)
        [item.description, item.unit, item.qty.toStringAsFixed(0), item.rate.toStringAsFixed(0), item.amount.toStringAsFixed(0), item.quotationId],
      ['', '', '', 'Total', invoice.totalAmount.toStringAsFixed(0), ''],
    ]);
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: '${invoice.id}.pdf', mimeType: 'application/pdf')]));
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _invoices;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Invoices', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: _openGenerateScreen,
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Generate Invoice')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (invoices.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No invoices generated yet'), style: TextStyle(color: AESColors.grey))),
            )
          else
            ...invoices.map((inv) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('${inv.clientName} (${inv.clientCompany})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: inv.effectiveStatus.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                  child: Text(inv.effectiveStatus.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: inv.effectiveStatus.color)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${inv.id} · ${inv.month} · ${inv.quotationIds.length} quotation${inv.quotationIds.length == 1 ? '' : 's'} · ${inv.mode == 'auto' ? 'Auto-generated' : 'Manually adjusted'}',
                                style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                            const SizedBox(height: 4),
                            Text('Generated by ${inv.generatedByUsername}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                            if (inv.status == InvoiceStatus.posted) ...[
                              const SizedBox(height: 4),
                              Text('Paid: Rs ${invoiceAmountPaid(inv.id).toStringAsFixed(0)} of Rs ${inv.totalWithTax.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Rs ${inv.totalWithTax.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.primaryGreen)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download_outlined, color: AESColors.primaryGreen),
                                tooltip: 'Download PDF',
                                onPressed: () => _downloadInvoice(inv),
                              ),
                              if (widget.perms.canManageAccounting)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18, color: AESColors.grey),
                                  enabled: !_busy,
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'post':
                                        _postInvoice(inv);
                                        break;
                                      case 'cancel':
                                        _cancelInvoice(inv);
                                        break;
                                      case 'journal':
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => JournalEntryDetailScreen(entry: sampleJournalEntries.firstWhere((e) => e.id == inv.journalEntryId), currentUser: widget.currentUser)));
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (inv.status == InvoiceStatus.draft) const PopupMenuItem(value: 'post', child: Text('Post Invoice')),
                                    if (inv.status == InvoiceStatus.posted) const PopupMenuItem(value: 'cancel', child: Text('Cancel Invoice')),
                                    if (inv.journalEntryId != null) const PopupMenuItem(value: 'journal', child: Text('View Journal Entry')),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class GenerateInvoiceScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const GenerateInvoiceScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<GenerateInvoiceScreen> createState() => _GenerateInvoiceScreenState();
}

class _GenerateInvoiceScreenState extends State<GenerateInvoiceScreen> {
  late List<_SentQuotationRef> _allRefs;
  String? _selectedClientKey;
  String? _selectedMonth;
  final Set<String> _checkedQuotationIds = {};
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _allRefs = _allSentQuotations(widget.perms, widget.currentUser);
  }

  List<_SentQuotationRef> get _clientOptions {
    final seen = <String>{};
    final result = <_SentQuotationRef>[];
    for (final r in _allRefs) {
      if (seen.add(r.clientKey)) result.add(r);
    }
    return result;
  }

  List<String> get _monthOptionsForSelectedClient {
    if (_selectedClientKey == null) return [];
    final months = _allRefs.where((r) => r.clientKey == _selectedClientKey).map((r) => r.monthKey).toSet().toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  List<_SentQuotationRef> get _matchingRefs {
    if (_selectedClientKey == null || _selectedMonth == null) return [];
    return _allRefs.where((r) => r.clientKey == _selectedClientKey && r.monthKey == _selectedMonth).toList();
  }

  void _selectAllMatching() {
    setState(() {
      _checkedQuotationIds
        ..clear()
        ..addAll(_matchingRefs.map((r) => r.quotation.id));
    });
  }

  Future<void> _generate() async {
    final checkedRefs = _matchingRefs.where((r) => _checkedQuotationIds.contains(r.quotation.id)).toList();
    if (checkedRefs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Select at least one quotation to include')), backgroundColor: Colors.redAccent),
      );
      return;
    }
    setState(() => _generating = true);
    final lineItems = <InvoiceLineItemSnapshot>[
      for (final r in checkedRefs)
        for (final item in r.quotation.lineItems)
          InvoiceLineItemSnapshot(
            quotationId: r.quotation.id,
            description: item.description,
            unit: item.unit,
            qty: item.qty,
            rate: item.rate,
            amount: item.amount,
          ),
    ];
    final allMatchingChecked = checkedRefs.length == _matchingRefs.length;
    // Resolves to a real Customer record (find-or-create by name+company) so this invoice can
    // post to Accounts Receivable against a real customer from the moment it exists, rather
    // than only once someone later posts it - see Customer.findOrBuildCustomer.
    final customer = findOrBuildCustomer(name: checkedRefs.first.quotation.clientName, company: checkedRefs.first.quotation.clientCompany, region: checkedRefs.first.workOrder.region);
    final customerIsNew = !sampleCustomers.any((c) => c.id == customer.id);
    final invoice = Invoice(
      clientName: checkedRefs.first.quotation.clientName,
      clientCompany: checkedRefs.first.quotation.clientCompany,
      month: _selectedMonth!,
      quotationIds: checkedRefs.map((r) => r.quotation.id).toList(),
      workOrderIds: checkedRefs.map((r) => r.workOrder.id).toList(),
      lineItems: lineItems,
      generatedAt: DateTime.now().toIso8601String(),
      generatedByUsername: widget.currentUser.username,
      mode: allMatchingChecked ? 'auto' : 'manual',
      region: checkedRefs.first.workOrder.region,
      customerId: customer.id,
    );

    try {
      if (customerIsNew) {
        await DataService.saveCustomer(customer);
        sampleCustomers.add(customer);
      }
      await DataService.saveInvoice(invoice);
      setState(() => sampleInvoices.add(invoice));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice ${invoice.id} generated - Rs ${invoice.totalAmount.toStringAsFixed(0)}'), backgroundColor: AESColors.darkGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate invoice: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientOptions = _clientOptions;
    final matching = _matchingRefs;

    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, title: Text(tr('Generate Invoice'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (clientOptions.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text(tr('No sent quotations to invoice yet - send a quotation via email first.'), style: TextStyle(color: AESColors.grey))),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedClientKey,
                  decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder(), isDense: true),
                  items: clientOptions
                      .map((r) => DropdownMenuItem(value: r.clientKey, child: Text('${r.quotation.clientName} (${r.quotation.clientCompany})')))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedClientKey = v;
                    _selectedMonth = null;
                    _checkedQuotationIds.clear();
                  }),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMonth,
                  decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder(), isDense: true),
                  items: _monthOptionsForSelectedClient.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: _selectedClientKey == null
                      ? null
                      : (v) => setState(() {
                            _selectedMonth = v;
                            _checkedQuotationIds.clear();
                            _selectAllMatching();
                          }),
                ),
                const SizedBox(height: 20),
                if (matching.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Quotations to include'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                      TextButton(onPressed: _selectAllMatching, child: Text(tr('Select All'))),
                    ],
                  ),
                  for (final r in matching)
                    CheckboxListTile(
                      value: _checkedQuotationIds.contains(r.quotation.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _checkedQuotationIds.add(r.quotation.id);
                        } else {
                          _checkedQuotationIds.remove(r.quotation.id);
                        }
                      }),
                      title: Text('${r.quotation.id} - WO #${r.workOrder.id} - ${r.quotation.siteName}'),
                      subtitle: Text('Sent ${r.quotation.sentAt!.substring(0, 10)} · Rs ${r.quotation.quoteTotal.toStringAsFixed(0)}'),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _generating ? null : _generate,
                      style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                      child: _generating ? const CircularProgressIndicator(color: Colors.white) : Text(tr('Generate Invoice')),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
