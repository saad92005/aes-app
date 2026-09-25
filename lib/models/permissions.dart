part of '../main.dart';

class Permissions {
  final AppUser user;
  Permissions(this.user);

  bool get seesAllRegions => user.region == 'All';

  // Work orders (and Reports, which is the same underlying work order data in sheet form)
  // are restricted to the coordination roles that actually run operations - Back Office,
  // Operational Manager, Head of Operations, CEO - plus whichever employee/vendor a
  // specific work order is assigned to (handled separately in WorkOrdersScreen/
  // ReportsScreen, not here). Roles added later (Finance, Store Manager, Procurement,
  // Office Staff) have no operational reason to see every work order company-wide, so this
  // is now an explicit allow-list rather than "everyone except employee/vendor" - that
  // negative check silently gave full visibility to every new role added since, which is
  // exactly the bug that prompted this rewrite.
  // HSSE included here too - safety oversight needs visibility into what field work is
  // actually happening, not just attendance. BDM/HRM/Admin deliberately excluded - that role
  // is HR/business-development/office-admin, not operational coordination.
  bool get _isWorkOrderCoordinationRole =>
      user.role == UserRole.backOffice ||
      user.role == UserRole.operationalManager ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo ||
      user.role == UserRole.hsse;

  bool get canViewReports => _isWorkOrderCoordinationRole;

  bool get canViewAllWorkOrders => _isWorkOrderCoordinationRole;

  bool get canApproveWorkOrders =>
      user.role == UserRole.operationalManager ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo;

  bool get canViewAllPettyCash =>
      user.role == UserRole.operationalManager ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.finance ||
      user.role == UserRole.ceo;

  // Two-stage expense approval: Operational Manager reviews first (their own region, via
  // the existing region-scoping every list screen already applies), then Finance gives the
  // final sign-off. Head of Operations and CEO can act at either stage as company-wide
  // authority above both. canApproveExpenses is kept as the union of both stages for any
  // code that only needs "can this person approve an expense at all" (e.g. nav visibility).
  bool get canApproveExpenseStage1 =>
      user.role == UserRole.operationalManager ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo;

  bool get canApproveExpenseStage2 =>
      user.role == UserRole.finance ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo;

  bool get canApproveExpenses =>
      canApproveExpenseStage1 || canApproveExpenseStage2;

  bool get canViewFinanceModule => user.role != UserRole.backOffice;

  // User account management (add/delete/edit login credentials) - CEO plus BDM/HRM/Admin,
  // since HR account onboarding is literally part of that role's job.
  bool get canManageEmployees =>
      user.role == UserRole.ceo || user.role == UserRole.bdmHrmAdmin;

  bool get canViewVendorBills =>
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo ||
      user.role == UserRole.backOffice ||
      user.role == UserRole.operationalManager ||
      user.role == UserRole.finance;

  // Internal cost/profit-margin figures on a quotation - never shown to employees or
  // vendors, and never included in anything sent to a client.
  bool get canViewInternalCosting =>
      user.role == UserRole.backOffice ||
      user.role == UserRole.ceo ||
      user.role == UserRole.finance ||
      user.role == UserRole.headOfOperations;

  bool get canManageSites =>
      user.role == UserRole.backOffice ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo;

  bool get canUseGmailSync =>
      user.role == UserRole.backOffice ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo;

  bool get canCheckInOut => user.role != UserRole.vendor;

  // BDM/HRM/Admin included for the HR side of that role (monitoring attendance company-wide);
  // HSSE included for safety oversight (who's actually on site).
  bool get canViewAttendanceReport =>
      user.role == UserRole.backOffice ||
      user.role == UserRole.operationalManager ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo ||
      user.role == UserRole.bdmHrmAdmin ||
      user.role == UserRole.hsse;

  // Open to every role - the assistant answers about the caller's own visible data plus
  // general questions, so there's no reason to gate it by role the way the data screens
  // themselves are gated.
  bool get canUseAiAssistant => true;

  // Store Manager and CEO do day-to-day stock entry (add items, record in/out).
  bool get canManageInventory =>
      user.role == UserRole.storeManager || user.role == UserRole.ceo;

  // Head of Operations, Operational Manager, and Finance get visibility (stock levels,
  // transaction log, tool assignments, CSV export) without doing data entry themselves -
  // same split as canManageInventory implies. Deliberately excludes Back Office and every
  // field role (Employee, Vendor, Procurement, Office Staff) - store inventory has nothing
  // to do with their job. extraInventoryAccess is the one-off per-employee exception for
  // someone in an otherwise-excluded role who still needs it (e.g. a specific Back Office
  // person handling store reconciliation) - toggled per employee, not a role change.
  bool get canViewInventory =>
      canManageInventory ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.operationalManager ||
      user.role == UserRole.finance ||
      user.extraInventoryAccess;

