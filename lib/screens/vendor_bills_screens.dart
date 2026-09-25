part of '../main.dart';

// ---------------- VENDOR: MY BILLS SCREEN ----------------
class VendorMyBillsScreen extends StatefulWidget {
  final AppUser currentUser;
  const VendorMyBillsScreen({super.key, required this.currentUser});

  @override
  State<VendorMyBillsScreen> createState() => _VendorMyBillsScreenState();
}

class _VendorMyBillsScreenState extends State<VendorMyBillsScreen> {
  List<VendorBill> get _myBills => sampleVendorBills.where((b) => b.vendorUsername == widget.currentUser.username).toList().reversed.toList();
  List<WorkOrder> get _myWorkOrders => sampleWorkOrders.where((w) => w.assignedVendorUsername == widget.currentUser.username).toList();

  Future<void> _showBillDialog({VendorBill? existing}) async {
    if (_myWorkOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('You need an assigned work order before you can submit a bill')), backgroundColor: AESColors.darkGrey),
      );
      return;
    }

    final remarksController = TextEditingController(text: existing?.remarks ?? '');
    final itemDrafts = existing != null
        ? existing.items.map((i) => LineItemDraft(id: i.id, category: i.category, description: i.description, amount: i.amount.toStringAsFixed(0))).toList()
        : [LineItemDraft()];
    List<String> photos = existing != null ? await DataService.loadVendorBillPhotos(existing.id) : [];
    if (existing?.legacyReceiptPhotoUrl != null) photos = [existing!.legacyReceiptPhotoUrl!, ...photos];
    final myWorkOrders = _myWorkOrders;
    WorkOrder? linkedOrder = existing != null
        ? myWorkOrders.firstWhere((w) => w.id == existing.workOrderId, orElse: () => myWorkOrders.first)
        : myWorkOrders.first;
    bool isSubmitting = false;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(existing == null ? 'Add Bill' : 'Edit Bill', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<WorkOrder>(
                      initialValue: linkedOrder,
                      decoration: const InputDecoration(labelText: 'Work Order', border: OutlineInputBorder(), isDense: true),
                      items: myWorkOrders.map((w) => DropdownMenuItem(value: w, child: Text('WO #${w.id} - ${w.siteName}'))).toList(),
                      onChanged: (v) => setSheetState(() => linkedOrder = v),
                    ),
                    const SizedBox(height: 16),
                    Text(tr('Items'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                    const SizedBox(height: 8),
                    for (final draft in itemDrafts)
                      LineItemEditorRow(
                        draft: draft,
                        onChanged: () => setSheetState(() {}),
                        onRemove: itemDrafts.length > 1 ? () => setSheetState(() => itemDrafts.remove(draft)) : null,
                      ),
                    OutlinedButton.icon(
                      onPressed: () => setSheetState(() => itemDrafts.add(LineItemDraft())),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('Add Item')),
                      style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: remarksController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Remarks (optional)', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    Text(tr('Receipt Photos'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                    const SizedBox(height: 8),
                    PhotoPickerRow(
                      label: '',
                      photos: photos,
                      onPhotoAdded: (dataUrl) => setSheetState(() => photos.add(dataUrl)),
                      onRemove: (i) => setSheetState(() => photos.removeAt(i)),
                      onMultiplePhotosAdded: (dataUrls) => setSheetState(() => photos.addAll(dataUrls)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                          final resolvedItems = itemDrafts
                              .where((d) => d.descController.text.trim().isNotEmpty)
                              .map((d) => VendorBillItem(id: d.id, category: d.resolvedCategory, description: d.descController.text.trim(), amount: d.amountValue))
                              .toList();
                          if (resolvedItems.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('Add at least one item with a description')), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          final now = DateTime.now();
                          final dateStr = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
                          final bill = VendorBill(
                            id: existing?.id ?? 'BILL-${_billCounter++}',
                            vendorUsername: widget.currentUser.username,
                            region: linkedOrder?.region ?? widget.currentUser.region,
                            workOrderId: linkedOrder?.id,
                            items: resolvedItems,
                            date: existing?.date ?? dateStr,
                            remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
                          );
                          try {
                            // Save first, only reflect it locally once Firestore confirms it -
                            // same reasoning as expense submission.
                            await DataService.saveVendorBill(bill);
                            await DataService.saveVendorBillPhotos(bill.id, photos, widget.currentUser.username);
                            setState(() {
                              if (existing != null) {
                                final idx = sampleVendorBills.indexWhere((b) => b.id == existing.id);
                                if (idx != -1) {
                                  sampleVendorBills[idx] = bill;
                                } else {
                                  sampleVendorBills.add(bill);
                                }
                              } else {
                                sampleVendorBills.add(bill);
                              }
                            });
                            if (context.mounted) Navigator.pop(context);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(existing == null ? tr('Bill submitted successfully') : tr('Bill updated')),
                                  backgroundColor: AESColors.primaryGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setSheetState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save bill: $e'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              )
                            : Text(existing == null ? tr('Submit Bill') : tr('Save Changes')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteBill(VendorBill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete Bill')),
        content: Text('Delete bill ${bill.id}? This cannot be undone.'),
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
      await DataService.deleteVendorBill(bill.id);
      setState(() => sampleVendorBills.removeWhere((b) => b.id == bill.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete bill: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Bills', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: () => _showBillDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Add Bill')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_myBills.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No bills submitted yet'), style: TextStyle(color: AESColors.grey))),
            )
          else
            ..._myBills.map((b) => _BillCard(bill: b, onEdit: () => _showBillDialog(existing: b), onDelete: () => _deleteBill(b))),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final VendorBill bill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BillCard({required this.bill, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReceiptPhotosThumb(parentCollection: 'vendorBills', parentId: bill.id, legacyUrl: bill.legacyReceiptPhotoUrl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in bill.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('${item.category} · ${item.description} · Rs ${item.amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey)),
                      ),
                    const SizedBox(height: 4),
                    Text('${bill.id} · ${bill.date}${bill.workOrderId != null ? ' · WO #${bill.workOrderId}' : ''}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                    if (bill.remarks != null && bill.remarks!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Remarks: ${bill.remarks}', style: const TextStyle(fontSize: 12, color: AESColors.grey, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              Text('Rs ${bill.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.primaryGreen)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
                  child: Text(tr('Edit')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                  child: Text(tr('Delete')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- CEO/HEAD OF OPS: VENDOR BILLS SCREEN ----------------
class VendorBillsScreen extends StatefulWidget {
  final AppUser currentUser;
  const VendorBillsScreen({super.key, required this.currentUser});

  @override
  State<VendorBillsScreen> createState() => _VendorBillsScreenState();
}

class _VendorBillsScreenState extends State<VendorBillsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Every other list screen (Work Orders, Inventory, Attendance Report) restricts a
    // region-scoped user to their own region - this one didn't, so e.g. a Lahore-scoped
    // Back Office user could see every vendor bill company-wide instead of just Lahore's.
    final perms = Permissions(widget.currentUser);
    final visibleBills = perms.seesAllRegions ? sampleVendorBills : sampleVendorBills.where((b) => b.region == widget.currentUser.region).toList();
    var bills = visibleBills.reversed.toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      bills = bills
          .where((b) =>
              b.id.toLowerCase().contains(q) ||
              b.vendorUsername.toLowerCase().contains(q) ||
              b.description.toLowerCase().contains(q) ||
              (b.workOrderId ?? '').toLowerCase().contains(q))
          .toList();
    }
    final total = bills.fold<double>(0, (sum, b) => sum + b.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vendor Bills', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
          const SizedBox(height: 4),
          Text('${bills.length} bill${bills.length == 1 ? '' : 's'} · Total: Rs ${total.toStringAsFixed(0)}', style: const TextStyle(color: AESColors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          ListSearchField(
            controller: _searchController,
            hintText: 'Search by vendor, bill #, description, WO#...',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 20),
          if (bills.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _searchQuery.trim().isEmpty ? 'No vendor bills submitted yet' : 'No vendor bills match your search',
                  style: const TextStyle(color: AESColors.grey),
                ),
              ),
            )
          else
            ...bills.map((b) => Container(
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
                      ReceiptPhotosThumb(parentCollection: 'vendorBills', parentId: b.id, legacyUrl: b.legacyReceiptPhotoUrl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vendor: ${b.vendorUsername}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                            const SizedBox(height: 4),
                            for (final item in b.items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('${item.category} · ${item.description} · Rs ${item.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                              ),
                            const SizedBox(height: 4),
                            Text('${b.id} · ${b.date}${b.workOrderId != null ? ' · WO #${b.workOrderId}' : ''}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                            if (b.remarks != null && b.remarks!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Remarks: ${b.remarks}', style: const TextStyle(fontSize: 12, color: AESColors.grey, fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                      Text('Rs ${b.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.primaryGreen)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
