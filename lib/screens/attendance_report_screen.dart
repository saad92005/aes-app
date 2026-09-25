part of '../main.dart';

// ---------------- BACK OFFICE: ATTENDANCE REPORT SCREEN ----------------
class AttendanceReportScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const AttendanceReportScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  String _regionFilter = 'All';
  List<Map<String, dynamic>> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await AuthService.listEmployees();
      if (mounted) setState(() => _allUsers = users);
    } catch (_) {
      // Non-critical - the absent-today list just won't show if this fails.
    }
  }

  List<AttendanceRecord> get _filtered {
    List<AttendanceRecord> data = widget.perms.seesAllRegions
        ? sampleAttendance
        : sampleAttendance.where((a) => a.region == widget.currentUser.region).toList();
    if (_regionFilter != 'All') {
      data = data.where((a) => a.region == _regionFilter).toList();
    }
    return data..sort((a, b) => b.date.compareTo(a.date));
  }

  // Active, non-vendor employees (everyone check-in/check-out applies to) who haven't
  // checked in today - only meaningful once the work day has actually started, otherwise
  // everyone would show "absent" first thing in the morning before anyone's had a chance to
  // check in yet.
  List<String> get _absentToday {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day, officeStartHour, officeStartMinute);
    if (now.isBefore(cutoff)) return [];

    final today = _todayDateString();
    final checkedInToday = sampleAttendance.where((a) => a.date == today).map((a) => a.employeeUsername).toSet();
    final regionScoped = widget.perms.seesAllRegions
        ? _allUsers
        : _allUsers.where((u) => u['region'] == widget.currentUser.region || u['region'] == 'All').toList();
    return regionScoped
        .where((u) =>
            u['active'] != false &&
            u['role'] != 'vendor' &&
            (_regionFilter == 'All' || u['region'] == _regionFilter) &&
            !checkedInToday.contains(u['username']))
        .map((u) => u['username'] as String)
        .toList();
  }

  Future<void> _exportCsv() async {
    final rows = <List<String>>[
      ['Employee', 'Region', 'Date', 'Check-In Time', 'Status', 'Remarks', 'Check-In Location', 'Check-Out Time', 'Overtime', 'Check-Out Location'],
      for (final a in _filtered)
        [
          a.employeeUsername,
          a.region,
          a.date,
          _formatTime(a.checkInAt),
          a.isLate ? 'Late' : 'On Time',
          a.remarks ?? '',
          a.checkInLat != null ? '${a.checkInLat},${a.checkInLng}' : '',
          a.isCheckedOut ? _formatTime(a.checkOutAt!) : '',
          a.overtime != null ? _formatDuration(a.overtime!) : '',
          a.checkOutLat != null ? '${a.checkOutLat},${a.checkOutLng}' : '',
        ],
      for (final username in _absentToday) [username, '', _todayDateString(), '', 'Absent', '', '', '', '', ''],
    ];

    await ExportService.exportRowsWithFormatChoice(context, title: 'Attendance Report', rows: rows, filenameBase: 'AES_Attendance_Report');
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtered;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('Team Attendance'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: data.isEmpty ? null : _exportCsv,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(tr('Export Report')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.perms.seesAllRegions)
            _FilterDropdown(
              label: 'Region',
              value: _regionFilter,
              options: const ['All', 'Multan', 'Lahore', 'Faisalabad'],
              onChanged: (v) => setState(() => _regionFilter = v),
            ),
          if (_absentToday.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFCEBEA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE34948).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, size: 16, color: Color(0xFFE34948)),
                      const SizedBox(width: 6),
                      Text(
                        'Absent Today (${_absentToday.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE34948)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_absentToday.join(', '), style: const TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (data.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No attendance records yet'), style: TextStyle(color: AESColors.grey))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(tr('Employee'))),
                  DataColumn(label: Text(tr('Region'))),
                  DataColumn(label: Text(tr('Date'))),
                  DataColumn(label: Text(tr('Check-In'))),
                  DataColumn(label: Text(tr('Status'))),
                  DataColumn(label: Text(tr('Remarks'))),
                  DataColumn(label: Text(tr('Check-Out'))),
                  DataColumn(label: Text(tr('Overtime'))),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final a in data)
                    DataRow(cells: [
                      DataCell(Text(a.employeeUsername)),
                      DataCell(Text(a.region)),
                      DataCell(Text(a.date)),
                      DataCell(Text(_formatTime(a.checkInAt))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              a.isLate ? Icons.error : Icons.check_circle,
                              size: 14,
                              color: a.isLate ? const Color(0xFFE34948) : AESColors.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              a.isLate ? 'Late' : 'On Time',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: a.isLate ? const Color(0xFFE34948) : AESColors.primaryGreen),
                            ),
                          ],
                        ),
                      ),
                      DataCell(SizedBox(
                        width: 160,
                        child: Text(
                          a.remarks ?? '-',
                          style: const TextStyle(fontSize: 12, color: AESColors.darkGrey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      DataCell(Text(a.isCheckedOut ? _formatTime(a.checkOutAt!) : 'Still checked in')),
                      DataCell(
                        a.overtime != null
                            ? Text(_formatDuration(a.overtime!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AESColors.darkGreen))
                            : const Text('-', style: TextStyle(fontSize: 12, color: AESColors.grey)),
                      ),
                      DataCell(
                        a.checkInLat != null
                            ? IconButton(
                                icon: const Icon(Icons.location_on_outlined, color: AESColors.primaryGreen, size: 20),
                                tooltip: 'View check-in location',
                                onPressed: () => _openLocationInMaps(context, a.checkInLat!, a.checkInLng!),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ]),
                ],
              ),
            ),
        ],
      );
  }
}

