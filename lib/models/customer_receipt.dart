part of '../main.dart';

// ---------------- CUSTOMER RECEIPTS (Accounts Receivable collections) ----------------
enum PaymentMethod { bankTransfer, cash, cheque, card, other }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}

// How much of a receipt applies against one specific invoice - the receipt's total amount is
// always the full amount that hit the bank (see CustomerReceipt.amount / the journal entry it
// posts), this is purely subsidiary bookkeeping for "which invoices did this payment cover."
// Amounts left unallocated stay as a general credit against the customer's AR balance (see
// section 6/7's "Unallocated Customer Receipt") until a later allocation edit assigns them.
class ReceiptAllocation {
  String invoiceId;
  double amount;
  ReceiptAllocation({required this.invoiceId, required this.amount});

  Map<String, dynamic> toMap() => {'invoiceId': invoiceId, 'amount': amount};
  static ReceiptAllocation fromMap(Map<String, dynamic> m) => ReceiptAllocation(invoiceId: m['invoiceId'] ?? '', amount: (m['amount'] ?? 0).toDouble());
}

class CustomerReceipt {
  final String id;
  final String customerId;
  final String date;
  final String dateIso;
  final double amount;
  final String bankAccountCode; // leaf account under 1110/1120 that received the money
  final PaymentMethod method;
  String referenceNumber;
  String notes;
  List<ReceiptAllocation> allocations;
  final String createdByUsername;
  final String createdAt;
  final String? journalEntryId;
  final String region;

  CustomerReceipt({
    String? id,
    required this.customerId,
    required this.date,
    required this.dateIso,
    required this.amount,
    required this.bankAccountCode,
    this.method = PaymentMethod.bankTransfer,
    this.referenceNumber = '',
    this.notes = '',
    List<ReceiptAllocation>? allocations,
    required this.createdByUsername,
    String? createdAt,
    this.journalEntryId,
    this.region = 'All',
  })  : id = id ?? 'RCPT-${_receiptCounter++}',
        allocations = allocations ?? [],
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get allocatedAmount => allocations.fold(0.0, (s, a) => s + a.amount);
  double get unallocatedAmount => amount - allocatedAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'date': date,
        'dateIso': dateIso,
        'amount': amount,
        'bankAccountCode': bankAccountCode,
        'method': method.name,
        'referenceNumber': referenceNumber,
        'notes': notes,
        'allocations': allocations.map((a) => a.toMap()).toList(),
        'createdByUsername': createdByUsername,
        'createdAt': createdAt,
        'journalEntryId': journalEntryId,
        'region': region,
      };

  static CustomerReceipt fromMap(Map<String, dynamic> m) => CustomerReceipt(
        id: m['id'],
        customerId: m['customerId'] ?? '',
        date: m['date'] ?? '',
        dateIso: m['dateIso'] ?? '',
        amount: (m['amount'] ?? 0).toDouble(),
        bankAccountCode: m['bankAccountCode'] ?? '',
        method: PaymentMethod.values.firstWhere((p) => p.name == m['method'], orElse: () => PaymentMethod.bankTransfer),
        referenceNumber: m['referenceNumber'] ?? '',
        notes: m['notes'] ?? '',
        allocations: (m['allocations'] as List<dynamic>? ?? []).map((a) => ReceiptAllocation.fromMap(Map<String, dynamic>.from(a))).toList(),
        createdByUsername: m['createdByUsername'] ?? '',
        createdAt: m['createdAt'],
        journalEntryId: m['journalEntryId'],
        region: m['region'] ?? 'All',
      );
}

int _receiptCounter = 1;
final List<CustomerReceipt> sampleCustomerReceipts = [];

// Total ever collected against one invoice, across every receipt's allocations - the single
// source of truth invoice.effectiveStatus (Paid/Partially Paid) is computed from.
double invoiceAmountPaid(String invoiceId) {
  double total = 0;
  for (final r in sampleCustomerReceipts) {
    for (final a in r.allocations) {
      if (a.invoiceId == invoiceId) total += a.amount;
    }
  }
  return total;
}
