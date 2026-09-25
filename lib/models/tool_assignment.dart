part of '../main.dart';

// ---------------- TOOL / STORE ASSIGNMENTS ----------------
// Tracks which inventory item (and how much of it) is currently checked out to which
// employee - distinct from a plain Stock Out, which represents material consumed on a job.
// A tool assignment is a temporary custody transfer: the item is still company property and
// expected back, so returning it restores the quantity to available stock the same way a
// Stock In would. Every assign/return also writes a normal InventoryTransaction (see
// InventoryScreen), so the existing Transaction Log stays the single complete explanation of
// every quantity change - this is just the extra "who currently has what" layer on top.
enum ToolAssignmentStatus { assigned, returned }

class ToolAssignment {
  final String id;
  final String itemId;
  final String itemName; // denormalized, same pattern as InventoryTransaction
  final double quantity;
  final String unit;
  String assignedToUsername;
  final String assignedByUsername;
  final String region;
  final String assignedDate;
  String? returnedDate;
  ToolAssignmentStatus status;
  String? note;
  // Optional - a tool checked out for a specific job vs. general/unassigned use (e.g. a
  // vehicle toolkit kept by the worker across jobs). Same "None - general stock" pattern
  // Stock In/Out already uses for InventoryTransaction.relatedWorkOrderId.
  String? relatedWorkOrderId;

  ToolAssignment({
    String? id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    this.unit = 'pcs',
    required this.assignedToUsername,
    required this.assignedByUsername,
    required this.region,
    String? assignedDate,
    this.returnedDate,
    this.status = ToolAssignmentStatus.assigned,
    this.note,
    this.relatedWorkOrderId,
  })  : id = id ?? 'ASSIGN-${_toolAssignmentCounter++}',
        assignedDate = assignedDate ?? _formatDateTimeDisplay(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'unit': unit,
        'assignedToUsername': assignedToUsername,
        'assignedByUsername': assignedByUsername,
        'region': region,
        'assignedDate': assignedDate,
        'returnedDate': returnedDate,
        'status': status.name,
        'note': note,
        'relatedWorkOrderId': relatedWorkOrderId,
      };

  static ToolAssignment fromMap(Map<String, dynamic> m) => ToolAssignment(
        id: m['id'],
        itemId: m['itemId'] ?? '',
        itemName: m['itemName'] ?? '',
        quantity: (m['quantity'] ?? 0).toDouble(),
        unit: m['unit'] ?? 'pcs',
        assignedToUsername: m['assignedToUsername'] ?? '',
        assignedByUsername: m['assignedByUsername'] ?? '',
        region: m['region'] ?? '',
        assignedDate: m['assignedDate'] ?? '',
        returnedDate: m['returnedDate'],
        status: ToolAssignmentStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => ToolAssignmentStatus.assigned),
        note: m['note'],
        relatedWorkOrderId: m['relatedWorkOrderId'],
      );
}

int _toolAssignmentCounter = 1;
final List<ToolAssignment> sampleToolAssignments = [];
