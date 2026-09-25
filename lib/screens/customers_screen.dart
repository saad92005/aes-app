part of '../main.dart';

// ---------------- CUSTOMERS (Accounts Receivable master) ----------------
class CustomersScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const CustomersScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCustomerDialog({Customer? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final companyController = TextEditingController(text: existing?.company ?? '');
    final addressController = TextEditingController(text: existing?.billingAddress ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final taxController = TextEditingController(text: existing?.taxNumber ?? '');
    final termsController = TextEditingController(text: (existing?.paymentTermsDays ?? 30).toString());
    final creditLimitController = TextEditingController(text: (existing?.creditLimit ?? 0).toStringAsFixed(0));
    String region = existing?.region ?? (widget.perms.seesAllRegions ? 'All' : widget.currentUser.region);
    bool isSubmitting = false;
    String? nameError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Customer' : 'Edit Customer'),
              // maxWidth (not a fixed width) so this shrinks to fit on a phone-width screen
              // instead of forcing 440 logical pixels and overflowing past the viewport edge.
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(labelText: 'Customer Name', border: const OutlineInputBorder(), isDense: true, errorText: nameError),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: companyController,
                        decoration: const InputDecoration(labelText: 'Company', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Billing Address', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), isDense: true))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), isDense: true))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: taxController,
                        decoration: const InputDecoration(labelText: 'Tax / NTN Number', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: termsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Payment Terms (days)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: creditLimitController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Credit Limit (0 = none)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: region,
                        decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder(), isDense: true),
                        items: const ['All', 'Multan', 'Lahore', 'Faisalabad'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setDialogState(() => region = v ?? region),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty) {
                            setDialogState(() => nameError = 'Enter a customer name');
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final customer = Customer(
                            id: existing?.id,
                            name: nameController.text.trim(),
                            company: companyController.text.trim(),
                            billingAddress: addressController.text.trim(),
                            phone: phoneController.text.trim(),
                            email: emailController.text.trim(),
                            taxNumber: taxController.text.trim(),
                            paymentTermsDays: int.tryParse(termsController.text.trim()) ?? 30,
                            creditLimit: double.tryParse(creditLimitController.text.trim()) ?? 0,
                            region: region,
                            isActive: existing?.isActive ?? true,
                            createdAt: existing?.createdAt,
                          );
                          try {
                            await DataService.saveCustomer(customer);
                            setState(() {
                              if (existing != null) {
                                final idx = sampleCustomers.indexWhere((c) => c.id == existing.id);
                                if (idx != -1) sampleCustomers[idx] = customer;
                              } else {
                                sampleCustomers.add(customer);
                              }
                            });
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save customer: $e'), backgroundColor: Colors.redAccent));
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text(existing == null ? 'Add Customer' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var customers = widget.perms.seesAllRegions ? sampleCustomers : sampleCustomers.where((c) => c.region == 'All' || c.region == widget.currentUser.region).toList();
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      customers = customers.where((c) => c.name.toLowerCase().contains(q) || c.company.toLowerCase().contains(q)).toList();
    }
    customers = List.of(customers)..sort((a, b) => a.name.compareTo(b.name));

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
                const Text('Customers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                ElevatedButton.icon(
                  onPressed: () => _showCustomerDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('Add Customer')),
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListSearchField(controller: _searchController, hintText: 'Search customers...', onChanged: (v) => setState(() => _searchQuery = v)),
            const SizedBox(height: 20),
            if (customers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(tr('No customers yet'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8)))),
              )
            else
              ...customers.map((c) {
                final balance = customerArBalance(c.id);
                return PressableScale(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerDetailScreen(customer: c, currentUser: widget.currentUser, perms: widget.perms)));
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
                              Text(c.company.isNotEmpty ? '${c.name} (${c.company})' : c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                              if (c.phone.isNotEmpty || c.email.isNotEmpty) Text([c.phone, c.email].where((s) => s.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Outstanding', style: TextStyle(fontSize: 11, color: AESColors.grey)),
                            Text('Rs ${balance.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: balance > 0 ? Colors.redAccent : AESColors.primaryGreen)),
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

// ---------------- CUSTOMER DETAIL (balance, aging, invoices, receipts) ----------------
class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;
  final AppUser currentUser;
  final Permissions perms;
  const CustomerDetailScreen({super.key, required this.customer, required this.currentUser, required this.perms});

  @override
  Widget build(BuildContext context) {
    final balance = customerArBalance(customer.id);
    final aging = customerAging(customer.id);
    final invoices = sampleInvoices.where((i) => i.customerId == customer.id).toList().reversed.toList();
    final receipts = sampleCustomerReceipts.where((r) => r.customerId == customer.id).toList().reversed.toList();

    Widget agingCell(String label, double value) => Expanded(
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AESColors.grey)),
              Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white, title: Text(customer.name)),
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
                  if (customer.company.isNotEmpty) Text(customer.company, style: const TextStyle(fontSize: 13, color: AESColors.grey)),
                  if (customer.billingAddress.isNotEmpty) Text(customer.billingAddress, style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                  if (customer.phone.isNotEmpty || customer.email.isNotEmpty) Text([customer.phone, customer.email].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                  Text('Payment Terms: Net ${customer.paymentTermsDays} days${customer.creditLimit > 0 ? ' · Credit Limit: Rs ${customer.creditLimit.toStringAsFixed(0)}' : ''}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                  const SizedBox(height: 14),
                  Text('Outstanding Balance', style: TextStyle(fontSize: 12, color: AESColors.grey)),
                  Text('Rs ${balance.toStringAsFixed(2)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: balance > 0 ? Colors.redAccent : AESColors.primaryGreen)),
                  if (customer.creditLimit > 0 && balance > customer.creditLimit)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Over credit limit', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 14),
                  const Divider(),
                  Text('Aging (Outstanding Invoices)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      agingCell('Current', aging.current),
                      agingCell('1-30', aging.days30),
                      agingCell('31-60', aging.days60),
                      agingCell('61-90', aging.days90),
                      agingCell('90+', aging.over90),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(tr('Invoices'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
            const SizedBox(height: 10),
            if (invoices.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(tr('No invoices yet'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8))))
            else
              ...invoices.map((inv) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AESColors.lightGrey)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${inv.id} · ${inv.month}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(inv.effectiveStatus.label, style: TextStyle(fontSize: 11, color: inv.effectiveStatus.color)),
                            ],
                          ),
                        ),
                        Text('Rs ${inv.totalWithTax.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('Receipts'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                if (perms.canManageAccounting)
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerReceiptFormScreen(currentUser: currentUser, presetCustomerId: customer.id)));
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(tr('Record Receipt')),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (receipts.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(tr('No receipts yet'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8))))
            else
              ...receipts.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AESColors.lightGrey)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r.id} · ${r.date}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${r.method.label}${r.referenceNumber.isNotEmpty ? ' · ${r.referenceNumber}' : ''}', style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                              if (r.unallocatedAmount.abs() >= 0.01) Text('Unallocated: Rs ${r.unallocatedAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                            ],
                          ),
                        ),
                        Text('Rs ${r.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AESColors.primaryGreen)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
