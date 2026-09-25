part of '../main.dart';

// ---------------- INVENTORY SCREEN ----------------
class InventoryScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const InventoryScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

enum _InventoryTab { stock, transactions, assignments }

class _InventoryScreenState extends State<InventoryScreen> {
  _InventoryTab _tab = _InventoryTab.stock;
  String _regionFilter = 'All';
  String _searchQuery = '';
  List<Map<String, dynamic>> _employees = [];
  bool _importing = false;
  // Shared single-flight guard for every stock/assignment/item mutation below - a dialog's
  // Confirm button already can't be double-tapped (Navigator.pop removes it after one tap),
  // but the screen becomes interactive again immediately once it closes, while the actual
  // Firestore write is often still in flight. Without this, a slow network let a second
  // dialog (same action or a different one) be opened and submitted before the first write
  // finished, creating duplicate transactions/items/assignments.
  bool _actionInFlight = false;

  Future<bool> _beginAction() async {
    if (_actionInFlight) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the previous action to finish'), backgroundColor: AESColors.darkGrey),
      );
      return false;
    }
    setState(() => _actionInFlight = true);
    return true;
  }

  void _endAction() {
    if (mounted) setState(() => _actionInFlight = false);
  }

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final list = await AuthService.listEmployees();
    if (mounted) setState(() => _employees = list.where((e) => e['active'] == true).toList());
  }

  List<InventoryItem> get _visibleItems => widget.perms.seesAllRegions
      ? sampleInventoryItems
      : sampleInventoryItems.where((i) => i.region == widget.currentUser.region).toList();

  List<InventoryItem> get _filteredItems {
    var items = _visibleItems;
    if (_regionFilter != 'All') items = items.where((i) => i.region == _regionFilter).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) => i.name.toLowerCase().contains(q) || i.category.toLowerCase().contains(q)).toList();
    }
    return List.of(items)..sort((a, b) => a.name.compareTo(b.name));
  }

  List<InventoryTransaction> get _visibleTxns => widget.perms.seesAllRegions
      ? sampleInventoryTransactions
      : sampleInventoryTransactions.where((t) => t.region == widget.currentUser.region).toList();

  List<InventoryTransaction> get _filteredTxns {
    var txns = _visibleTxns;
    if (_regionFilter != 'All') txns = txns.where((t) => t.region == _regionFilter).toList();
    return List.of(txns)..sort((a, b) => b.id.compareTo(a.id));
  }

  List<ToolAssignment> get _visibleAssignments => widget.perms.seesAllRegions
      ? sampleToolAssignments
      : sampleToolAssignments.where((a) => a.region == widget.currentUser.region).toList();

  List<ToolAssignment> get _filteredAssignments {
    var assignments = _visibleAssignments;
    if (_regionFilter != 'All') assignments = assignments.where((a) => a.region == _regionFilter).toList();
    return List.of(assignments)..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<void> _recordTransaction(InventoryItem item, InventoryTxnType type) async {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    final relatedOrders = (widget.perms.seesAllRegions ? sampleWorkOrders : sampleWorkOrders.where((w) => w.region == item.region)).toList();
    String? relatedWorkOrderId;
    String? errorMessage;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(type == InventoryTxnType.stockIn ? 'Stock In - ${item.name}' : 'Stock Out - ${item.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current stock: ${item.quantity.toStringAsFixed(0)} ${item.unit}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: qtyController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Quantity (${item.unit})', border: const OutlineInputBorder(), isDense: true),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      initialValue: relatedWorkOrderId,
                      decoration: InputDecoration(
                        labelText: type == InventoryTxnType.stockOut ? 'Used for Work Order (optional)' : 'Received for Work Order (optional)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(tr('None - general stock'))),
                        ...relatedOrders.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text('WO #${w.id} - ${w.siteName}', overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setDialogState(() => relatedWorkOrderId = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () {
                    final qty = double.tryParse(qtyController.text.trim());
                    if (qty == null || qty <= 0) {
                      setDialogState(() => errorMessage = 'Enter a quantity greater than 0');
                      return;
                    }
                    if (type == InventoryTxnType.stockOut && qty > item.quantity) {
                      setDialogState(() => errorMessage =
                          'Only ${item.quantity.toStringAsFixed(0)} ${item.unit} in stock - can\'t take out $qty');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(tr('Confirm')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    final qty = double.tryParse(qtyController.text.trim());
    if (qty == null || qty <= 0) return;
    if (type == InventoryTxnType.stockOut && qty > item.quantity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Not enough stock for that quantity')), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }
    if (!await _beginAction()) return;

    final delta = type == InventoryTxnType.stockIn ? qty : -qty;
    final txn = InventoryTransaction(
      id: 'INV-TXN-${_inventoryTxnCounter++}',
      itemId: item.id,
      itemName: item.name,
      type: type,
      quantity: qty,
      date: _formatDateTimeDisplay(DateTime.now()),
      performedByUsername: widget.currentUser.username,
      region: item.region,
      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      relatedWorkOrderId: relatedWorkOrderId,
    );
    try {
      // The Firestore transaction inside adjustInventoryQuantity is what actually prevents
      // two concurrent stock-outs from over-drawing the same item - the check above is just
      // a fast local pre-check to avoid a round trip for obviously-wrong input. The item's
      // displayed quantity updates itself via the live inventory stream once this commits.
      await DataService.adjustInventoryQuantity(item.id, delta);
      await DataService.saveInventoryTransaction(txn);
      setState(() => sampleInventoryTransactions.add(txn));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      _endAction();
    }
  }

  // Checks a quantity of an item out to a specific employee - reduces available stock the
  // same way a Stock Out does (and writes the same InventoryTransaction ledger entry, so the
  // Transaction Log stays the single complete explanation of every quantity change), plus a
  // ToolAssignment record so "what does this employee currently have" can be answered
  // directly instead of by scanning the whole transaction log for their name.
  Future<void> _assignTool() async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employee accounts to assign to yet'), backgroundColor: AESColors.darkGrey),
      );
      return;
    }
    final availableItems = _visibleItems.where((i) => i.quantity > 0).toList()..sort((a, b) => a.name.compareTo(b.name));
    if (availableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items with stock on hand to assign'), backgroundColor: AESColors.darkGrey),
      );
      return;
    }

    InventoryItem selectedItem = availableItems.first;
    String selectedUsername = _employees.first['username'];
    final qtyController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    String? errorMessage;
    final relatedOrders = (widget.perms.seesAllRegions ? sampleWorkOrders : sampleWorkOrders.where((w) => w.region == widget.currentUser.region)).toList();
    String? relatedWorkOrderId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('Assign Tool')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<InventoryItem>(
                      initialValue: selectedItem,
                      decoration: const InputDecoration(labelText: 'Item', border: OutlineInputBorder(), isDense: true),
                      items: availableItems
                          .map((i) => DropdownMenuItem(value: i, child: Text('${i.name} (${i.quantity.toStringAsFixed(0)} ${i.unit} available)', overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedItem = v ?? selectedItem),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUsername,
                      decoration: const InputDecoration(labelText: 'Assign To', border: OutlineInputBorder(), isDense: true),
                      items: _employees.map((e) => DropdownMenuItem(value: e['username'] as String, child: Text(e['username']))).toList(),
                      onChanged: (v) => setDialogState(() => selectedUsername = v ?? selectedUsername),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Quantity (${selectedItem.unit})', border: const OutlineInputBorder(), isDense: true),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      initialValue: relatedWorkOrderId,
                      decoration: const InputDecoration(labelText: 'For Work Order (optional)', border: OutlineInputBorder(), isDense: true),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(tr('None - general stock'))),
                        ...relatedOrders.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text('WO #${w.id} - ${w.siteName}', overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setDialogState(() => relatedWorkOrderId = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () {
                    final qty = double.tryParse(qtyController.text.trim());
                    if (qty == null || qty <= 0) {
                      setDialogState(() => errorMessage = 'Enter a quantity greater than 0');
                      return;
                    }
                    if (qty > selectedItem.quantity) {
                      setDialogState(() => errorMessage = 'Only ${selectedItem.quantity.toStringAsFixed(0)} ${selectedItem.unit} available');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(tr('Confirm')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    final qty = double.tryParse(qtyController.text.trim());
    if (qty == null || qty <= 0 || qty > selectedItem.quantity) return;
    if (!await _beginAction()) return;

    final now = DateTime.now();
    final assignment = ToolAssignment(
      itemId: selectedItem.id,
      itemName: selectedItem.name,
      quantity: qty,
      unit: selectedItem.unit,
      assignedToUsername: selectedUsername,
      assignedByUsername: widget.currentUser.username,
      region: selectedItem.region,
      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      relatedWorkOrderId: relatedWorkOrderId,
    );
    final txn = InventoryTransaction(
      id: 'INV-TXN-${_inventoryTxnCounter++}',
      itemId: selectedItem.id,
      itemName: selectedItem.name,
      type: InventoryTxnType.stockOut,
      quantity: qty,
      date: _formatDateTimeDisplay(now),
      performedByUsername: widget.currentUser.username,
      region: selectedItem.region,
      note: 'Assigned to $selectedUsername${relatedWorkOrderId != null ? ' for WO #$relatedWorkOrderId' : ''}',
      relatedWorkOrderId: relatedWorkOrderId,
    );
    try {
      await DataService.adjustInventoryQuantity(selectedItem.id, -qty);
      await DataService.saveInventoryTransaction(txn);
      await DataService.saveToolAssignment(assignment);
      setState(() {
        sampleInventoryTransactions.add(txn);
        sampleToolAssignments.add(assignment);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      _endAction();
    }
  }

  // Marks a checked-out tool as returned and restores its quantity to available stock (a
  // normal Stock In, same as _assignTool writes a Stock Out) - the ToolAssignment itself is
  // kept, not deleted, so "who had this tool and when" stays in the record.
  Future<void> _returnAssignment(ToolAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Mark Returned')),
        content: Text('Mark ${assignment.quantity.toStringAsFixed(0)} ${assignment.unit} of "${assignment.itemName}" as returned by ${assignment.assignedToUsername}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _beginAction()) return;

    final now = DateTime.now();
    final txn = InventoryTransaction(
      id: 'INV-TXN-${_inventoryTxnCounter++}',
      itemId: assignment.itemId,
      itemName: assignment.itemName,
      type: InventoryTxnType.stockIn,
      quantity: assignment.quantity,
      date: _formatDateTimeDisplay(now),
      performedByUsername: widget.currentUser.username,
      region: assignment.region,
      note: 'Returned by ${assignment.assignedToUsername}',
    );
    final previousStatus = assignment.status;
    final previousReturnedDate = assignment.returnedDate;
    setState(() {
      assignment.status = ToolAssignmentStatus.returned;
      assignment.returnedDate = _formatDateTimeDisplay(now);
    });
    try {
      await DataService.adjustInventoryQuantity(assignment.itemId, assignment.quantity);
      await DataService.saveInventoryTransaction(txn);
      await DataService.saveToolAssignment(assignment);
      setState(() => sampleInventoryTransactions.add(txn));
    } catch (e) {
      setState(() {
        assignment.status = previousStatus;
        assignment.returnedDate = previousReturnedDate;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      _endAction();
    }
  }

  // Corrects who a still-checked-out tool is assigned to, its linked work order, or its
  // note - deliberately doesn't touch quantity or the item itself, since either of those
  // would need re-doing the stock math this assignment already recorded. A quantity/item
  // mistake is cleaner to fix by returning the wrong assignment and creating a fresh one.
  Future<void> _editAssignment(ToolAssignment assignment) async {
    if (_employees.isEmpty) return;
    String selectedUsername = assignment.assignedToUsername;
    final relatedOrders = (widget.perms.seesAllRegions ? sampleWorkOrders : sampleWorkOrders.where((w) => w.region == widget.currentUser.region)).toList();
    String? relatedWorkOrderId = assignment.relatedWorkOrderId;
    final noteController = TextEditingController(text: assignment.note ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Assignment - ${assignment.itemName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _employees.any((e) => e['username'] == selectedUsername) ? selectedUsername : null,
                      decoration: const InputDecoration(labelText: 'Assign To', border: OutlineInputBorder(), isDense: true),
                      items: _employees.map((e) => DropdownMenuItem(value: e['username'] as String, child: Text(e['username']))).toList(),
                      onChanged: (v) => setDialogState(() => selectedUsername = v ?? selectedUsername),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      initialValue: relatedWorkOrderId,
                      decoration: const InputDecoration(labelText: 'For Work Order (optional)', border: OutlineInputBorder(), isDense: true),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(tr('None - general stock'))),
                        ...relatedOrders.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text('WO #${w.id} - ${w.siteName}', overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setDialogState(() => relatedWorkOrderId = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    if (!await _beginAction()) return;

    final previousUsername = assignment.assignedToUsername;
    final previousWorkOrderId = assignment.relatedWorkOrderId;
    final previousNote = assignment.note;
    setState(() {
      assignment.assignedToUsername = selectedUsername;
      assignment.relatedWorkOrderId = relatedWorkOrderId;
      assignment.note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
    });
    try {
      await DataService.saveToolAssignment(assignment);
    } catch (e) {
      setState(() {
        assignment.assignedToUsername = previousUsername;
        assignment.relatedWorkOrderId = previousWorkOrderId;
        assignment.note = previousNote;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      _endAction();
    }
  }

  // Deleting a still-checked-out assignment restores its quantity to stock first (same as
  // marking it returned) so removing a mistaken assignment can never silently leave an item
  // permanently missing from the count. An already-returned assignment has no stock effect
  // to undo - it's just removed as a record.
  Future<void> _deleteAssignment(ToolAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete')),
        content: Text(
          assignment.status == ToolAssignmentStatus.assigned
              ? 'Delete this assignment? ${assignment.quantity.toStringAsFixed(0)} ${assignment.unit} of "${assignment.itemName}" will be restored to stock.'
              : 'Delete this assignment record? This cannot be undone.',
        ),
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
    if (!await _beginAction()) return;

    try {
      if (assignment.status == ToolAssignmentStatus.assigned) {
        final txn = InventoryTransaction(
          id: 'INV-TXN-${_inventoryTxnCounter++}',
          itemId: assignment.itemId,
          itemName: assignment.itemName,
          type: InventoryTxnType.stockIn,
          quantity: assignment.quantity,
          date: _formatDateTimeDisplay(DateTime.now()),
          performedByUsername: widget.currentUser.username,
          region: assignment.region,
          note: 'Assignment to ${assignment.assignedToUsername} deleted/cancelled',
        );
        await DataService.adjustInventoryQuantity(assignment.itemId, assignment.quantity);
        await DataService.saveInventoryTransaction(txn);
        sampleInventoryTransactions.add(txn);
      }
      await DataService.deleteToolAssignment(assignment.id);
      setState(() => sampleToolAssignments.removeWhere((a) => a.id == assignment.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      _endAction();
    }
  }

  // Imports (or re-imports) a stock count sheet at any time - matches an existing item by
  // name within the target region and adjusts its quantity to whatever the sheet says
  // (writing a normal stockIn/stockOut InventoryTransaction so the Transaction Log still
  // fully explains the change, same invariant _assignTool/_recordTransaction already keep),
  // or creates a new item if the name isn't already on file. Column headers are matched
  // flexibly (case-insensitive, several common aliases) since the exact wording of a
  // real-world stock sheet varies.
  Future<void> _importInventoryExcel() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls']),
    ]);
    if (file == null) return;

    // A user who can see every region needs to say which store this sheet belongs to,
    // unless the sheet itself has its own Region column (checked once the file is parsed) -
    // a region-scoped user (e.g. a single-region Store Manager) never needs to be asked.
    String? chosenRegion;
    if (widget.perms.seesAllRegions && mounted) {
      chosenRegion = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr('Which store is this sheet for?')),
          children: [
            for (final r in const ['Multan', 'Lahore', 'Faisalabad'])
              SimpleDialogOption(onPressed: () => Navigator.pop(context, r), child: Text(r)),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(tr('Sheet has its own Region column')),
            ),
          ],
        ),
      );
      if (chosenRegion == null) return; // dismissed without choosing
    }
    final defaultRegion = chosenRegion?.isEmpty == true ? null : (chosenRegion ?? widget.currentUser.region);

    setState(() => _importing = true);
    try {
      final bytes = await file.readAsBytes();
      final workbook = xls.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) throw Exception('No sheets found in this file');
      final sheet = workbook.tables[workbook.tables.keys.first]!;
      if (sheet.rows.length < 2) throw Exception('The sheet appears to be empty');

      final headerRow = sheet.rows.first;
      final headerIndex = <String, int>{};
      for (int i = 0; i < headerRow.length; i++) {
        final text = headerRow[i]?.value?.toString().trim().toLowerCase();
        if (text != null && text.isNotEmpty) headerIndex[text] = i;
      }
      int? findCol(List<String> aliases) {
        for (final a in aliases) {
          if (headerIndex.containsKey(a)) return headerIndex[a];
        }
        return null;
      }

      final nameCol = findCol(['item', 'item name', 'name', 'description', 'material']);
      final categoryCol = findCol(['category', 'type']);
      final unitCol = findCol(['unit', 'uom', 'units']);
      final qtyCol = findCol(['quantity', 'qty', 'stock', 'current stock', 'stock qty', 'balance', 'closing stock']);
      final reorderCol = findCol(['reorder', 'reorder level', 'min stock', 'minimum stock', 'low stock alert']);
      final regionCol = findCol(['region', 'store', 'location', 'warehouse']);

      if (nameCol == null || qtyCol == null) {
        throw Exception('Could not find both an Item Name column and a Quantity column - check the sheet\'s headers');
      }
      if (defaultRegion == null && regionCol == null) {
        throw Exception('Sheet has no Region column, and no region was chosen - nowhere to file these items');
      }

      String cellText(List<xls.Data?> row, int? col) {
        if (col == null || col >= row.length) return '';
        return row[col]?.value?.toString().trim() ?? '';
      }

      int created = 0;
      int updated = 0;
      for (int r = 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        final name = cellText(row, nameCol);
        if (name.isEmpty) continue;
        final qty = double.tryParse(cellText(row, qtyCol).replaceAll(',', '')) ?? 0;
        final category = categoryCol != null ? cellText(row, categoryCol) : '';
        final unit = unitCol != null ? cellText(row, unitCol) : '';
        final reorder = reorderCol != null ? double.tryParse(cellText(row, reorderCol).replaceAll(',', '')) : null;
        final sheetRegion = regionCol != null ? cellText(row, regionCol) : '';
        final region = sheetRegion.isNotEmpty ? sheetRegion : defaultRegion!;

        InventoryItem? existingItem;
        for (final item in sampleInventoryItems) {
          if (item.region == region && item.name.toLowerCase() == name.toLowerCase()) {
            existingItem = item;
            break;
          }
        }

        if (existingItem != null) {
          final delta = qty - existingItem.quantity;
          if (delta != 0) {
            final txn = InventoryTransaction(
              id: 'INV-TXN-${_inventoryTxnCounter++}',
              itemId: existingItem.id,
              itemName: existingItem.name,
              type: delta > 0 ? InventoryTxnType.stockIn : InventoryTxnType.stockOut,
              quantity: delta.abs(),
              date: _formatDateTimeDisplay(DateTime.now()),
              performedByUsername: widget.currentUser.username,
              region: region,
              note: 'Imported from Excel sheet',
            );
            await DataService.adjustInventoryQuantity(existingItem.id, delta);
            await DataService.saveInventoryTransaction(txn);
            sampleInventoryTransactions.add(txn);
          }
          var metaChanged = false;
          if (category.isNotEmpty && existingItem.category != category) {
            existingItem.category = category;
            metaChanged = true;
          }
          if (unit.isNotEmpty && existingItem.unit != unit) {
            existingItem.unit = unit;
            metaChanged = true;
          }
          if (reorder != null && existingItem.reorderLevel != reorder) {
            existingItem.reorderLevel = reorder;
            metaChanged = true;
          }
          if (metaChanged) await DataService.saveInventoryItem(existingItem);
          updated++;
        } else {
          final newItem = InventoryItem(
            id: 'INV-ITEM-${_inventoryItemCounter++}',
            name: name,
            unit: unit.isEmpty ? 'pcs' : unit,
            category: category.isEmpty ? 'General' : category,
            region: region,
            quantity: 0,
            reorderLevel: reorder ?? 0,
          );
          await DataService.saveInventoryItem(newItem);
          sampleInventoryItems.add(newItem);
          if (qty > 0) {
            final txn = InventoryTransaction(
              id: 'INV-TXN-${_inventoryTxnCounter++}',
              itemId: newItem.id,
              itemName: newItem.name,
              type: InventoryTxnType.stockIn,
              quantity: qty,
              date: _formatDateTimeDisplay(DateTime.now()),
              performedByUsername: widget.currentUser.username,
              region: region,
              note: 'Imported from Excel sheet',
            );
            await DataService.adjustInventoryQuantity(newItem.id, qty);
            await DataService.saveInventoryTransaction(txn);
            sampleInventoryTransactions.add(txn);
          }
          created++;
        }
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported: $created new item${created == 1 ? '' : 's'}, $updated updated'),
            backgroundColor: AESColors.darkGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
    if (mounted) setState(() => _importing = false);
  }

  Future<void> _addItem() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    final unitController = TextEditingController(text: 'pcs');
    final reorderController = TextEditingController(text: '0');
    final initialQtyController = TextEditingController(text: '0');
    String region = widget.perms.seesAllRegions ? 'Lahore' : widget.currentUser.region;
    String? nameError;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('Add Inventory Item')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: unitController,
                            decoration: const InputDecoration(labelText: 'Unit (pcs, box...)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (widget.perms.seesAllRegions)
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: region,
                              decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder(), isDense: true),
                              items: const ['Multan', 'Lahore', 'Faisalabad'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (v) => setDialogState(() => region = v ?? region),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: initialQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Starting Quantity', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: reorderController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Low Stock Alert At', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      setDialogState(() => nameError = 'Enter an item name');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(tr('Add Item')),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) return;
    if (!await _beginAction()) return;
    final startingQty = double.tryParse(initialQtyController.text.trim()) ?? 0;
    final item = InventoryItem(
      id: 'INV-ITEM-${_inventoryItemCounter++}',
      name: nameController.text.trim(),
      unit: unitController.text.trim().isEmpty ? 'pcs' : unitController.text.trim(),
      category: categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
      region: region,
      quantity: 0,
      reorderLevel: double.tryParse(reorderController.text.trim()) ?? 0,
    );
    try {
      await DataService.saveInventoryItem(item);
      setState(() => sampleInventoryItems.add(item));
      // Every quantity change - including the starting stock - goes through the same
      // ledger path, so the transaction log always fully explains the current quantity.
      if (startingQty > 0) {
        await _recordInitialStock(item, startingQty);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      _endAction();
    }
  }

  // Edits the item's own details (name/category/unit/reorder level/region) - deliberately
  // separate from Stock In/Out, which only ever change quantity through the transactional
  // adjustInventoryQuantity ledger path. This never touches quantity.
  Future<void> _editItem(InventoryItem item) async {
    final nameController = TextEditingController(text: item.name);
    final categoryController = TextEditingController(text: item.category);
    final unitController = TextEditingController(text: item.unit);
    final reorderController = TextEditingController(text: item.reorderLevel.toStringAsFixed(0));
    String region = item.region;
    String? nameError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('Edit Inventory Item')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(labelText: 'Item Name', border: const OutlineInputBorder(), isDense: true, errorText: nameError),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: unitController,
                            decoration: const InputDecoration(labelText: 'Unit (pcs, box...)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: region,
                            decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder(), isDense: true),
                            items: const ['Multan', 'Lahore', 'Faisalabad'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (v) => setDialogState(() => region = v ?? region),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reorderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Low Stock Alert At', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      setDialogState(() => nameError = 'Enter an item name');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    if (!await _beginAction()) return;
    final previous = InventoryItem(
      id: item.id,
      name: item.name,
      unit: item.unit,
      category: item.category,
      region: item.region,
      quantity: item.quantity,
      reorderLevel: item.reorderLevel,
    );
    setState(() {
      item.name = nameController.text.trim();
      item.category = categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim();
      item.unit = unitController.text.trim().isEmpty ? 'pcs' : unitController.text.trim();
      item.region = region;
      item.reorderLevel = double.tryParse(reorderController.text.trim()) ?? item.reorderLevel;
    });
    try {
      await DataService.saveInventoryItem(item);
    } catch (e) {
      setState(() {
        item.name = previous.name;
        item.category = previous.category;
        item.unit = previous.unit;
        item.region = previous.region;
        item.reorderLevel = previous.reorderLevel;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      _endAction();
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete Item')),
        content: Text('Delete "${item.name}"? This removes it from the stock list - the transaction history stays as a record. This cannot be undone.'),
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
    if (!await _beginAction()) return;
    try {
      await DataService.deleteInventoryItem(item.id);
      setState(() => sampleInventoryItems.removeWhere((i) => i.id == item.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete item: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      _endAction();
    }
  }

  Future<void> _recordInitialStock(InventoryItem item, double qty) async {
    final txn = InventoryTransaction(
      id: 'INV-TXN-${_inventoryTxnCounter++}',
      itemId: item.id,
      itemName: item.name,
      type: InventoryTxnType.stockIn,
      quantity: qty,
      date: _formatDateTimeDisplay(DateTime.now()),
      performedByUsername: widget.currentUser.username,
      region: item.region,
      note: 'Starting stock',
    );
    await DataService.adjustInventoryQuantity(item.id, qty);
    await DataService.saveInventoryTransaction(txn);
    if (mounted) setState(() => sampleInventoryTransactions.add(txn));
  }

  Future<void> _exportTransactionsCsv() async {
    final rows = <List<String>>[
      ['Date', 'Item', 'Type', 'Quantity', 'Region', 'Performed By', 'Related Work Order', 'Note'],
      for (final t in _filteredTxns)
        [
          t.date,
          t.itemName,
          t.type == InventoryTxnType.stockIn ? 'Stock In' : 'Stock Out',
          t.quantity.toStringAsFixed(0),
          t.region,
          t.performedByUsername,
          t.relatedWorkOrderId ?? '',
          t.note ?? '',
        ],
    ];
    await ExportService.exportRowsWithFormatChoice(context, title: 'Inventory Transactions', rows: rows, filenameBase: 'AES_Inventory_Transactions');
  }

  // Snapshot report of current stock on hand, separate from the transaction ledger above -
  // this answers "what do we have right now", the ledger answers "what moved and when".
  Future<void> _exportStockCsv() async {
    final rows = <List<String>>[
      ['Item', 'Category', 'Region', 'Quantity', 'Unit', 'Low Stock Alert At', 'Low Stock?'],
      for (final i in _filteredItems)
        [
          i.name,
          i.category,
          i.region,
          i.quantity.toStringAsFixed(0),
          i.unit,
          i.reorderLevel.toStringAsFixed(0),
          i.isLowStock ? 'Yes' : 'No',
        ],
    ];
    await ExportService.exportRowsWithFormatChoice(context, title: 'Inventory Stock Levels', rows: rows, filenameBase: 'AES_Inventory_Stock_Levels');
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final txns = _filteredTxns;
    final assignments = _filteredAssignments;
    final lowStockCount = _visibleItems.where((i) => i.isLowStock).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Inventory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Uploading a stock sheet is available to everyone who can see inventory
                  // at all (Store Manager, Finance, OM, Head of Ops, CEO) - Finance in
                  // particular needs this for reconciling store counts, not just viewing
                  // them. Actual hands-on management (Add Item, Assign Tool) stays with
                  // Store Manager/CEO below, unchanged.
                  if (widget.perms.canViewInventory && _tab == _InventoryTab.stock) ...[
                    OutlinedButton.icon(
                      onPressed: _importing ? null : _importInventoryExcel,
                      icon: _importing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file_outlined, size: 18),
                      label: Text(tr('Upload Sheet')),
                      style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
                    ),
                  ],
                  if (widget.perms.canManageInventory)
                    ElevatedButton.icon(
                      onPressed: _tab == _InventoryTab.assignments ? _assignTool : _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr(_tab == _InventoryTab.assignments ? 'Assign Tool' : 'Add Item')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AESColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (lowStockCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('$lowStockCount item${lowStockCount == 1 ? '' : 's'} at or below the low-stock alert level',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepOrange)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InventoryTabButton(label: 'Stock Levels', selected: _tab == _InventoryTab.stock, onTap: () => setState(() => _tab = _InventoryTab.stock)),
              _InventoryTabButton(label: 'Transaction Log', selected: _tab == _InventoryTab.transactions, onTap: () => setState(() => _tab = _InventoryTab.transactions)),
              _InventoryTabButton(label: 'Assignments', selected: _tab == _InventoryTab.assignments, onTap: () => setState(() => _tab = _InventoryTab.assignments)),
              if (_tab != _InventoryTab.assignments)
                OutlinedButton.icon(
                  onPressed: _tab == _InventoryTab.transactions
                      ? (txns.isEmpty ? null : _exportTransactionsCsv)
                      : (items.isEmpty ? null : _exportStockCsv),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(tr('Export')),
                  style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.perms.seesAllRegions) ...[
            _FilterDropdown(
              label: 'Region',
              value: _regionFilter,
              options: const ['All', 'Multan', 'Lahore', 'Faisalabad'],
              onChanged: (v) => setState(() => _regionFilter = v),
            ),
            const SizedBox(height: 16),
          ],
          if (_tab == _InventoryTab.stock) ...[
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search items...',
                prefixIcon: Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(tr('No inventory items yet'), style: TextStyle(color: AESColors.grey))),
              )
            else
              for (final item in items)
                _InventoryItemTile(
                  item: item,
                  perms: widget.perms,
                  onStockIn: () => _recordTransaction(item, InventoryTxnType.stockIn),
                  onStockOut: () => _recordTransaction(item, InventoryTxnType.stockOut),
                  onEdit: () => _editItem(item),
                  onDelete: () => _deleteItem(item),
                ),
          ] else if (_tab == _InventoryTab.assignments) ...[
            if (assignments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(tr('No tools assigned yet'), style: const TextStyle(color: AESColors.grey))),
              )
            else
              for (final assignment in assignments)
                _ToolAssignmentTile(
                  assignment: assignment,
                  canManage: widget.perms.canManageInventory,
                  onReturn: () => _returnAssignment(assignment),
                  onEdit: () => _editAssignment(assignment),
                  onDelete: () => _deleteAssignment(assignment),
                ),
          ] else ...[
            if (txns.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(tr('No stock movements recorded yet'), style: TextStyle(color: AESColors.grey))),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(tr('Date'))),
                    DataColumn(label: Text(tr('Item'))),
                    DataColumn(label: Text(tr('Type'))),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text(tr('Region'))),
                    DataColumn(label: Text('By')),
                    DataColumn(label: Text(tr('Work Order'))),
                    DataColumn(label: Text(tr('Note'))),
                  ],
                  rows: [
                    for (final t in txns)
                      DataRow(cells: [
                        DataCell(Text(t.date)),
                        DataCell(Text(t.itemName)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.type == InventoryTxnType.stockIn ? Icons.arrow_downward : Icons.arrow_upward,
                                size: 14, color: t.type == InventoryTxnType.stockIn ? AESColors.primaryGreen : Colors.deepOrange),
                            const SizedBox(width: 4),
                            Text(t.type == InventoryTxnType.stockIn ? 'In' : 'Out'),
                          ],
                        )),
                        DataCell(Text(t.quantity.toStringAsFixed(0))),
                        DataCell(Text(t.region)),
                        DataCell(Text(t.performedByUsername)),
                        DataCell(Text(t.relatedWorkOrderId ?? '-')),
                        DataCell(Text(t.note ?? '-')),
                      ]),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InventoryTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _InventoryTabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AESColors.primaryGreen : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AESColors.darkGrey)),
        ),
      ),
    );
  }
}

class _InventoryItemTile extends StatelessWidget {
  final InventoryItem item;
  final Permissions perms;
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _InventoryItemTile({
    required this.item,
    required this.perms,
    required this.onStockIn,
    required this.onStockOut,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nameSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: Text(item.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey))),
            if (item.isLowStock) ...[
              const SizedBox(width: 8),
              const Icon(Icons.warning_amber_outlined, size: 14, color: Colors.orange),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text('${item.category} · ${item.region}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
      ],
    );
    final quantityText = Text('${item.quantity.toStringAsFixed(0)} ${item.unit}',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: item.isLowStock ? Colors.deepOrange : AESColors.darkGreen));
    // Compact density so up to 4 icon buttons (Stock In/Out, Edit, Delete) fit comfortably
    // on a phone-width row instead of overflowing - the default IconButton hit target is
    // sized for a handful of icons spread across a whole toolbar, not 4 in a row this narrow.
    final actionIcons = !perms.canManageInventory
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Stock In',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline, color: AESColors.primaryGreen, size: 20),
                onPressed: onStockIn,
              ),
              IconButton(
                tooltip: 'Stock Out',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange, size: 20),
                onPressed: onStockOut,
              ),
              IconButton(
                tooltip: 'Edit Details',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, color: AESColors.grey, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Delete Item',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: onDelete,
              ),
            ],
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: item.isLowStock ? Border.all(color: Colors.orange, width: 1.4) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      // Below ~420px there's no room for name + quantity + 4 action icons on one line, so
      // it stacks instead: name/category on top, quantity and actions on their own row
      // underneath - same "switch to a stacked layout on mobile" pattern used across the
      // app's other responsive fixes, rather than letting it overflow.
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 420) {
            return Row(
              children: [
                Expanded(child: nameSection),
                quantityText,
                if (actionIcons != null) ...[const SizedBox(width: 4), actionIcons],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              nameSection,
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  quantityText,
                  if (actionIcons != null) actionIcons,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolAssignmentTile extends StatelessWidget {
  final ToolAssignment assignment;
  final bool canManage;
  final VoidCallback onReturn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ToolAssignmentTile({
    required this.assignment,
    required this.canManage,
    required this.onReturn,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAssigned = assignment.status == ToolAssignmentStatus.assigned;
    final statusColor = isAssigned ? Colors.deepOrange : AESColors.primaryGreen;

    final detailsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${assignment.itemName} · ${assignment.quantity.toStringAsFixed(0)} ${assignment.unit}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey)),
        const SizedBox(height: 3),
        Text(
          'Assigned to ${assignment.assignedToUsername} · ${assignment.assignedDate}'
          '${assignment.relatedWorkOrderId != null ? ' · WO #${assignment.relatedWorkOrderId}' : ''}',
          style: const TextStyle(fontSize: 12, color: AESColors.grey),
        ),
        if (assignment.status == ToolAssignmentStatus.returned && assignment.returnedDate != null)
          Text('Returned ${assignment.returnedDate}', style: const TextStyle(fontSize: 12, color: AESColors.primaryGreen)),
        if (assignment.note != null && assignment.note!.isNotEmpty)
          Text(assignment.note!, style: const TextStyle(fontSize: 12, color: AESColors.grey, fontStyle: FontStyle.italic)),
      ],
    );
    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(isAssigned ? 'Assigned' : 'Returned', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
    );
    // A status chip, Edit/Delete icons, and a "Mark Returned" button with a full text label
    // is a lot to fit in one row on a phone - Wrap lets it flow onto a second line instead
    // of overflowing, rather than trying to force everything onto one line.
    final actions = !canManage
        ? statusChip
        : Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              statusChip,
              if (isAssigned)
                IconButton(
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, color: AESColors.grey, size: 20),
                  onPressed: onEdit,
                ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: onDelete,
              ),
              if (isAssigned)
                OutlinedButton(
                  onPressed: onReturn,
                  style: OutlinedButton.styleFrom(foregroundColor: AESColors.primaryGreen, visualDensity: VisualDensity.compact),
                  child: Text(tr('Mark Returned')),
                ),
            ],
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 460) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: detailsSection),
                const SizedBox(width: 8),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detailsSection,
              const SizedBox(height: 10),
              actions,
            ],
          );
        },
      ),
    );
  }
}

