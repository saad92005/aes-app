part of '../main.dart';

// ---------------- VENDOR BILLS ----------------
int _vendorBillItemCounter = 1;

class VendorBillItem {
  final String id;
  String category;
  String description;
  double amount;

  VendorBillItem({String? id, required this.category, required this.description, required this.amount}) : id = id ?? 'BILLITEM-${_vendorBillItemCounter++}';

  Map<String, dynamic> toMap() => {'id': id, 'category': category, 'description': description, 'amount': amount};

  static VendorBillItem fromMap(Map<String, dynamic> m) => VendorBillItem(
        id: m['id'],
        category: m['category'] ?? 'Other',
        description: m['description'] ?? '',
        amount: (m['amount'] ?? 0).toDouble(),
      );
}

// One bill can now hold multiple line items, same reasoning as ExpenseClaim - one physical
// receipt often covers several items. Receipt photos live in the `vendorBills/{id}/photos`
// subcollection via PhotoRepo rather than embedded directly, for the same 1 MiB-per-document
// reason. There is deliberately no approval/status workflow here - vendor bills never had
// one, and adding one wasn't part of this change.
class VendorBill {
  final String id;
  final String vendorUsername;
  final String? workOrderId;
  List<VendorBillItem> items;
  final String date;
  String? remarks;
  final String region;
  // Only ever populated by fromMap() for documents saved before multi-item bills existed -
  // never written back. Keeps old receipt photos (embedded directly, before PhotoRepo
  // existed) visible instead of silently disappearing after this change.
  final String? legacyReceiptPhotoUrl;

  VendorBill({
    required this.id,
    required this.vendorUsername,
    this.workOrderId,
    required this.items,
    required this.date,
    this.remarks,
    this.region = 'All',
    this.legacyReceiptPhotoUrl,
  });

  double get amount => items.fold(0.0, (sum, i) => sum + i.amount);
  String get description => items.isEmpty
      ? ''
      : items.length == 1
          ? items.first.description
          : items.map((i) => i.description).join(', ');

  Map<String, dynamic> toMap() => {
        'id': id,
        'vendorUsername': vendorUsername,
        'workOrderId': workOrderId,
        'items': items.map((i) => i.toMap()).toList(),
        'date': date,
        'remarks': remarks,
        'region': region,
      };

  static VendorBill fromMap(Map<String, dynamic> m) {
    List<VendorBillItem> items;
    final rawItems = m['items'];
    if (rawItems is List && rawItems.isNotEmpty) {
      items = rawItems.map((i) => VendorBillItem.fromMap(Map<String, dynamic>.from(i))).toList();
    } else {
      // Legacy shape: a single description/amount directly on the bill, from before
      // multi-item bills existed. Wrapped as a single line item so old data keeps working.
      items = [VendorBillItem(category: 'Other', description: m['description'] ?? '', amount: (m['amount'] ?? 0).toDouble())];
    }
    return VendorBill(
      id: m['id'],
      vendorUsername: m['vendorUsername'] ?? '',
      workOrderId: m['workOrderId'],
      items: items,
      date: m['date'] ?? '',
      remarks: m['remarks'],
      // Bills saved before this field existed have no region on record - default to 'All'
      // so they stay visible everywhere rather than silently vanishing from every
      // region-scoped user's view after this fix ships.
      region: m['region'] ?? 'All',
      legacyReceiptPhotoUrl: m['receiptPhotoUrl'],
    );
  }
}

int _billCounter = 1;
