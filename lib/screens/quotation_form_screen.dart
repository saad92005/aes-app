part of '../main.dart';

// ---------------- QUOTATION FORM SCREEN ----------------
class QuotationFormScreen extends StatefulWidget {
  final WorkOrder workOrder;
  final QuotationData? existingQuotation;
  const QuotationFormScreen({super.key, required this.workOrder, this.existingQuotation});

  @override
  State<QuotationFormScreen> createState() => _QuotationFormScreenState();
}

class _QuotationFormScreenState extends State<QuotationFormScreen> {
  late TextEditingController _clientNameController;
  late TextEditingController _clientCompanyController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  final FocusNode _clientNameFocusNode = FocusNode();
  late List<_LineItemRow> _lineRows;
  List<String> _beforePhotos = [];
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingQuotation != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingQuotation != null) {
      final q = widget.existingQuotation!;
      _clientNameController = TextEditingController(text: q.clientName);
      _clientCompanyController = TextEditingController(text: q.clientCompany);
      _descriptionController = TextEditingController(text: q.descriptionOfWorkOrder);
      _notesController = TextEditingController(text: q.notes);
      _lineRows = q.lineItems
          .map((i) => _LineItemRow()
            ..descController.text = i.description
            ..unitController.text = i.unit
            ..qtyController.text = i.qty.toStringAsFixed(0)
            ..rateController.text = i.rate.toStringAsFixed(0)
            ..cmepStatus = i.cmepStatus
            ..internalCostController.text = i.internalCost.toStringAsFixed(0)
            ..remarksController.text = i.remarks)
          .toList();
      if (_lineRows.isEmpty) _lineRows = [_LineItemRow()];
      _beforePhotos = List.from(q.beforePhotoUrls);
    } else {
      _clientNameController = TextEditingController();
      _clientCompanyController = TextEditingController();
      _descriptionController = TextEditingController(text: widget.workOrder.description);
      // Pre-filled from the employee's site visit, if they've submitted one, so Back Office
      // doesn't have to retype the description or re-request photos already on file.
      _notesController = TextEditingController(text: widget.workOrder.employeeNotes ?? '');
      _lineRows = [_LineItemRow()];
      _loadBeforePhotos();
    }
  }

  @override
  void dispose() {
    _clientNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBeforePhotos() async {
    final photos = await DataService.loadWorkOrderPhotos(widget.workOrder.id, 'employee');
    if (mounted) setState(() => _beforePhotos = photos);
  }

  void _addRow() => setState(() => _lineRows.add(_LineItemRow()));
  void _removeRow(int index) => setState(() => _lineRows.removeAt(index));

  // Saves this name/company combo to the shared client list if it's genuinely new, so the
  // next quotation (of the hundreds sent in a single day) can just pick it from the
  // autocomplete instead of retyping it - mirrors how ManageSitesScreen grows sampleSites.
  Future<void> _ensureClientSaved() async {
    final name = _clientNameController.text.trim();
    final company = _clientCompanyController.text.trim();
    if (name.isEmpty) return;
    final alreadyKnown = sampleClients.any(
      (c) => c.name.toLowerCase() == name.toLowerCase() && c.company.toLowerCase() == company.toLowerCase(),
    );
    if (alreadyKnown) return;
    final newClient = ClientEntry(id: 'CLIENT-${_clientCounter++}', name: name, company: company);
    sampleClients.add(newClient);
    try {
      await DataService.saveClient(newClient);
    } catch (_) {
      // Not fatal to the quotation - the typed name/company is saved on the quotation
      // itself either way, this only means it won't show up in the dropdown next time.
    }
  }

  Future<void> _submit() async {
    // Guards against the same repeated-tap / slow-network duplicate-submission issue as every
    // other important form in the app - without this, a slow save left the button tappable
    // and a second tap could send this quotation (and the work order status change) twice.
    if (_isSubmitting) return;
    // The Submit button previously had no validation at all - a misclick or a forgotten
    // field could send a work order to "Quotation Ready" (and later out to a real client by
    // email) with a blank client name or a Rs 0 quotation with no line items at all.
    if (_clientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enter the client name before submitting')), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final items = _lineRows
        .where((r) => r.descController.text.trim().isNotEmpty)
        .map((r) => QuotationLineItem(
              description: r.descController.text.trim(),
              unit: r.unitController.text.trim().isEmpty ? 'Job' : r.unitController.text.trim(),
              qty: double.tryParse(r.qtyController.text.trim()) ?? 1,
              rate: double.tryParse(r.rateController.text.trim()) ?? 0,
              cmepStatus: r.cmepStatus,
              internalCost: r.internalCost,
              remarks: r.remarksController.text.trim(),
            ))
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Add at least one line item before submitting')), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (items.every((i) => i.rate <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('At least one line item needs a rate greater than 0')), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_isEditing) {
      widget.workOrder.quotation = QuotationData(
        id: widget.existingQuotation!.id,
        date: widget.existingQuotation!.date,
        clientName: _clientNameController.text.trim(),
        clientCompany: _clientCompanyController.text.trim(),
        siteName: widget.workOrder.siteName,
        descriptionOfWorkOrder: _descriptionController.text.trim(),
        lineItems: items,
        region: widget.workOrder.region,
        beforePhotoUrls: _beforePhotos,
        notes: _notesController.text.trim(),
      );
      widget.workOrder.rejectionNote = null;
      widget.workOrder.rejectedByRole = null;
    } else {
      widget.workOrder.quotation = QuotationData(
        clientName: _clientNameController.text.trim(),
        clientCompany: _clientCompanyController.text.trim(),
        siteName: widget.workOrder.siteName,
        descriptionOfWorkOrder: _descriptionController.text.trim(),
        lineItems: items,
        region: widget.workOrder.region,
        beforePhotoUrls: _beforePhotos,
        notes: _notesController.text.trim(),
      );
      widget.workOrder.status = WorkOrderStatus.quotationReady;
      widget.workOrder.rejectionNote = null;
      widget.workOrder.rejectedByRole = null;
    }

    setState(() => _isSubmitting = true);
    try {
      await _ensureClientSaved();
      await DataService.saveWorkOrder(widget.workOrder);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save quotation: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(
        backgroundColor: AESColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Quotation ${widget.existingQuotation!.id}' : 'Create Quotation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Calculator',
            onPressed: () {
              showDialog(context: context, builder: (context) => const _CalculatorDialog());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WO #${widget.workOrder.id} · ${widget.workOrder.siteName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.darkGreen)),
              const SizedBox(height: 20),
              Text(tr('Client Information'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RawAutocomplete<ClientEntry>(
                      textEditingController: _clientNameController,
                      focusNode: _clientNameFocusNode,
                      optionsBuilder: (textEditingValue) {
                        final q = textEditingValue.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<ClientEntry>.empty();
                        return sampleClients.where((c) => c.name.toLowerCase().contains(q));
                      },
                      displayStringForOption: (c) => c.name,
                      onSelected: (c) => setState(() => _clientCompanyController.text = c.company),
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Client contact name',
                            helperText: 'Start typing to pick a previous client',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    title: Text(option.name, style: const TextStyle(fontSize: 13)),
                                    subtitle: option.company.isEmpty ? null : Text(option.company, style: const TextStyle(fontSize: 11)),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _clientCompanyController,
                      decoration: const InputDecoration(labelText: 'Client company', filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(tr('Description of Work Order'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              PhotoPickerRow(
                label: 'Before Photos',
                photos: _beforePhotos,
                onPhotoAdded: (dataUrl) => setState(() => _beforePhotos.add(dataUrl)),
                onRemove: (i) => setState(() => _beforePhotos.removeAt(i)),
              ),
              const SizedBox(height: 20),
              Text(tr('Line Items'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
              const SizedBox(height: 4),
              Text(tr('Tap a cell to edit, just like a spreadsheet'), style: TextStyle(fontSize: 12, color: AESColors.grey)),
              const SizedBox(height: 10),
              _buildLineItemsTable(),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, color: AESColors.primaryGreen),
                label: Text(tr('Add Row'), style: TextStyle(color: AESColors.primaryGreen)),
              ),
              const SizedBox(height: 20),
              _buildTotalsSummary(),
              const SizedBox(height: 20),
              Text(tr('Notes / Terms'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Payment terms, validity, warranty, etc. (optional)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AESColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text(_isEditing ? tr('Save Changes') : tr('Submit Quotation')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _colDesc = 220;
  static const double _colUnit = 80;
  static const double _colQty = 60;
  static const double _colRate = 90;
  static const double _colAmount = 100;
  static const double _colCmep = 120;
  static const double _colInternalCost = 110;
  static const double _colRemarks = 160;
  static const double _colRemove = 44;

  Widget _tableHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AESColors.darkGreen)),
    );
  }

  Widget _buildLineItemsTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AESColors.lightGrey)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _tableHeaderCell('Description', _colDesc),
                  const SizedBox(width: 8),
                  _tableHeaderCell('Unit', _colUnit),
                  const SizedBox(width: 8),
                  _tableHeaderCell('Qty', _colQty),
                  const SizedBox(width: 8),
                  _tableHeaderCell('Rate', _colRate),
                  const SizedBox(width: 8),
                  _tableHeaderCell('CMEP', _colCmep),
                  const SizedBox(width: 8),
                  _tableHeaderCell('Amount', _colAmount),
                  const SizedBox(width: 8),
                  _tableHeaderCell('Internal Cost', _colInternalCost),
                  const SizedBox(width: 8),
                  _tableHeaderCell('AES Remarks', _colRemarks),
                  const SizedBox(width: 8),
                  const SizedBox(width: _colRemove),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  'Internal Cost is for your own records only - it never appears on the quotation the client sees. AES Remarks IS shown on the quotation.',
                  style: TextStyle(fontSize: 11, color: AESColors.grey, fontStyle: FontStyle.italic),
                ),
              ),
              const Divider(height: 20),
              for (int i = 0; i < _lineRows.length; i++) _buildTableRow(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(int i) {
    final row = _lineRows[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _colDesc,
            child: TextField(
              controller: row.descController,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _colUnit,
            child: TextField(
              controller: row.unitController,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _colQty,
            child: TextField(
              controller: row.qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _colRate,
            child: TextField(
              controller: row.rateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _colCmep,
            child: DropdownButtonFormField<String>(
              initialValue: row.cmepStatus,
              isDense: true,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
              items: [
                DropdownMenuItem(value: 'Non CMEP', child: Text(tr('Non CMEP'), style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'CMEP BOQ', child: Text('CMEP BOQ', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() => row.cmepStatus = v ?? 'Non CMEP'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _colAmount,
            child: Text(
              row.amount.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AESColors.darkGreen),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _colInternalCost,
            child: TextField(
              controller: row.internalCostController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _colRemarks,
            child: TextField(
              controller: row.remarksController,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _colRemove,
            child: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
              onPressed: _lineRows.length > 1 ? () => _removeRow(i) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSummary() {
    final grandTotal = _lineRows.fold<double>(0, (sum, r) => sum + r.amount);
    final totalInternalCost = _lineRows.fold<double>(0, (sum, r) => sum + r.internalCost);
    final profitMargin = grandTotal - totalInternalCost;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AESColors.lightGrey)),
      child: Column(
        children: [
          _totalRow('Grand Total', grandTotal, bold: true),
          const Divider(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(tr('Internal Only (not shown on the quotation)'), style: TextStyle(fontSize: 11, color: AESColors.grey, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          _totalRow('Total Internal Cost', totalInternalCost),
          const SizedBox(height: 6),
          _totalRow('Profit Margin', profitMargin),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: bold ? 16 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: AESColors.darkGrey)),
        Text('Rs ${value.toStringAsFixed(0)}',
            style: TextStyle(fontSize: bold ? 18 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: bold ? AESColors.primaryGreen : AESColors.darkGrey)),
      ],
    );
  }
}

