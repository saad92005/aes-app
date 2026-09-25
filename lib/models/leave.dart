part of '../main.dart';

// ---------------- LEAVE APPLICATIONS ----------------
enum LeaveStatus { pending, approved, rejected }

extension LeaveStatusLabel on LeaveStatus {
  String get label {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case LeaveStatus.pending:
        return const Color(0xFFFF9800);
      case LeaveStatus.approved:
        return AESColors.primaryGreen;
      case LeaveStatus.rejected:
        return Colors.redAccent;
    }
  }
}

const List<String> leaveTypes = ['Casual', 'Sick', 'Annual', 'Unpaid'];

int _leaveCounter = 1;

class LeaveRequest {
  final String id;
  final String employeeUsername;
  final String region;
  String leaveType;
  String startDate; // ISO date (yyyy-MM-dd)
  String endDate;
  String? remarks;
  LeaveStatus status;
  String? rejectionNote;
  final String submittedAt;

  LeaveRequest({
    required this.id,
    required this.employeeUsername,
    required this.region,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.remarks,
    this.status = LeaveStatus.pending,
    this.rejectionNote,
    required this.submittedAt,
  });

  int get numberOfDays {
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    if (start == null || end == null) return 1;
    return end.difference(start).inDays + 1;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeUsername': employeeUsername,
        'region': region,
        'leaveType': leaveType,
        'startDate': startDate,
        'endDate': endDate,
        'remarks': remarks,
        'status': status.name,
        'rejectionNote': rejectionNote,
        'submittedAt': submittedAt,
      };

  static LeaveRequest fromMap(Map<String, dynamic> m) => LeaveRequest(
        id: m['id'],
        employeeUsername: m['employeeUsername'] ?? '',
        region: m['region'] ?? 'All',
        leaveType: m['leaveType'] ?? 'Casual',
        startDate: m['startDate'] ?? '',
        endDate: m['endDate'] ?? '',
        remarks: m['remarks'],
        status: LeaveStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => LeaveStatus.pending),
        rejectionNote: m['rejectionNote'],
        submittedAt: m['submittedAt'] ?? '',
      );
}

final List<LeaveRequest> sampleLeaves = [];
