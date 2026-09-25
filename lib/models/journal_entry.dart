part of '../main.dart';

// ---------------- GENERAL LEDGER / JOURNAL ENTRIES ----------------
// Tags which section of the Cash Flow Statement a journal entry's cash movement belongs to.
// Set once at posting time (the person entering the transaction knows what it actually was),
// not inferred after the fact - inference from account codes alone can't reliably tell "bought
// a vehicle" (investing) apart from "paid a repair bill" (operating), even though both are a
// credit to a bank account.
enum CashFlowActivity { operating, investing, financing, none }

extension CashFlowActivityLabel on CashFlowActivity {
  String get label {
    switch (this) {
      case CashFlowActivity.operating:
        return 'Operating Activities';
      case CashFlowActivity.investing:
        return 'Investing Activities';
      case CashFlowActivity.financing:
        return 'Financing Activities';
      case CashFlowActivity.none:
        return 'Not Cash-Related';
    }
  }
}

class JournalLine {
  String accountCode;
  // Denormalized at posting time so a later account rename doesn't rewrite history - the
  // General Ledger and old journal entries should always read back exactly as they were
  // posted, per "Changes to the COA must not corrupt historical transactions."
  String accountName;
  double debit;
  double credit;
  String description;
  // Subsidiary-ledger dimensions - optional tags that let one control account (e.g. 1130
  // Accounts Receivable, 2110 Accounts Payable) carry a per-customer/vendor/project breakdown
  // without needing a separate COA leaf account per customer/vendor/project. Only ever read by
  // the module that owns that dimension (e.g. customerArBalance filters on customerId) - a
  // line with none of these set is just an ordinary account posting.
  String? customerId;
  String? vendorId;
  String? projectId;

  JournalLine({
    required this.accountCode,
    required this.accountName,
    this.debit = 0,
    this.credit = 0,
    this.description = '',
    this.customerId,
    this.vendorId,
    this.projectId,
  });

  Map<String, dynamic> toMap() => {
        'accountCode': accountCode,
        'accountName': accountName,
        'debit': debit,
        'credit': credit,
        'description': description,
        'customerId': customerId,
        'vendorId': vendorId,
        'projectId': projectId,
      };

  static JournalLine fromMap(Map<String, dynamic> m) => JournalLine(
        accountCode: m['accountCode'] ?? '',
        accountName: m['accountName'] ?? '',
        debit: (m['debit'] ?? 0).toDouble(),
        credit: (m['credit'] ?? 0).toDouble(),
        customerId: m['customerId'],
        vendorId: m['vendorId'],
        projectId: m['projectId'],
        description: m['description'] ?? '',
      );
}

class JournalEntry {
  final String id; // 'JE-<n>'
  // The accounting/effective date (yyyy-MM-dd + ISO) - distinct from createdAt, which is when
  // it was actually keyed into the system. Financial statements are always period-filtered on
  // this, never on createdAt.
  final String date;
  final String dateIso;
  String memo;
  final String createdByUsername;
  final String createdAt;
  final CashFlowActivity cashFlowActivity;
  // Opening-balance entries (see Account opening balance flow) post against 3600 - Opening
  // Balance Equity, and are flagged so reports/UI can label them distinctly from normal
  // activity.
  final bool isOpeningBalance;
  final bool isReversal;
  final String? reversalOfEntryId;
  // Once a normal (non-reversed) entry has been reversed, this holds the reversing entry's id
  // (empty string otherwise) so the UI can grey it out and block reversing it a second time -
  // correcting a mistake is always a NEW offsetting entry, never an edit or delete of the
  // original (see JournalEntriesScreen).
  String reversedByEntryId;
  final List<JournalLine> lines;

  JournalEntry({
    String? id,
    required this.date,
    required this.dateIso,
    this.memo = '',
    required this.createdByUsername,
    String? createdAt,
    this.cashFlowActivity = CashFlowActivity.operating,
    this.isOpeningBalance = false,
    this.isReversal = false,
    this.reversalOfEntryId,
    String? reversedByEntryId,
    required this.lines,
  })  : id = id ?? 'JE-${_journalEntryCounter++}',
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        reversedByEntryId = reversedByEntryId ?? '';

  double get totalDebit => lines.fold(0.0, (s, l) => s + l.debit);
  double get totalCredit => lines.fold(0.0, (s, l) => s + l.credit);
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;
  bool get hasBeenReversed => reversedByEntryId.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'dateIso': dateIso,
        'memo': memo,
        'createdByUsername': createdByUsername,
        'createdAt': createdAt,
        'cashFlowActivity': cashFlowActivity.name,
        'isOpeningBalance': isOpeningBalance,
        'isReversal': isReversal,
        'reversalOfEntryId': reversalOfEntryId,
        'reversedByEntryId': reversedByEntryId,
        'lines': lines.map((l) => l.toMap()).toList(),
      };

  static JournalEntry fromMap(Map<String, dynamic> m) => JournalEntry(
        id: m['id'],
        date: m['date'] ?? '',
        dateIso: m['dateIso'] ?? '',
        memo: m['memo'] ?? '',
        createdByUsername: m['createdByUsername'] ?? '',
        createdAt: m['createdAt'],
        cashFlowActivity: CashFlowActivity.values.firstWhere((c) => c.name == m['cashFlowActivity'], orElse: () => CashFlowActivity.operating),
        isOpeningBalance: m['isOpeningBalance'] ?? false,
        isReversal: m['isReversal'] ?? false,
        reversalOfEntryId: m['reversalOfEntryId'],
        reversedByEntryId: m['reversedByEntryId'] ?? '',
        lines: (m['lines'] as List<dynamic>? ?? []).map((l) => JournalLine.fromMap(Map<String, dynamic>.from(l))).toList(),
      );
}

