part of '../main.dart';

// ---------------- QUOTATIONS LIST SCREEN ----------------
class QuotationsListScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const QuotationsListScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<QuotationsListScreen> createState() => _QuotationsListScreenState();
}

class _QuotationsListScreenState extends State<QuotationsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateQuotationPicker() async {
    final eligible = (widget.perms.seesAllRegions
            ? sampleWorkOrders
            : sampleWorkOrders.where((w) => w.region == widget.currentUser.region))
        .where((w) => w.quotation == null)
        .toList();

    final selected = await showModalBottomSheet<WorkOrder>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('New Quotation'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                  const SizedBox(height: 4),
                  Text(tr('Create your own project, or pick from an existing work order'), style: TextStyle(fontSize: 12, color: AESColors.grey)),
                  const SizedBox(height: 16),
                  Material(
                    color: AESColors.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final newWorkOrder = await _showCreateProjectDialog();
                        if (newWorkOrder != null && context.mounted) {
                          Navigator.pop(context, newWorkOrder);
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle, color: AESColors.primaryGreen),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(tr('Create My Own Project'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGreen)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (eligible.isNotEmpty) ...[
                    Text(tr('Existing Work Orders'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGrey)),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: eligible.isEmpty
                        ? Center(child: Text(tr('No existing work orders to quote'), style: TextStyle(color: AESColors.grey, fontSize: 13)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: eligible.length,
                            itemBuilder: (context, i) {
                              final w = eligible[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                color: AESColors.lightGrey,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  title: Text(w.siteName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text('WO #${w.id} · ${w.region}', style: const TextStyle(fontSize: 12)),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.pop(context, w),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => QuotationFormScreen(workOrder: selected)));
      setState(() {});
    }
  }

  Future<WorkOrder?> _showCreateProjectDialog() async {
    final siteNameController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();
    String region = widget.perms.seesAllRegions ? 'Lahore' : widget.currentUser.region;
    DateTime? targetFinish = DateTime.now().add(const Duration(days: 3));

    return showDialog<WorkOrder>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('Create My Own Project')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: siteNameController,
                      decoration: const InputDecoration(labelText: 'Site / Project Name', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: region,
                      decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder(), isDense: true),
                      items: const ['Multan', 'Lahore', 'Faisalabad']
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => region = v ?? region),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickDateTime(context, initial: targetFinish ?? DateTime.now().add(const Duration(days: 3)));
                        if (picked != null) setDialogState(() => targetFinish = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Target Finish (SLA deadline)', border: OutlineInputBorder(), isDense: true),
                        child: Text(
                          targetFinish == null ? 'Tap to set' : _formatDateTimeDisplay(targetFinish!),
                          style: TextStyle(color: targetFinish == null ? AESColors.grey : AESColors.darkGrey, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description of Work', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () {
                    if (siteNameController.text.trim().isEmpty) return;
                    final now = DateTime.now();
                    final reportedStr = _formatDateTimeDisplay(now);
                    final newWorkOrder = WorkOrder(
                      id: _nextCustomWorkOrderId(),
                      siteName: siteNameController.text.trim().toUpperCase(),
                      address: addressController.text.trim(),
                      region: region,
                      priority: 2,
                      description: descriptionController.text.trim().isEmpty ? 'Custom project' : descriptionController.text.trim(),
                      targetDate: targetFinish != null ? _formatDateTimeDisplay(targetFinish!) : reportedStr,
                      targetDateIso: targetFinish?.toIso8601String(),
                      reportedDate: reportedStr,
                      status: WorkOrderStatus.pending,
                    );
                    sampleWorkOrders.add(newWorkOrder);
                    DataService.saveWorkOrder(newWorkOrder);
                    Navigator.pop(context, newWorkOrder);
                  },
                  child: Text(tr('Continue to Quotation')),
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
    List<WorkOrder> withQuotations = (widget.perms.seesAllRegions
            ? sampleWorkOrders
            : sampleWorkOrders.where((w) => w.region == widget.currentUser.region))
        .where((w) => w.quotation != null)
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      withQuotations = withQuotations
          .where((w) =>
              w.quotation!.id.toLowerCase().contains(q) ||
              w.id.toLowerCase().contains(q) ||
              w.siteName.toLowerCase().contains(q) ||
              w.quotation!.clientName.toLowerCase().contains(q) ||
              w.quotation!.clientCompany.toLowerCase().contains(q))
          .toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quotations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: _showCreateQuotationPicker,
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('New Quotation')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${withQuotations.length} quotation${withQuotations.length == 1 ? '' : 's'}', style: const TextStyle(color: AESColors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          ListSearchField(
            controller: _searchController,
            hintText: 'Search by quotation #, WO#, site, client...',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 20),
          if (withQuotations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _searchQuery.trim().isEmpty ? 'No quotations created yet' : 'No quotations match your search',
                  style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8)),
                ),
              ),
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

class _QuotationListCard extends StatelessWidget {
  final WorkOrder workOrder;
  final VoidCallback onTap;
  const _QuotationListCard({required this.workOrder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final q = workOrder.quotation!;
    return PressableScale(
      onTap: onTap,
      scaleDown: 0.985,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(q.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.darkGreen)),
                    ),
                    _StatusBadge(status: workOrder.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text('WO #${workOrder.id} · ${workOrder.siteName}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AESColors.grey),
                    const SizedBox(width: 4),
                    Text(q.clientName.isEmpty ? 'No client name' : q.clientName, style: const TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_today_outlined, size: 12, color: AESColors.grey),
                    const SizedBox(width: 4),
                    Text(q.date, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Rs ${q.quoteTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AESColors.primaryGreen)),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      scaleDown: 0.985,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: AESColors.lightGreen, shape: BoxShape.circle),
                    child: Icon(icon, color: AESColors.primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AESColors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
