part of '../main.dart';

// ---------------- WORK ORDERS SCREEN ----------------
class WorkOrdersScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  final String? initialRegionFilter;
  const WorkOrdersScreen({super.key, required this.currentUser, required this.perms, this.initialRegionFilter});

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

const List<String> _fullMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class _WorkOrdersScreenState extends State<WorkOrdersScreen> {
  late String _regionFilter;
  WorkOrderStatus? _statusFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // null = show every month, grouped. A real work order date (reportedDateTime), not "today",
  // decides which month a work order falls under - see WorkOrder.reportedDateTime.
  String? _selectedMonthKey;

  @override
  void initState() {
    super.initState();
    _regionFilter = widget.initialRegionFilter ?? 'All';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // "yyyy-MM" - null when the work order has no parseable reported date at all (very old/
  // malformed records only). Zero-padded so lexicographic string sort == chronological sort.
  String? _monthKeyOf(WorkOrder w) {
    final dt = w.reportedDateTime;
    if (dt == null) return null;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final month = int.tryParse(parts[1]) ?? 1;
    return '${_fullMonthNames[month - 1]} ${parts[0]}';
  }

  // Manual creation for work orders that didn't come in by email - reuses the same
  // region-detection GmailService.detectRegion already uses for Gmail-sourced work orders
  // (matches against sampleSites, auto-registers a new SiteEntry if the site is genuinely
  // new), rather than leaving the region as a bare hardcoded dropdown with no memory of
  // already-known sites.
  Future<void> _showAddWorkOrderDialog() async {
    final woNumberController = TextEditingController();
    final siteNameController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();
    int priority = 2;
    String region = widget.perms.seesAllRegions ? 'Lahore' : widget.currentUser.region;
    bool regionManuallyChanged = false;
    DateTime? targetFinish = DateTime.now().add(const Duration(days: 3));
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('Add Work Order Manually')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: woNumberController,
                      decoration: const InputDecoration(
                        labelText: 'WO Number (optional - auto-generated if left blank)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: siteNameController,
                      decoration: const InputDecoration(labelText: 'Site Name', border: OutlineInputBorder(), isDense: true),
                      onChanged: (value) {
                        // Auto-detects the region from already-known sites the same way Gmail
                        // sync does, so a manually-created work order for a real, existing
                        // site doesn't need the region picked by hand - but leaves it alone
                        // once the user has manually overridden the dropdown themselves.
                        if (regionManuallyChanged) return;
                        final detected = GmailService.detectRegion(value.trim(), sampleSites);
                        if (detected != null) setDialogState(() => region = detected);
                      },
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
                      onChanged: (v) => setDialogState(() {
                        region = v ?? region;
                        regionManuallyChanged = true;
                      }),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder(), isDense: true),
                      items: [
                        DropdownMenuItem(value: 1, child: Text(tr('1 - High'))),
                        DropdownMenuItem(value: 2, child: Text(tr('2 - Medium'))),
                        DropdownMenuItem(value: 3, child: Text(tr('3 - Low'))),
                      ],
                      onChanged: (v) => setDialogState(() => priority = v ?? priority),
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
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (siteNameController.text.trim().isEmpty) return;
                    setDialogState(() => isSubmitting = true);
                    final now = DateTime.now();
                    final reportedStr = _formatDateTimeDisplay(now);
                    final siteName = siteNameController.text.trim().toUpperCase();
                    final woId = woNumberController.text.trim().isNotEmpty ? woNumberController.text.trim() : _nextCustomWorkOrderId();

                    final autoDetectedRegion = GmailService.detectRegion(siteName, sampleSites);
                    if (autoDetectedRegion == null) {
                      final newSite = SiteEntry(id: 'SITE-${_siteCounter++}', siteName: siteName, region: region);
                      sampleSites.add(newSite);
                      try {
                        await DataService.saveSite(newSite);
                      } catch (_) {
                        // Not fatal - the work order still gets created with the chosen region.
                      }
                    }

                    final newWorkOrder = WorkOrder(
                      id: woId,
                      siteName: siteName,
                      address: addressController.text.trim(),
                      region: region,
                      priority: priority,
                      description: descriptionController.text.trim().isEmpty ? 'Manually created work order' : descriptionController.text.trim(),
                      targetDate: targetFinish != null ? _formatDateTimeDisplay(targetFinish!) : reportedStr,
                      targetDateIso: targetFinish?.toIso8601String(),
                      reportedDate: reportedStr,
                      reportedDateIso: now.toIso8601String(),
                      status: WorkOrderStatus.pending,
                    );
                    try {
                      await DataService.saveWorkOrder(newWorkOrder);
                      sampleWorkOrders.add(newWorkOrder);
                      if (context.mounted) {
                        setState(() {});
                        Navigator.pop(context);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(tr('Work order created successfully')), backgroundColor: AESColors.primaryGreen),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setDialogState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save work order: $e'), backgroundColor: Colors.redAccent),
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
                      : Text(tr('Create Work Order')),
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
    // Region-based visibility: employees see only work orders assigned to them; everyone else sees the full region
    List<WorkOrder> visible = widget.perms.seesAllRegions
        ? sampleWorkOrders
        : sampleWorkOrders.where((w) => w.region == widget.currentUser.region).toList();

    if (widget.currentUser.role == UserRole.employee) {
      visible = visible.where((w) => w.assignedEmployeeUsername == widget.currentUser.username).toList();
    } else if (widget.currentUser.role == UserRole.vendor) {
      visible = visible.where((w) => w.assignedVendorUsername == widget.currentUser.username).toList();
    } else if (!widget.perms.canViewAllWorkOrders) {
      // Roles with no operational reason to see work orders (Finance, Store Manager,
      // Procurement, Office Staff) - not an employee/vendor with their own assignment, and
      // not one of the coordination roles canViewAllWorkOrders allows. This screen shouldn't
      // even be reachable for them (the nav item and Dashboard tile are hidden), but this is
      // the actual data-level guarantee in case something else ever links here directly.
      visible = [];
    }

    if (_regionFilter != 'All') {
      visible = visible.where((w) => w.region == _regionFilter).toList();
    }
    if (_statusFilter != null) {
      visible = visible.where((w) => w.status == _statusFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      visible = visible
          .where((w) =>
              w.id.toLowerCase().contains(q) ||
              w.siteName.toLowerCase().contains(q) ||
              w.address.toLowerCase().contains(q) ||
              w.description.toLowerCase().contains(q))
          .toList();
    }

    // Every month that has at least one work order under the region/status/search filters
    // above (but before the month filter itself) - so the dropdown always offers every month
    // that's actually reachable from here, newest first.
    final monthKeysPresent = <String>{};
    for (final w in visible) {
      final key = _monthKeyOf(w);
      if (key != null) monthKeysPresent.add(key);
    }
    final availableMonths = monthKeysPresent.toList()..sort((a, b) => b.compareTo(a));
    // A month picked earlier can stop existing once its own filters are narrowed further
    // (e.g. switching region) - fall back to "All Months" rather than silently showing zero
    // results with no visible explanation.
    if (_selectedMonthKey != null && !monthKeysPresent.contains(_selectedMonthKey)) {
      _selectedMonthKey = null;
    }
    if (_selectedMonthKey != null) {
      visible = visible.where((w) => _monthKeyOf(w) == _selectedMonthKey).toList();
    }

    // Group by month (newest first), then by region within each month - using the work
    // order's actual reported date, never "today". Work orders with no parseable date at all
    // are collected separately and shown last, rather than silently dropped.
    final Map<String, List<WorkOrder>> byMonth = {};
    final List<WorkOrder> undated = [];
    for (final w in visible) {
      final key = _monthKeyOf(w);
      if (key == null) {
        undated.add(w);
      } else {
        byMonth.putIfAbsent(key, () => []).add(w);
      }
    }
    final sortedMonthKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    int cmpNewestFirst(WorkOrder a, WorkOrder b) {
      final da = a.reportedDateTime;
      final db = b.reportedDateTime;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    }

    final List<Widget> groupedSections = [];
    for (final monthKey in sortedMonthKeys) {
      final monthOrders = byMonth[monthKey]!;
      if (_selectedMonthKey == null) {
        groupedSections.add(Padding(
          padding: EdgeInsets.only(top: groupedSections.isEmpty ? 0 : 24, bottom: 10),
          child: Text(
            '${_monthLabel(monthKey)} · ${monthOrders.length} work order${monthOrders.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen),
          ),
        ));
      }
      if (_regionFilter != 'All') {
        // Already scoped to one region - a region sub-header would just repeat the filter.
        final sorted = List.of(monthOrders)..sort(cmpNewestFirst);
        for (final w in sorted) {
          groupedSections.add(_WorkOrderCard(
            workOrder: w,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => WorkOrderDetailScreen(workOrder: w, perms: widget.perms)));
              setState(() {});
            },
          ));
        }
      } else {
        final byRegion = <String, List<WorkOrder>>{};
        for (final w in monthOrders) {
          byRegion.putIfAbsent(w.region, () => []).add(w);
        }
        final regionNames = byRegion.keys.toList()..sort();
        for (final region in regionNames) {
          final regionOrders = List.of(byRegion[region]!)..sort(cmpNewestFirst);
          groupedSections.add(Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Row(
              children: [
                Container(width: 4, height: 14, color: AESColors.primaryGreen),
                const SizedBox(width: 8),
                Text('$region · ${regionOrders.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AESColors.darkGrey)),
              ],
            ),
          ));
          for (final w in regionOrders) {
            groupedSections.add(_WorkOrderCard(
              workOrder: w,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => WorkOrderDetailScreen(workOrder: w, perms: widget.perms)));
                setState(() {});
              },
            ));
          }
        }
      }
    }
    if (undated.isNotEmpty) {
      final sorted = List.of(undated)..sort((a, b) => a.id.compareTo(b.id));
      groupedSections.add(Padding(
        padding: EdgeInsets.only(top: groupedSections.isEmpty ? 0 : 24, bottom: 10),
        child: const Text('Unknown Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
      ));
      for (final w in sorted) {
        groupedSections.add(_WorkOrderCard(
          workOrder: w,
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => WorkOrderDetailScreen(workOrder: w, perms: widget.perms)));
            setState(() {});
          },
        ));
      }
    }

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
              const Text('Work Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              if (widget.perms.canCreateWorkOrder)
                ElevatedButton.icon(
                  onPressed: _showAddWorkOrderDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('Add Work Order')),
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
          Text(
            widget.perms.seesAllRegions
                ? 'All regions · ${visible.length} work order${visible.length == 1 ? '' : 's'}'
                : '${widget.currentUser.region} · ${visible.length} work order${visible.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AESColors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ListSearchField(
            controller: _searchController,
            hintText: 'Search by WO#, site, address, description...',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 12),
          // Filters
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (widget.perms.seesAllRegions)
                _FilterDropdown(
                  label: 'Region',
                  value: _regionFilter,
                  options: const ['All', 'Multan', 'Lahore', 'Faisalabad'],
                  onChanged: (v) => setState(() => _regionFilter = v),
                ),
              _StatusFilterDropdown(
                value: _statusFilter,
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
              if (availableMonths.isNotEmpty)
                _MonthFilterDropdown(
                  value: _selectedMonthKey,
                  options: availableMonths,
                  labelOf: _monthLabel,
                  onChanged: (v) => setState(() => _selectedMonthKey = v),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(tr('No work orders match these filters'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8))),
              ),
            )
          else
            ...groupedSections,
        ],
      ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AESColors.lightGrey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AESColors.grey),
          style: const TextStyle(color: AESColors.darkGrey, fontSize: 13),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text('$label: $o'))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _MonthFilterDropdown extends StatelessWidget {
  final String? value;
  final List<String> options;
  final String Function(String key) labelOf;
  final ValueChanged<String?> onChanged;

  const _MonthFilterDropdown({required this.value, required this.options, required this.labelOf, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AESColors.lightGrey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(tr('Month: All'), style: TextStyle(fontSize: 13, color: AESColors.darkGrey)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AESColors.grey),
          style: const TextStyle(color: AESColors.darkGrey, fontSize: 13),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(tr('Month: All'))),
            ...options.map((key) => DropdownMenuItem<String?>(value: key, child: Text('Month: ${labelOf(key)}'))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StatusFilterDropdown extends StatelessWidget {
  final WorkOrderStatus? value;
  final ValueChanged<WorkOrderStatus?> onChanged;

  const _StatusFilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AESColors.lightGrey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WorkOrderStatus?>(
          value: value,
          hint: Text(tr('Status: All'), style: TextStyle(fontSize: 13, color: AESColors.darkGrey)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AESColors.grey),
          style: const TextStyle(color: AESColors.darkGrey, fontSize: 13),
          items: [
            DropdownMenuItem(value: null, child: Text(tr('Status: All'))),
            ...WorkOrderStatus.values.map((s) => DropdownMenuItem(value: s, child: Text('Status: ${s.label}'))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  final WorkOrder workOrder;
  final VoidCallback onTap;

  const _WorkOrderCard({required this.workOrder, required this.onTap});

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
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        workOrder.siteName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.darkGrey),
                      ),
                    ),
                    _StatusBadge(status: workOrder.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text('WO #${workOrder.id} · ${workOrder.region}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                const SizedBox(height: 10),
                Text(
                  workOrder.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AESColors.darkGrey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.priority_high, size: 14, color: workOrder.priority == 1 ? Colors.red : AESColors.grey),
                    const SizedBox(width: 4),
                    Text('Priority ${workOrder.priority}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_today_outlined, size: 13, color: AESColors.grey),
                    const SizedBox(width: 4),
                    Text('Target: ${workOrder.targetDate}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                _AssignmentBadge(workOrder: workOrder),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// Who this work order is actually assigned to, right on the list card - previously only
// visible by opening the work order's own detail screen, which made "who's doing what" hard
// to see at a glance across a whole list.
class _AssignmentBadge extends StatelessWidget {
  final WorkOrder workOrder;
  const _AssignmentBadge({required this.workOrder});

  @override
  Widget build(BuildContext context) {
    final assignee = workOrder.assignedEmployeeUsername ?? workOrder.assignedVendorUsername;
    final isVendor = workOrder.assignedEmployeeUsername == null && workOrder.assignedVendorUsername != null;
    return Row(
      children: [
        Icon(
          assignee == null ? Icons.person_off_outlined : (isVendor ? Icons.storefront_outlined : Icons.person_outline),
          size: 13,
          color: assignee == null ? AESColors.grey : AESColors.primaryGreen,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            assignee == null ? 'Unassigned' : '${isVendor ? 'Vendor' : 'Worker'}: $assignee',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: assignee == null ? FontWeight.normal : FontWeight.w600, color: assignee == null ? AESColors.grey : AESColors.primaryGreen),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final WorkOrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status.color),
      ),
    );
  }
}

