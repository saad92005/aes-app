part of '../main.dart';

class ReportsScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const ReportsScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _regionFilter = 'All';

  List<WorkOrder> get _filtered {
    List<WorkOrder> data = widget.perms.seesAllRegions
        ? sampleWorkOrders
        : sampleWorkOrders.where((w) => w.region == widget.currentUser.region).toList();
    if (_regionFilter != 'All') {
      data = data.where((w) => w.region == _regionFilter).toList();
    }
    return data;
  }

  Future<void> _exportCsv() async {
    final rows = <List<String>>[
      [
        'WO #', 'Site Name', 'Region', 'Work Type', 'Priority', 'Status', 'Reported Date', 'Target Finish',
        'Started At', 'Completed At', 'Time on Job', 'SLA Status', 'Description',
      ],
      for (final w in _filtered)
        [
          w.id,
          w.siteName,
          w.region,
          w.workType ?? '',
          w.priority.toString(),
          w.status.label,
          w.reportedDate,
          w.targetDate,
          w.startedAt != null ? _formatDateTimeDisplay(DateTime.parse(w.startedAt!)) : '',
          w.completedAt != null ? _formatDateTimeDisplay(DateTime.parse(w.completedAt!)) : '',
          w.jobDuration != null ? _formatDuration(w.jobDuration!) : '',
          w.metSla == null ? '' : (w.metSla! ? 'SLA' : 'Non SLA'),
          w.description,
        ],
    ];

    await ExportService.exportRowsWithFormatChoice(context, title: 'Work Orders Report', rows: rows, filenameBase: 'AES_Work_Orders_Report');
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtered;

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
              const Text('Reports', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(tr('Export Report')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${data.length} work order${data.length == 1 ? '' : 's'}', style: const TextStyle(color: AESColors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          if (widget.perms.seesAllRegions)
            _FilterDropdown(
              label: 'Region',
              value: _regionFilter,
              options: const ['All', 'Multan', 'Lahore', 'Faisalabad'],
              onChanged: (v) => setState(() => _regionFilter = v),
            ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AESColors.lightGrey),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AESColors.lightGreen),
                  dataRowColor: WidgetStateProperty.resolveWith((states) => Colors.white),
                  columnSpacing: 28,
                  columns: [
                    DataColumn(label: Text('WO #', style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Site Name'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Region'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Work Type'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Priority'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Status'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Reported'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Target Finish'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Started'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text('Completed', style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text(tr('Time on Job'), style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                    DataColumn(label: Text('SLA', style: TextStyle(fontWeight: FontWeight.bold, color: AESColors.darkGreen))),
                  ],
                  rows: data
                      .map((w) => DataRow(
                            onSelectChanged: (_) async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => WorkOrderDetailScreen(workOrder: w, perms: widget.perms)),
                              );
                              setState(() {});
                            },
                            cells: [
                            DataCell(Text(w.id)),
                            DataCell(SizedBox(width: 200, child: Text(w.siteName, overflow: TextOverflow.ellipsis))),
                            DataCell(Text(w.region)),
                            DataCell(Text(w.workType ?? '-')),
                            DataCell(Text(w.priority.toString())),
                            DataCell(_StatusBadge(status: w.status)),
                            DataCell(Text(w.reportedDate)),
                            DataCell(Text(w.targetDate)),
                            DataCell(Text(w.startedAt != null ? _formatDateTimeDisplay(DateTime.parse(w.startedAt!)) : '-')),
                            DataCell(Text(w.completedAt != null ? _formatDateTimeDisplay(DateTime.parse(w.completedAt!)) : '-')),
                            DataCell(Text(w.jobDuration != null ? _formatDuration(w.jobDuration!) : '-')),
                            DataCell(
                              w.metSla == null
                                  ? const Text('-')
                                  : Text(
                                      w.metSla! ? 'SLA' : 'Non SLA',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: w.metSla! ? AESColors.primaryGreen : Colors.redAccent),
                                    ),
                            ),
                          ]))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