  // Invoices are financial documents bundling sent quotations - same roles that can already
  // see internal costing figures.
  bool get canManageInvoices => canViewInternalCosting;

  // Leave: everyone with an actual employment relationship with the company can submit one;
  // vendors are external and don't go through this. Approval is the 4 roles the leave
  // application must alert - back office, operational manager, head of operations, and CEO.
  bool get canSubmitLeave => user.role != UserRole.vendor;

  // BDM/HRM/Admin included - leave approval is an HR function.
  bool get canApproveLeave =>
      user.role == UserRole.backOffice ||
      user.role == UserRole.operationalManager ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo ||
      user.role == UserRole.bdmHrmAdmin;

  // Manual work order creation (independent of Gmail sync/quotation-flow auto-creation) -
  // the coordination roles that would actually be logging a work order that didn't arrive
  // by email.
  bool get canCreateWorkOrder =>
      user.role == UserRole.backOffice ||
      user.role == UserRole.operationalManager ||
      user.role == UserRole.headOfOperations ||
      user.role == UserRole.ceo;

  // Editing an existing work order's own details (site name, address, region, priority,
  // description, target finish) - same coordination roles as canCreateWorkOrder, explicitly
  // NOT the assigned employee/vendor. An employee doing the fieldwork can add their own site
  // notes/photos through the separate Start Job/Mark Complete flow, but never rewrite the
  // work order's own facts (location, priority, etc.) themselves.
  bool get canEditWorkOrder => canCreateWorkOrder;

  // Every role except vendor can submit their own expense claims now - vendors already have
  // their own separate VendorBill flow, so extending this to them would be a duplicate path
  // for the same cost.
  bool get canSubmitExpense => user.role != UserRole.vendor;

  // Regional Finance hubs (Quotations + Expenses + P&L for one region) are dedicated to a
  // Finance-role user actually assigned to that region - same pattern the app already uses
  // for backOffice (separate accounts per region, e.g. one backOffice user per region rather
  // than one shared account), not shared with backOffice/headOfOperations/CEO. A
  // company-wide Finance user (region == 'All') sees every region's hub. CEO gets the
  // 3-region Company P&L comparison instead of these two directly.
  bool get canViewMultanFinance =>
      user.role == UserRole.finance &&
      (user.region == 'Multan' || seesAllRegions);
  bool get canViewFaisalabadFinance =>
      user.role == UserRole.finance &&
      (user.region == 'Faisalabad' || seesAllRegions);

  // Per-employee ledger (cash advances, deductions, reimbursements) - sensitive personal
  // financial records, kept as tightly scoped as expense approval (Finance) plus the CEO for
  // full company visibility.
  bool get canManageLedger =>
      user.role == UserRole.finance || user.role == UserRole.ceo;

  // Chart of Accounts / Journal Entries / General Ledger / Trial Balance / Balance Sheet /
  // P&L / Cash Flow Statement - the core double-entry accounting module. Kept to the same two
  // roles as canManageLedger (Finance does the bookkeeping, CEO has full company visibility) -
  // this is more sensitive and more technical than anything else in the app, not something
  // Back Office/Operational Manager/Head of Operations need day-to-day access to.
  bool get canManageAccounting =>
      user.role == UserRole.finance || user.role == UserRole.ceo;

  // Payroll - salary figures, bank info, deductions. Explicitly NOT granted to
  // Attendance-facing roles (Back Office, Operational Manager, HSSE) even though they can see
  // attendance data Payroll reads from - "Attendance Admin should not automatically have
  // access to salary information" is an explicit requirement. Finance runs payroll day to day;
  // BDM/HRM/Admin gets it too since payroll is as much an HR function as an accounting one;
  // CEO has full visibility as always.
  bool get canManagePayroll =>
      user.role == UserRole.finance ||
      user.role == UserRole.ceo ||
      user.role == UserRole.bdmHrmAdmin;

  // Every employed role can see their OWN payslips/salary/payroll history - never anyone
  // else's. Vendors are external and were never on payroll to begin with.
  bool get canViewOwnPayslips => user.role != UserRole.vendor;

  // "Finalized payroll should not be editable without an explicit 'Reopen Payroll'
  // permission" - kept to CEO only (narrower than canManagePayroll) since reopening a
  // finalized/paid month is the one payroll action with real financial-integrity risk if
  // used casually.
  bool get canReopenPayroll => user.role == UserRole.ceo;
}
