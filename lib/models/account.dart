part of '../main.dart';

// ---------------- CHART OF ACCOUNTS ----------------
// Standard 8-category numbering, same shape every real accounting system/ERP uses. Ranges are
// advisory (checked by _codeRangeWarning below, not hard-blocked) so a company's real COA -
// which may not follow this exact numbering - can still be entered without the UI fighting it.
enum AccountType { asset, liability, equity, revenue, costOfSales, expense, otherIncome, otherExpense }

extension AccountTypeLabel on AccountType {
  String get label {
    switch (this) {
      case AccountType.asset:
        return 'Assets';
      case AccountType.liability:
        return 'Liabilities';
      case AccountType.equity:
        return 'Equity';
      case AccountType.revenue:
        return 'Revenue / Income';
      case AccountType.costOfSales:
        return 'Cost of Sales';
      case AccountType.expense:
        return 'Expenses';
      case AccountType.otherIncome:
        return 'Other Income';
      case AccountType.otherExpense:
        return 'Other Expenses';
    }
  }

  // Advisory code range (start, end) - see note above.
  (int, int) get codeRange {
    switch (this) {
      case AccountType.asset:
        return (1000, 1999);
      case AccountType.liability:
        return (2000, 2999);
      case AccountType.equity:
        return (3000, 3999);
      case AccountType.revenue:
        return (4000, 4999);
      case AccountType.costOfSales:
        return (5000, 5999);
      case AccountType.expense:
        return (6000, 6999);
      case AccountType.otherIncome:
        return (7000, 7999);
      case AccountType.otherExpense:
        return (8000, 8999);
    }
  }

  // The normal (increasing) balance side for this account type under standard double-entry
  // rules - Assets/Cost of Sales/Expenses/Other Expenses increase with a Debit, Liabilities/
  // Equity/Revenue/Other Income increase with a Credit. Individual accounts can still override
  // this (see Account.normalBalance) for contra accounts like Accumulated Depreciation, which
  // sits under Assets but carries a natural Credit balance.
  NormalBalance get defaultNormalBalance {
    switch (this) {
      case AccountType.asset:
      case AccountType.costOfSales:
      case AccountType.expense:
      case AccountType.otherExpense:
        return NormalBalance.debit;
      case AccountType.liability:
      case AccountType.equity:
      case AccountType.revenue:
      case AccountType.otherIncome:
        return NormalBalance.credit;
    }
  }

  // Where this account type surfaces in the two core financial statements.
  bool get isBalanceSheet => this == AccountType.asset || this == AccountType.liability || this == AccountType.equity;
  bool get isIncomeStatement => !isBalanceSheet;
}

enum NormalBalance { debit, credit }

extension NormalBalanceLabel on NormalBalance {
  String get label => this == NormalBalance.debit ? 'Debit' : 'Credit';
}

// Null outside the account type's advisory range - shown as a soft warning in the Add/Edit
// Account form, never a hard block, since the real company COA (provided separately) is the
// source of truth and may number things differently.
String? accountCodeRangeWarning(String code, AccountType type) {
  final n = int.tryParse(code.trim());
  if (n == null) return 'Account code must be numeric';
  final (start, end) = type.codeRange;
  if (n < start || n > end) {
    return 'Outside the usual $start–$end range for ${type.label} - allowed, but double-check the code';
  }
  return null;
}

class Account {
  final String code; // e.g. "1111" - doubles as the document id, so codes must be unique.
  String name;
  AccountType type;
  String? parentCode; // null = top-level account (e.g. "1000 - Assets" itself has no parent)
  String category; // free-text sub-classification, e.g. "Current Assets", "Fixed Assets"
  NormalBalance normalBalance;
  String description;
  bool isActive;
  final String createdAt; // ISO 8601, set once
  String updatedAt; // ISO 8601, refreshed on every edit
  // Only meaningful for a leaf account under Bank Accounts (1120) - lets each real bank
  // account carry its own reference details without a separate "bank accounts" collection.
  String? bankName;
  String? bankAccountNumber;

  Account({
    required this.code,
    required this.name,
    required this.type,
    this.parentCode,
    this.category = '',
    NormalBalance? normalBalance,
    this.description = '',
    this.isActive = true,
    String? createdAt,
    String? updatedAt,
    this.bankName,
    this.bankAccountNumber,
  })  : normalBalance = normalBalance ?? type.defaultNormalBalance,
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  bool get isBankLeaf => parentCode == '1120';

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'type': type.name,
        'parentCode': parentCode,
        'category': category,
        'normalBalance': normalBalance.name,
        'description': description,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
      };

  static Account fromMap(Map<String, dynamic> m) => Account(
        code: m['code'] ?? '',
        name: m['name'] ?? '',
        type: AccountType.values.firstWhere((t) => t.name == m['type'], orElse: () => AccountType.asset),
        parentCode: m['parentCode'],
        category: m['category'] ?? '',
        normalBalance: NormalBalance.values.firstWhere((n) => n.name == m['normalBalance'], orElse: () => NormalBalance.debit),
        description: m['description'] ?? '',
        isActive: m['isActive'] ?? true,
        createdAt: m['createdAt'],
        updatedAt: m['updatedAt'],
        bankName: m['bankName'],
        bankAccountNumber: m['bankAccountNumber'],
      );
}

