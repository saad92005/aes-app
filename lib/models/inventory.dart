part of '../main.dart';

// ---------------- INVENTORY ----------------
class InventoryItem {
  final String id;
  String name;
  String unit; // e.g. 'pcs', 'box', 'meter', 'liter'
  String category;
  String region; // 'Multan', 'Lahore', 'Faisalabad' - each region keeps its own stock
  double quantity; // current stock on hand - kept in sync by InventoryTransaction entries
  double reorderLevel; // flagged as low stock at or below this

  InventoryItem({
    required this.id,
    required this.name,
    this.unit = 'pcs',
    this.category = 'General',
    required this.region,
    this.quantity = 0,
    this.reorderLevel = 0,
  });

  bool get isLowStock => quantity <= reorderLevel;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'unit': unit,
        'category': category,
        'region': region,
        'quantity': quantity,
        'reorderLevel': reorderLevel,
      };

  static InventoryItem fromMap(Map<String, dynamic> m) => InventoryItem(
        id: m['id'],
        name: m['name'] ?? '',
        unit: m['unit'] ?? 'pcs',
        category: m['category'] ?? 'General',
        region: m['region'] ?? '',
        quantity: (m['quantity'] ?? 0).toDouble(),
        reorderLevel: (m['reorderLevel'] ?? 0).toDouble(),
      );
}

enum InventoryTxnType { stockIn, stockOut }

// Append-only ledger entry - every stock movement gets one of these, so there's always a
// full audit trail of what came in and what went out, who did it, and why.
class InventoryTransaction {
  final String id;
  final String itemId;
  final String itemName; // denormalized so the ledger/CSV reads fine without a join
  final InventoryTxnType type;
  final double quantity;
  final String date; // display string, e.g. "16-Jul-2026 14:30"
  final String performedByUsername;
  final String region;
  final String? note;
  final String? relatedWorkOrderId; // optional - links a stock-out to the job it was used for

  InventoryTransaction({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.quantity,
    required this.date,
    required this.performedByUsername,
    required this.region,
    this.note,
    this.relatedWorkOrderId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'itemId': itemId,
        'itemName': itemName,
        'type': type.name,
        'quantity': quantity,
        'date': date,
        'performedByUsername': performedByUsername,
        'region': region,
        'note': note,
        'relatedWorkOrderId': relatedWorkOrderId,
      };

  static InventoryTransaction fromMap(Map<String, dynamic> m) => InventoryTransaction(
        id: m['id'],
        itemId: m['itemId'] ?? '',
        itemName: m['itemName'] ?? '',
        type: InventoryTxnType.values.firstWhere((t) => t.name == m['type'], orElse: () => InventoryTxnType.stockIn),
        quantity: (m['quantity'] ?? 0).toDouble(),
        date: m['date'] ?? '',
        performedByUsername: m['performedByUsername'] ?? '',
        region: m['region'] ?? '',
        note: m['note'],
        relatedWorkOrderId: m['relatedWorkOrderId'],
      );
}

int _inventoryItemCounter = 1;
int _inventoryTxnCounter = 1;
final List<InventoryItem> sampleInventoryItems = [];
final List<InventoryTransaction> sampleInventoryTransactions = [];

