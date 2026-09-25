part of '../main.dart';

// ---------------- INVOICES ----------------
// An invoice bundles one or more quotations that were actually sent (QuotationData.sentAt)
// to the same client within a chosen month. Line items are snapshotted at generation time so
// editing the source quotation later never retroactively changes an already-issued invoice.
class InvoiceLineItemSnapshot {
  final String quotationId;
  final String description;
  final String unit;
  final double qty;
  final double rate;
  final double amount;

  InvoiceLineItemSnapshot({
    required this.quotationId,
    required this.description,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'quotationId': quotationId,
        'description': description,
        'unit': unit,
        'qty': qty,
        'rate': rate,
        'amount': amount,
      };

  static InvoiceLineItemSnapshot fromMap(Map<String, dynamic> m) => InvoiceLineItemSnapshot(
        quotationId: m['quotationId'] ?? '',
        description: m['description'] ?? '',
        unit: m['unit'] ?? 'Job',
        qty: (m['qty'] ?? 0).toDouble(),
        rate: (m['rate'] ?? 0).toDouble(),
        amount: (m['amount'] ?? 0).toDouble(),
      );
}

int _invoiceCounter = 1;

// The real, user-controlled lifecycle states - draft can still be freely edited/regenerated,
// posted is locked and has created its accounting entry, cancelled has reversed that entry.
// "Partially Paid" / "Paid" / "Overdue" are NOT stored states here - they're always computed
// live from actual receipts and the due date (see Invoice.effectiveStatus) so they can never
// drift out of sync with what was actually collected, which a manually-set status field would
// risk.
enum InvoiceStatus { draft, posted, cancelled }

// The full displayed lifecycle, including the computed states - what the UI actually shows.
enum InvoiceDisplayStatus { draft, posted, partiallyPaid, paid, overdue, cancelled }

extension InvoiceDisplayStatusLabel on InvoiceDisplayStatus {
  String get label {
    switch (this) {
      case InvoiceDisplayStatus.draft:
        return 'Draft';
      case InvoiceDisplayStatus.posted:
        return 'Posted';
      case InvoiceDisplayStatus.partiallyPaid:
        return 'Partially Paid';
      case InvoiceDisplayStatus.paid:
        return 'Paid';
      case InvoiceDisplayStatus.overdue:
        return 'Overdue';
      case InvoiceDisplayStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case InvoiceDisplayStatus.draft:
        return const Color(0xFF9A9A9A);
      case InvoiceDisplayStatus.posted:
        return const Color(0xFF2196F3);
      case InvoiceDisplayStatus.partiallyPaid:
        return const Color(0xFFFF9800);
      case InvoiceDisplayStatus.paid:
        return const Color(0xFF2E7D32);
      case InvoiceDisplayStatus.overdue:
        return const Color(0xFFD32F2F);
      case InvoiceDisplayStatus.cancelled:
        return const Color(0xFF616161);
    }
  }
}

class Invoice {
  final String id;
  final String clientName;
  final String clientCompany;
  final String month; // 'YYYY-MM'
  final List<String> quotationIds;
  final List<String> workOrderIds;
  final List<InvoiceLineItemSnapshot> lineItems;
  final String generatedAt;
  final String generatedByUsername;
  final String mode; // 'auto' or 'manual'
  final String region;
  // Null only for invoices generated before Customers existed - resolved lazily the first time
  // such a legacy invoice is opened (see InvoicesListScreen._resolveCustomer).
  String? customerId;
  InvoiceStatus status;
  String? dueDateIso;
  // Which Revenue account this invoice's amount is credited to on posting - defaults to
  // Service Revenue, editable before posting.
  String revenueAccountCode;
  double taxRatePercent;
  String? postedAt;
  String? postedByUsername;
  String? journalEntryId;
  String? cancelledAt;
  String? cancelledByUsername;

  Invoice({
    String? id,
    required this.clientName,
    required this.clientCompany,
    required this.month,
    required this.quotationIds,
    required this.workOrderIds,
    required this.lineItems,
    required this.generatedAt,
    required this.generatedByUsername,
    required this.mode,
    this.region = 'All',
    this.customerId,
    this.status = InvoiceStatus.draft,
    this.dueDateIso,
    this.revenueAccountCode = '4200',
    this.taxRatePercent = 0,
    this.postedAt,
    this.postedByUsername,
    this.journalEntryId,
    this.cancelledAt,
    this.cancelledByUsername,
  }) : id = id ?? 'INV-${_invoiceCounter++}';

  double get totalAmount => lineItems.fold(0.0, (sum, i) => sum + i.amount);
  double get taxAmount => totalAmount * (taxRatePercent / 100);
  double get totalWithTax => totalAmount + taxAmount;

  InvoiceDisplayStatus get effectiveStatus {
    if (status == InvoiceStatus.cancelled) return InvoiceDisplayStatus.cancelled;
    if (status == InvoiceStatus.draft) return InvoiceDisplayStatus.draft;
    final paid = invoiceAmountPaid(id);
    final outstanding = totalWithTax - paid;
    if (outstanding.abs() < 0.01) return InvoiceDisplayStatus.paid;
    if (paid > 0.01) return InvoiceDisplayStatus.partiallyPaid;
    final due = dueDateIso != null ? DateTime.tryParse(dueDateIso!) : null;
    if (due != null && DateTime.now().isAfter(due)) return InvoiceDisplayStatus.overdue;
    return InvoiceDisplayStatus.posted;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'clientName': clientName,
        'clientCompany': clientCompany,
        'month': month,
        'quotationIds': quotationIds,
        'workOrderIds': workOrderIds,
        'lineItems': lineItems.map((i) => i.toMap()).toList(),
        'generatedAt': generatedAt,
        'generatedByUsername': generatedByUsername,
        'mode': mode,
        'region': region,
        'customerId': customerId,
        'status': status.name,
        'dueDateIso': dueDateIso,
        'revenueAccountCode': revenueAccountCode,
        'taxRatePercent': taxRatePercent,
        'postedAt': postedAt,
        'postedByUsername': postedByUsername,
        'journalEntryId': journalEntryId,
        'cancelledAt': cancelledAt,
        'cancelledByUsername': cancelledByUsername,
      };

  static Invoice fromMap(Map<String, dynamic> m) => Invoice(
        id: m['id'],
        clientName: m['clientName'] ?? '',
        clientCompany: m['clientCompany'] ?? '',
        month: m['month'] ?? '',
        quotationIds: List<String>.from(m['quotationIds'] ?? []),
        workOrderIds: List<String>.from(m['workOrderIds'] ?? []),
        lineItems: (m['lineItems'] as List? ?? []).map((i) => InvoiceLineItemSnapshot.fromMap(Map<String, dynamic>.from(i))).toList(),
        generatedAt: m['generatedAt'] ?? '',
        generatedByUsername: m['generatedByUsername'] ?? '',
        mode: m['mode'] ?? 'manual',
        region: m['region'] ?? 'All',
        customerId: m['customerId'],
        status: InvoiceStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => InvoiceStatus.draft),
        dueDateIso: m['dueDateIso'],
        revenueAccountCode: m['revenueAccountCode'] ?? '4200',
        taxRatePercent: (m['taxRatePercent'] ?? 0).toDouble(),
        postedAt: m['postedAt'],
        postedByUsername: m['postedByUsername'],
        journalEntryId: m['journalEntryId'],
        cancelledAt: m['cancelledAt'],
        cancelledByUsername: m['cancelledByUsername'],
      );
}

final List<Invoice> sampleInvoices = [];
