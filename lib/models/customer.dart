part of '../main.dart';

// ---------------- CUSTOMERS / ACCOUNTS RECEIVABLE ----------------
// A real customer master record - distinct from ClientEntry (lib/models/client.dart), which
// is only a lightweight name/company autocomplete for quotations. Customer carries everything
// AR actually needs: billing/tax info, payment terms, credit limit, and a link into the
// Chart of Accounts control account (1130 - Accounts Receivable) that every invoice/receipt
// posts against.
//
// There is deliberately no per-customer COA leaf account - that would explode the Chart of
// Accounts by one account per customer. Instead this follows standard ERP practice: ONE control
// account (1130) in the General Ledger, with each JournalLine tagged with customerId as a
// subsidiary-ledger dimension (see JournalLine.customerId). A customer's balance/aging/ledger
// are always computed by filtering journal lines on that tag - never stored separately - so
// there is exactly one source of truth for money owed, matching the "one accounting engine"
// requirement.
class Customer {
  final String id;
  String name;
  String company;
  String billingAddress;
  String phone;
  String email;
  String taxNumber;
  int paymentTermsDays; // e.g. 30 for "Net 30"
  double creditLimit; // 0 = no limit
  String region;
  bool isActive;
  final String createdAt;
  String updatedAt;

  Customer({
    String? id,
    required this.name,
    this.company = '',
    this.billingAddress = '',
    this.phone = '',
    this.email = '',
    this.taxNumber = '',
    this.paymentTermsDays = 30,
    this.creditLimit = 0,
    this.region = 'All',
    this.isActive = true,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? 'CUST-${_customerCounter++}',
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'company': company,
        'billingAddress': billingAddress,
        'phone': phone,
        'email': email,
        'taxNumber': taxNumber,
        'paymentTermsDays': paymentTermsDays,
        'creditLimit': creditLimit,
        'region': region,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static Customer fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'],
        name: m['name'] ?? '',
        company: m['company'] ?? '',
        billingAddress: m['billingAddress'] ?? '',
        phone: m['phone'] ?? '',
        email: m['email'] ?? '',
        taxNumber: m['taxNumber'] ?? '',
        paymentTermsDays: m['paymentTermsDays'] ?? 30,
        creditLimit: (m['creditLimit'] ?? 0).toDouble(),
        region: m['region'] ?? 'All',
        isActive: m['isActive'] ?? true,
        createdAt: m['createdAt'],
        updatedAt: m['updatedAt'],
      );
}

int _customerCounter = 1;
final List<Customer> sampleCustomers = [];

// Accounts Receivable control account - every customer-facing invoice/receipt posts here.
const String arControlAccountCode = '1130';

Customer? customerById(String id) {
  for (final c in sampleCustomers) {
    if (c.id == id) return c;
  }
  return null;
}

// Finds an existing customer by name+company (case-insensitive), or creates a bare-bones one -
// used when generating an invoice from a quotation's free-text client name, so every invoice
// always resolves to a real Customer record even before Finance has had a chance to enrich it
// with billing/tax/credit-limit details. Does not persist - caller is responsible for saving
// if a new one was created (see InvoicesScreen._resolveCustomer).
Customer findOrBuildCustomer({required String name, required String company, required String region}) {
  final key = '${name.trim().toLowerCase()}|${company.trim().toLowerCase()}';
  for (final c in sampleCustomers) {
    if ('${c.name.trim().toLowerCase()}|${c.company.trim().toLowerCase()}' == key) return c;
  }
  return Customer(name: name.trim(), company: company.trim(), region: region);
}

// Live AR balance for one customer - positive means the customer owes the company money.
// Computed the same way every other account balance is (see directAccountMovement), just
// additionally filtered to journal lines tagged with this customer.
double customerArBalance(String customerId, {String? to}) {
  double total = 0;
  for (final entry in sampleJournalEntries) {
    if (to != null && entry.dateIso.compareTo(to) > 0) continue;
    for (final line in entry.lines) {
      if (line.accountCode != arControlAccountCode || line.customerId != customerId) continue;
      // AR is a Debit-normal account - a debit (invoice) increases what's owed, a credit
      // (receipt) decreases it.
      total += line.debit - line.credit;
    }
  }
  return total;
}

// Aging buckets (0-30/31-60/61-90/90+ days overdue) for a customer's currently-unpaid posted
// invoices, based on each invoice's due date vs `asOf`. Cancelled/draft invoices are excluded;
// fully-paid invoices contribute 0.
({double current, double days30, double days60, double days90, double over90}) customerAging(String customerId, {DateTime? asOf}) {
  final today = asOf ?? DateTime.now();
  double current = 0, d30 = 0, d60 = 0, d90 = 0, over90 = 0;
  for (final inv in sampleInvoices.where((i) => i.customerId == customerId && i.status == InvoiceStatus.posted)) {
    final outstanding = inv.totalWithTax - invoiceAmountPaid(inv.id);
    if (outstanding.abs() < 0.01) continue;
    final due = inv.dueDateIso != null ? DateTime.tryParse(inv.dueDateIso!) : null;
    final daysOverdue = due == null ? 0 : today.difference(due).inDays;
    if (daysOverdue <= 0) {
      current += outstanding;
    } else if (daysOverdue <= 30) {
      d30 += outstanding;
    } else if (daysOverdue <= 60) {
      d60 += outstanding;
    } else if (daysOverdue <= 90) {
      d90 += outstanding;
    } else {
      over90 += outstanding;
    }
  }
  return (current: current, days30: d30, days60: d60, days90: d90, over90: over90);
}