final List<Account> sampleAccounts = [];

// Every account under a given parent code, sorted by code - the basic building block the tree
// view / dropdowns use to walk the hierarchy.
List<Account> childAccountsOf(String? parentCode) =>
    sampleAccounts.where((a) => a.parentCode == parentCode).toList()..sort((a, b) => a.code.compareTo(b.code));

Account? accountByCode(String code) {
  for (final a in sampleAccounts) {
    if (a.code == code) return a;
  }
  return null;
}

// Full ancestor chain, immediate parent first - used to build a breadcrumb like
// "Assets > Current Assets > Bank Accounts" for a given leaf account.
List<Account> accountAncestors(Account account) {
  final chain = <Account>[];
  var current = account.parentCode;
  while (current != null) {
    final parent = accountByCode(current);
    if (parent == null) break;
    chain.add(parent);
    current = parent.parentCode;
  }
  return chain;
}

// The standard Chart of Accounts described in the accounting module spec - seeded once, on
// explicit user action (see ChartOfAccountsScreen's "Seed Default Chart of Accounts" button),
// never silently/automatically. Every account here is fully editable afterward, and this list
// is meant to be reconciled against the company's real Chart of Accounts once provided -
// nothing about the engine depends on these exact codes/names.
List<Account> buildDefaultChartOfAccounts() {
  Account a(String code, String name, AccountType type, String? parent, String category, {NormalBalance? normal}) =>
      Account(code: code, name: name, type: type, parentCode: parent, category: category, normalBalance: normal);

  return [
    // ---- 1000-1999 Assets ----
    a('1000', 'Assets', AccountType.asset, null, ''),
    a('1100', 'Current Assets', AccountType.asset, '1000', 'Current Assets'),
    a('1110', 'Cash in Hand / Petty Cash', AccountType.asset, '1100', 'Cash'),
    a('1120', 'Bank Accounts', AccountType.asset, '1100', 'Bank Accounts'),
    a('1130', 'Accounts Receivable / Trade Receivables', AccountType.asset, '1100', 'Receivables'),
    a('1140', 'Inventory', AccountType.asset, '1100', 'Inventory'),
    a('1150', 'Prepaid Expenses', AccountType.asset, '1100', 'Prepaid Expenses'),
    a('1160', 'Advances', AccountType.asset, '1100', 'Advances'),
    a('1170', 'Security Deposits', AccountType.asset, '1100', 'Security Deposits'),
    a('1190', 'Other Current Assets', AccountType.asset, '1100', 'Other Current Assets'),
    a('1500', 'Fixed Assets', AccountType.asset, '1000', 'Fixed Assets'),
    a('1510', 'Vehicles', AccountType.asset, '1500', 'Fixed Assets'),
    a('1520', 'Equipment', AccountType.asset, '1500', 'Fixed Assets'),
    a('1530', 'Furniture & Fixtures', AccountType.asset, '1500', 'Fixed Assets'),
    a('1540', 'Computers / IT Equipment', AccountType.asset, '1500', 'Fixed Assets'),
    a('1590', 'Accumulated Depreciation', AccountType.asset, '1500', 'Fixed Assets', normal: NormalBalance.credit),
    a('1900', 'Other Non-Current Assets', AccountType.asset, '1000', 'Other Non-Current Assets'),

    // ---- 2000-2999 Liabilities ----
    a('2000', 'Liabilities', AccountType.liability, null, ''),
    a('2100', 'Current Liabilities', AccountType.liability, '2000', 'Current Liabilities'),
    a('2110', 'Accounts Payable / Trade Payables', AccountType.liability, '2100', 'Payables'),
    a('2120', 'Supplier Payables', AccountType.liability, '2100', 'Payables'),
    a('2130', 'Accrued Expenses', AccountType.liability, '2100', 'Accrued Expenses'),
    a('2140', 'Salaries Payable', AccountType.liability, '2100', 'Payroll Liabilities'),
    a('2150', 'Taxes Payable', AccountType.liability, '2100', 'Tax Liabilities'),
    a('2160', 'VAT / GST Payable', AccountType.liability, '2100', 'Tax Liabilities'),
    a('2170', 'Advances Received from Customers', AccountType.liability, '2100', 'Customer Advances'),
    a('2190', 'Other Current Liabilities', AccountType.liability, '2100', 'Other Current Liabilities'),
    a('2500', 'Long-Term Liabilities', AccountType.liability, '2000', 'Long-Term Liabilities'),
    a('2510', 'Bank Loans', AccountType.liability, '2500', 'Long-Term Liabilities'),
    a('2520', 'Loans Payable', AccountType.liability, '2500', 'Long-Term Liabilities'),

    // ---- 3000-3999 Equity ----
    a('3000', 'Equity', AccountType.equity, null, ''),
    a('3100', "Share Capital / Owner's Capital", AccountType.equity, '3000', 'Capital'),
    a('3200', 'Additional Capital', AccountType.equity, '3000', 'Capital'),
    a('3300', 'Retained Earnings', AccountType.equity, '3000', 'Retained Earnings'),
    a('3400', 'Current Year Profit / Loss', AccountType.equity, '3000', 'Current Year Earnings'),
    a('3500', 'Drawings / Dividends', AccountType.equity, '3000', 'Drawings', normal: NormalBalance.debit),
    a('3600', 'Opening Balance Equity', AccountType.equity, '3000', 'Opening Balance Equity'),

    // ---- 4000-4999 Revenue / Income ----
    a('4000', 'Revenue / Income', AccountType.revenue, null, ''),
    a('4100', 'Sales Revenue', AccountType.revenue, '4000', 'Operating Revenue'),
    a('4200', 'Service Revenue', AccountType.revenue, '4000', 'Operating Revenue'),
    a('4300', 'Contract Revenue', AccountType.revenue, '4000', 'Operating Revenue'),
    a('4400', 'Project Revenue', AccountType.revenue, '4000', 'Operating Revenue'),
    a('4900', 'Other Operating Income', AccountType.revenue, '4000', 'Operating Revenue'),

    // ---- 5000-5999 Cost of Sales ----
    a('5000', 'Cost of Sales / COGS', AccountType.costOfSales, null, ''),
    a('5100', 'Cost of Materials', AccountType.costOfSales, '5000', 'Direct Costs'),
    a('5200', 'Direct Labour', AccountType.costOfSales, '5000', 'Direct Costs'),
    a('5300', 'Subcontractor Costs', AccountType.costOfSales, '5000', 'Direct Costs'),
    a('5400', 'Direct Project Costs', AccountType.costOfSales, '5000', 'Direct Costs'),
    a('5500', 'Cost of Goods Sold', AccountType.costOfSales, '5000', 'Direct Costs'),
    a('5900', 'Other Direct Costs', AccountType.costOfSales, '5000', 'Direct Costs'),

    // ---- 6000-6999 Operating Expenses ----
    a('6000', 'Operating Expenses', AccountType.expense, null, ''),
    a('6100', 'Salaries & Wages', AccountType.expense, '6000', 'Payroll'),
    a('6110', 'Rent', AccountType.expense, '6000', 'Occupancy'),
    a('6120', 'Utilities', AccountType.expense, '6000', 'Occupancy'),
    a('6130', 'Internet & Telephone', AccountType.expense, '6000', 'Communications'),
    a('6140', 'Office Expenses', AccountType.expense, '6000', 'Office & Admin'),
    a('6150', 'Travel & Transportation', AccountType.expense, '6000', 'Travel'),
    a('6160', 'Fuel', AccountType.expense, '6000', 'Travel'),
    a('6170', 'Repairs & Maintenance', AccountType.expense, '6000', 'Maintenance'),
    a('6180', 'Insurance', AccountType.expense, '6000', 'Insurance'),
    a('6190', 'Professional Fees', AccountType.expense, '6000', 'Professional Services'),
    a('6200', 'Legal Fees', AccountType.expense, '6000', 'Professional Services'),
    a('6210', 'Accounting Fees', AccountType.expense, '6000', 'Professional Services'),
    a('6220', 'Marketing & Advertising', AccountType.expense, '6000', 'Marketing'),
    a('6230', 'Software / Subscriptions', AccountType.expense, '6000', 'IT & Software'),
    a('6240', 'Depreciation Expense', AccountType.expense, '6000', 'Depreciation'),
    a('6250', 'Bank Charges', AccountType.expense, '6000', 'Bank Charges'),
    a('6260', 'General & Administrative Expenses', AccountType.expense, '6000', 'Office & Admin'),
    a('6900', 'Other Operating Expenses', AccountType.expense, '6000', 'Other'),

    // ---- 7000-7999 Other Income ----
    a('7000', 'Other Income', AccountType.otherIncome, null, ''),
    a('7100', 'Interest Income', AccountType.otherIncome, '7000', 'Other Income'),
    a('7900', 'Miscellaneous Income', AccountType.otherIncome, '7000', 'Other Income'),

    // ---- 8000-8999 Other Expenses ----
    a('8000', 'Other Expenses', AccountType.otherExpense, null, ''),
    a('8100', 'Interest Expense', AccountType.otherExpense, '8000', 'Other Expenses'),
    a('8900', 'Miscellaneous Expense', AccountType.otherExpense, '8000', 'Other Expenses'),
  ];
}
