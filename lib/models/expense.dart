part of '../main.dart';

// ---------------- DAILY EXPENSES ----------------
// Two-stage approval: pending (submitted, awaiting the Operational Manager) ->
// managerApproved (awaiting Finance's final sign-off) -> approved (fully approved). Either
// stage can reject, which always lands on `rejected` regardless of which stage caught it -
// rejectionNote explains why, same as before.
enum ExpenseStatus { pending, managerApproved, approved, rejected }

extension ExpenseStatusLabel on ExpenseStatus {
  String get label {
    switch (this) {
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.managerApproved:
        return 'Manager Approved';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case ExpenseStatus.pending:
        return const Color(0xFFFF9800);
      case ExpenseStatus.managerApproved:
        return const Color(0xFF2A78D6);
      case ExpenseStatus.approved:
        return AESColors.primaryGreen;
      case ExpenseStatus.rejected:
        return Colors.redAccent;
    }
  }
}

// Preset categories a line item can be tagged with. The submission UI also offers "Add new
// item", which lets the user type any other category not in this list - that free-text
// value is stored directly in ExpenseLineItem.category, same as a preset one.
const List<String> expenseCategories = [
  'Fuel',
  'Transport',
  'Food',
  'Lodging',
  'Materials',
  'Tools',
  'Utilities',
  'Communication',
  'Parking/Tolls',
  'Office Supplies',
  'Miscellaneous',
  'Other',
];

int _expenseItemCounter = 1;

class ExpenseLineItem {
  final String id;
  String category;
  String description;
  double amount;

  ExpenseLineItem({String? id, required this.category, required this.description, required this.amount}) : id = id ?? 'EXPITEM-${_expenseItemCounter++}';

  Map<String, dynamic> toMap() => {'id': id, 'category': category, 'description': description, 'amount': amount};

  static ExpenseLineItem fromMap(Map<String, dynamic> m) => ExpenseLineItem(
        id: m['id'],
        category: m['category'] ?? 'Other',
        description: m['description'] ?? '',
        amount: (m['amount'] ?? 0).toDouble(),
      );
}

// One claim can now hold multiple line items (e.g. one physical receipt covering fuel +
// tools bought on the same trip), rather than being locked to a single category/amount.
// Receipt photos live in the `expenses/{id}/photos` subcollection via PhotoRepo (same
// pattern as work order photos) so a claim can carry several receipt photos without risking
// Firestore's 1 MiB-per-document limit the way embedding them directly would.
class ExpenseClaim {
  final String id;
  final String employeeUsername;
  final String workOrderId;
  final String siteName;
  List<ExpenseLineItem> items;
  final String date;
  String? remarks;
  ExpenseStatus status;
  String? rejectionNote;
  final String submittedAt;
  final String region;
  // Only ever populated by fromMap() for documents saved before multi-item claims existed -
  // never written back. Lets old receipt photos (embedded directly on the claim doc, before
  // PhotoRepo existed) keep showing up instead of silently disappearing after this change.
  final String? legacyReceiptPhotoUrl;

  ExpenseClaim({
    required this.id,
    required this.employeeUsername,
    required this.workOrderId,
    required this.siteName,
    required this.items,
    required this.date,
    this.remarks,
    this.status = ExpenseStatus.pending,
    this.rejectionNote,
    required this.submittedAt,
    this.region = 'All',
    this.legacyReceiptPhotoUrl,
  });

  double get amount => items.fold(0.0, (sum, i) => sum + i.amount);
  String get category => items.isEmpty ? 'Other' : (items.length == 1 ? items.first.category : '${items.length} items');
  String get description => items.isEmpty
      ? ''
      : items.length == 1
          ? items.first.description
          : items.map((i) => i.description).join(', ');

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeUsername': employeeUsername,
        'workOrderId': workOrderId,
        'siteName': siteName,
        'items': items.map((i) => i.toMap()).toList(),
        'date': date,
        'remarks': remarks,
        'status': status.name,
        'rejectionNote': rejectionNote,
        'submittedAt': submittedAt,
        'region': region,
      };

  static ExpenseClaim fromMap(Map<String, dynamic> m) {
    List<ExpenseLineItem> items;
    final rawItems = m['items'];
    if (rawItems is List && rawItems.isNotEmpty) {
      items = rawItems.map((i) => ExpenseLineItem.fromMap(Map<String, dynamic>.from(i))).toList();
    } else {
      // Legacy shape: a single category/description/amount directly on the claim, from
      // before multi-item claims existed. Wrapped as a single line item so old data keeps
      // working without a separate migration step.
      items = [
        ExpenseLineItem(
          category: m['category'] ?? 'Other',
          description: m['description'] ?? '',
          amount: (m['amount'] ?? 0).toDouble(),
        ),
      ];
    }
    return ExpenseClaim(
      id: m['id'],
      employeeUsername: m['employeeUsername'] ?? '',
      workOrderId: m['workOrderId'] ?? '',
      siteName: m['siteName'] ?? '',
      items: items,
      date: m['date'] ?? '',
      remarks: m['remarks'],
      status: ExpenseStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => ExpenseStatus.pending),
      rejectionNote: m['rejectionNote'],
      submittedAt: m['submittedAt'] ?? '',
      // Expenses saved before this field existed have no region on record - default to
      // 'All' so they stay visible everywhere rather than silently vanishing from every
      // region-scoped user's view after this fix ships.
      region: m['region'] ?? 'All',
      legacyReceiptPhotoUrl: m['receiptPhotoUrl'],
    );
  }
}

int _expenseCounter = 1;
final List<ExpenseClaim> sampleExpenses = [];
