part of '../main.dart';

// ---------------- EMPLOYEE LEDGER (Finance) ----------------
// A running personal account per employee - debit = they owe the company (e.g. a cash
// advance), credit = reduces that (a repayment) or represents an amount owed to them. This
// is intentionally separate from Expense Claims (which are reimbursement requests with an
// approval workflow) - the ledger is Finance's own record-keeping tool, entered directly,
// with no approval step of its own.
enum LedgerEntryType { debit, credit }

extension LedgerEntryTypeLabel on LedgerEntryType {
  String get label => this == LedgerEntryType.debit ? 'Debit (Owes Company)' : 'Credit (Paid / Owed to Employee)';
}

const List<String> ledgerCategories = [
  'Cash Advance',
  'Salary Adjustment',
  'Reimbursement',
  'Deduction',
  'Repayment',
  'Other',
];

class LedgerEntry {
  final String id;
  final String employeeUsername;
  final String date;
  String category;
  String description;
  LedgerEntryType type;
  double amount;
  final String enteredByUsername;
  final String region;

  LedgerEntry({
    String? id,
    required this.employeeUsername,
    String? date,
    this.category = 'Other',
    this.description = '',
    required this.type,
    required this.amount,
    required this.enteredByUsername,
    this.region = 'All',
  })  : id = id ?? 'LEDGER-${_ledgerCounter++}',
        date = date ?? _formatDateTimeDisplay(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeUsername': employeeUsername,
        'date': date,
        'category': category,
        'description': description,
        'type': type.name,
        'amount': amount,
        'enteredByUsername': enteredByUsername,
        'region': region,
      };

  static LedgerEntry fromMap(Map<String, dynamic> m) => LedgerEntry(
        id: m['id'],
        employeeUsername: m['employeeUsername'] ?? '',
        date: m['date'] ?? '',
        category: m['category'] ?? 'Other',
        description: m['description'] ?? '',
        type: LedgerEntryType.values.firstWhere((t) => t.name == m['type'], orElse: () => LedgerEntryType.debit),
        amount: (m['amount'] ?? 0).toDouble(),
        enteredByUsername: m['enteredByUsername'] ?? '',
        region: m['region'] ?? 'All',
      );
}

int _ledgerCounter = 1;
final List<LedgerEntry> sampleLedgerEntries = [];
