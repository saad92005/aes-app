part of '../main.dart';

// ---------------- EMPLOYEE: MY ATTENDANCE SCREEN ----------------
class MyAttendanceScreen extends StatefulWidget {
  final AppUser currentUser;
  const MyAttendanceScreen({super.key, required this.currentUser});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  bool _working = false;

  List<AttendanceRecord> get _myRecords => sampleAttendance
      .where((a) => a.employeeUsername == widget.currentUser.username)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  AttendanceRecord? get _todayRecord {
    final today = _todayDateString();
    for (final r in _myRecords) {
      if (r.date == today) return r;
    }
    return null;
  }

  // Any earlier day still sitting checked-in with no checkout at all - _myRecords is
  // already sorted newest-first, so this naturally surfaces the most recent gap first if
  // more than one ever piles up. While this is non-null, check-in for today is blocked
  // until it's resolved (see build() and _resolveMissedCheckout below).
  AttendanceRecord? get _missedCheckoutRecord {
    final today = _todayDateString();
    for (final r in _myRecords) {
      if (r.date != today && !r.isCheckedOut) return r;
    }
    return null;
  }

  // Forces a checkout time to be entered for a day that was never checked out of, before
  // today's check-in is allowed. Location is still required, same as a normal same-day
  // checkout - it's today's actual location captured at the moment this is filled in, not a
  // reconstruction of where the employee was on the missed day (which isn't recoverable).
  Future<void> _resolveMissedCheckout(AttendanceRecord record) async {
    final checkIn = DateTime.tryParse(record.checkInAt);
    final picked = await _pickDateTime(context, initial: checkIn?.add(const Duration(hours: 8)) ?? DateTime.now());
    if (picked == null) return;
    if (checkIn != null && !picked.isAfter(checkIn)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout time must be after check-in time (${_formatTime(record.checkInAt)})'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _working = true);
    final position = await _captureAttendanceLocation(context);
    if (position == null) {
      if (mounted) setState(() => _working = false);
      return;
    }
    record.checkOutAt = picked.toIso8601String();
    record.checkOutLat = position.latitude;
    record.checkOutLng = position.longitude;
    try {
      await DataService.saveAttendance(record);
      setState(() {});
      await _notifyAdminsOfCheckOut(record);
    } catch (e) {
      record.checkOutAt = null;
      record.checkOutLat = null;
      record.checkOutLng = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _checkIn() async {
    setState(() => _working = true);
    final position = await _captureAttendanceLocation(context);
    if (position == null) {
      setState(() => _working = false);
      return;
    }
    final today = _todayDateString();
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day, officeStartHour, officeStartMinute);
    // Checked before saving (not read back off the AttendanceRecord afterwards) so the
    // reason prompt can happen before the record is even built - a network issue or
    // traffic delay is exactly the kind of thing worth capturing right at the moment it's
    // causing the late check-in, not reconstructed after the fact.
    String? remarks;
    if (now.isAfter(cutoff) && mounted) {
      remarks = await _showLateReasonDialog(context);
    }
    final record = AttendanceRecord(
      id: '${widget.currentUser.username}_$today',
      employeeUsername: widget.currentUser.username,
      region: widget.currentUser.region,
      date: today,
      checkInAt: now.toIso8601String(),
      checkInLat: position.latitude,
      checkInLng: position.longitude,
      remarks: remarks,
    );
    try {
      await DataService.saveAttendance(record);
      setState(() => sampleAttendance.add(record));
      if (record.isLate) await _notifyAdminsOfLateCheckIn(record);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check in: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _checkOut() async {
    final record = _todayRecord;
    if (record == null) return;
    setState(() => _working = true);
    final position = await _captureAttendanceLocation(context);
    if (position == null) {
      setState(() => _working = false);
      return;
    }
    final previousCheckOutAt = record.checkOutAt;
    final previousLat = record.checkOutLat;
    final previousLng = record.checkOutLng;
    record.checkOutAt = DateTime.now().toIso8601String();
    record.checkOutLat = position.latitude;
    record.checkOutLng = position.longitude;
    try {
      await DataService.saveAttendance(record);
      setState(() {});
      await _notifyAdminsOfCheckOut(record);
    } catch (e) {
      record.checkOutAt = previousCheckOutAt;
      record.checkOutLat = previousLat;
      record.checkOutLng = previousLng;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check out: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayRecord;
    final missedCheckout = _missedCheckoutRecord;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('My Attendance'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
          const SizedBox(height: 4),
          Text(tr('Office hours: 9:30 AM - 6:00 PM'), style: TextStyle(fontSize: 12, color: AESColors.grey)),
          const SizedBox(height: 16),
          if (missedCheckout != null)
            // Blocks today's check-in entirely until this is resolved - the button below is
            // the only action available while a previous day is still sitting checked-in
            // with no checkout on record.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.deepOrange, width: 1.4),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_outlined, color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You forgot to check out on ${missedCheckout.date} (checked in at ${_formatTime(missedCheckout.checkInAt)}). '
                          'Enter your checkout time for that day before you can check in today.',
                          style: const TextStyle(fontSize: 13, color: AESColors.darkGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _working ? null : () => _resolveMissedCheckout(missedCheckout),
                      icon: _working
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.logout, size: 18),
                      label: Text('Enter Checkout for ${missedCheckout.date}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Status", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                  const SizedBox(height: 10),
                  if (today == null)
                    Text(tr('Not checked in yet'), style: TextStyle(fontSize: 13, color: AESColors.grey))
                  else ...[
                    Row(
                      children: [
                        Text('Checked in at ${_formatTime(today.checkInAt)}', style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                        if (today.isLate) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.error, size: 13, color: Color(0xFFE34948)),
                          const SizedBox(width: 3),
                          Text(tr('Late'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE34948))),
                        ],
                      ],
                    ),
                    if (today.isCheckedOut)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Text('Checked out at ${_formatTime(today.checkOutAt!)}', style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                            if (today.overtime != null) ...[
                              const SizedBox(width: 8),
                              Text('· ${_formatDuration(today.overtime!)} overtime', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AESColors.darkGreen)),
                            ],
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _working
                          ? null
                          : today == null
                              ? _checkIn
                              : (today.isCheckedOut ? null : _checkOut),
                      icon: _working
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(today == null ? Icons.login : Icons.logout, size: 18),
                      label: Text(today == null ? 'Check In' : (today.isCheckedOut ? 'Completed for Today' : 'Check Out')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: today != null && today.isCheckedOut ? AESColors.grey : AESColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(tr('History'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
          const SizedBox(height: 10),
          if (_myRecords.isEmpty)
            Text(tr('No attendance records yet'), style: TextStyle(fontSize: 13, color: AESColors.grey))
          else
            for (final r in _myRecords)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(r.date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AESColors.darkGrey)),
                              if (r.isLate) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.error, size: 12, color: Color(0xFFE34948)),
                                const SizedBox(width: 2),
                                Text(tr('Late'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE34948))),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'In ${_formatTime(r.checkInAt)}${r.isCheckedOut ? '  ·  Out ${_formatTime(r.checkOutAt!)}' : '  ·  Still checked in'}'
                            '${r.overtime != null ? '  ·  ${_formatDuration(r.overtime!)} overtime' : ''}',
                            style: const TextStyle(fontSize: 12, color: AESColors.grey),
                          ),
                          if (r.remarks != null && r.remarks!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Remarks: ${r.remarks}', style: const TextStyle(fontSize: 11, color: AESColors.grey, fontStyle: FontStyle.italic)),
                            ),
                        ],
                      ),
                    ),
                    if (r.checkInLat != null)
                      IconButton(
                        icon: const Icon(Icons.location_on_outlined, color: AESColors.primaryGreen, size: 20),
                        tooltip: 'View check-in location',
                        onPressed: () => _openLocationInMaps(context, r.checkInLat!, r.checkInLng!),
                      ),
                  ],
                ),
              ),
        ],
      );
  }
}