int _journalEntryCounter = 1;
final List<JournalEntry> sampleJournalEntries = [];

// ---------------- BALANCE / REPORT COMPUTATION ----------------
// Every figure in every accounting report (Trial Balance, Balance Sheet, P&L, Cash Flow,
// General Ledger) is derived live from sampleJournalEntries - there is no separately-stored
// "current balance" field anywhere to drift out of sync with the entries that are the actual
// source of truth.

// Net movement on one account only (not its children), signed so a positive number always
// means "more of the account's normal balance" - e.g. positive for a Bank account means more
// cash, positive for a Payable means more owed. `from`/`to` are inclusive date bounds (ISO
// yyyy-MM-dd string compares work correctly since dateIso is always zero-padded); either can
// be left null for an open-ended bound.
double directAccountMovement(String accountCode, {String? from, String? to}) {
  double total = 0;
  final account = accountByCode(accountCode);
  final normal = account?.normalBalance ?? NormalBalance.debit;
  for (final entry in sampleJournalEntries) {
    if (from != null && entry.dateIso.compareTo(from) < 0) continue;
    if (to != null && entry.dateIso.compareTo(to) > 0) continue;
    for (final line in entry.lines) {
      if (line.accountCode != accountCode) continue;
      total += normal == NormalBalance.debit ? (line.debit - line.credit) : (line.credit - line.debit);
    }
  }
  return total;
}

// Same as directAccountMovement, but rolled up through every descendant account too - the
// figure to show next to a header/parent account like "1000 - Assets", which never has
// journal lines posted to it directly.
double rollupAccountMovement(String accountCode, {String? from, String? to}) {
  double total = directAccountMovement(accountCode, from: from, to: to);
  for (final child in childAccountsOf(accountCode)) {
    total += rollupAccountMovement(child.code, from: from, to: to);
  }
  return total;
}

// True if this account is, or descends from, the Cash (1110) or Bank Accounts (1120) parents -
// used by the Cash Flow Statement to isolate lines that actually moved cash.
bool isCashOrBankAccount(String code) {
  if (code == '1110' || code == '1120') return true;
  final account = accountByCode(code);
  if (account == null) return false;
  for (final ancestor in accountAncestors(account)) {
    if (ancestor.code == '1110' || ancestor.code == '1120') return true;
  }
  return false;
}

// Whether `code` has already received an opening-balance journal entry - each account can only
// have one (see ChartOfAccountsScreen's "Set Opening Balance" action); corrections after that
// go through a normal adjusting journal entry instead.
bool hasOpeningBalanceEntry(String code) => sampleJournalEntries.any((e) => e.isOpeningBalance && e.lines.any((l) => l.accountCode == code));

// Total movement across every top-level account of one statement type (e.g. all of Revenue,
// all of Operating Expenses) for a period - the building block for P&L lines and the Finance
// Dashboard's KPI tiles, shared so both always agree.
double accountTypeMovement(AccountType type, {String? from, String? to}) {
  double total = 0;
  for (final a in sampleAccounts.where((a) => a.parentCode == null && a.type == type)) {
    total += rollupAccountMovement(a.code, from: from, to: to);
  }
  return total;
}

// Net profit/loss for the period, computed live from Revenue/Cost of Sales/Expense/Other
// Income/Other Expense activity - this is what the Balance Sheet shows as "Current Year
// Profit/Loss (Unposted)" so the sheet balances even before a formal period-close (a year-end
// closing journal entry that zeroes revenue/expense accounts into Retained Earnings) has been
// done. Real accounting systems distinguish live and closed P&L the same way.
double computeNetProfit({String? from, String? to}) {
  double revenue = 0, otherIncome = 0, cogs = 0, expense = 0, otherExpense = 0;
  for (final acc in sampleAccounts.where((a) => a.parentCode == null)) {
    final movement = rollupAccountMovement(acc.code, from: from, to: to);
    switch (acc.type) {
      case AccountType.revenue:
        revenue += movement;
        break;
      case AccountType.otherIncome:
        otherIncome += movement;
        break;
      case AccountType.costOfSales:
        cogs += movement;
        break;
      case AccountType.expense:
        expense += movement;
        break;
      case AccountType.otherExpense:
        otherExpense += movement;
        break;
      default:
        break;
    }
  }
  return revenue + otherIncome - cogs - expense - otherExpense;
}
