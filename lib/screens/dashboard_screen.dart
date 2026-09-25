part of '../main.dart';

// Master kill switch for the whole Finance/Accounting module (Finance Dashboard, Customers,
// Customer Receipts, Chart of Accounts, Journal Entries, Accounting Reports, Ledger, the
// regional Finance hubs, Company P&L) - deactivated per explicit request without deleting any
// of the underlying screens/models/services, so flipping this back to true re-enables
// everything exactly as it was. Deliberately does NOT touch Invoices, Vendor Bills, or
// Expenses - those are core day-to-day operational features (Back Office invoicing,
// employee/vendor expense submission) that predate this module and aren't part of it.
const bool financeModuleEnabled = false;

// ---------------- DASHBOARD SCREEN (Sidebar Layout) ----------------
class DashboardScreen extends StatefulWidget {
  final AppUser currentUser;
  const DashboardScreen({super.key, required this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _loadingData = true;
  StreamSubscription<List<WorkOrder>>? _workOrdersSub;
  StreamSubscription<List<InventoryItem>>? _inventoryItemsSub;

  @override
  void initState() {
    super.initState();
    _loadRealData();
    // Runs for the whole logged-in session regardless of which nav tab is open - not just
    // when someone happens to be looking at the Gmail Sync screen.
    if (Permissions(widget.currentUser).canUseGmailSync)
      GmailAutoSyncManager.ensureStarted();
    // One-time, guarded by a Firestore marker doc so it only ever runs once across the
    // app's lifetime (not once per login) - moves photos off the legacy flat
    // `workOrderPhotos` collection into the new per-work-order subcollections. Best-effort:
    // this is internal cleanup, not something the user is waiting on, so a failure here
    // (e.g. a permission hiccup) must never surface as an uncaught error - it'll just retry
    // on the next login since the marker doc only gets set after a full success.
    PhotoRepo.migrateLegacyWorkOrderPhotosIfNeeded().catchError((e) {
      // ignore: avoid_print
      print('Photo migration skipped: $e');
    });
  }

  @override
  void dispose() {
    _workOrdersSub?.cancel();
    _inventoryItemsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRealData() async {
    // Work orders get their own independent try/catch and their own wait-for-first-snapshot
    // step, on purpose: this used to be the last thing set up after several other awaited
    // loads, inside one shared try block - so if any of those other loads failed for any
    // reason, work orders never even started loading. And because the loading spinner was
    // turned off unconditionally right after starting the stream (not after the first
    // snapshot actually arrived), a refresh could render an empty work orders list for a
    // moment before the real data caught up - or forever, if the stream ever errored out
    // silently (no onError handler existed before). Doing this first and waiting for either
    // real data, a stream error, or a timeout - whichever comes first - means the list a
    // user sees is never a flash of "no work orders" while data is still on its way in.
    final firstSnapshot = Completer<void>();
    _workOrdersSub = DataService.watchWorkOrders().listen(
      (liveOrders) {
        sampleWorkOrders
          ..clear()
          ..addAll(liveOrders);
        _resyncIdCounters();
        if (!firstSnapshot.isCompleted) firstSnapshot.complete();
        if (mounted) setState(() {});
      },
      onError: (e) {
        // Keep whatever's already in memory rather than wiping the list out on a transient
        // error - and don't let the spinner hang forever waiting for a snapshot that will
        // never come.
        if (!firstSnapshot.isCompleted) firstSnapshot.complete();
      },
    );

    // Also live-synced (not just loaded once) - two people adjusting stock on different
    // devices at the same time need to see each other's changes, not just their own stale
    // copy of the quantity from whenever the page first loaded.
    _inventoryItemsSub = DataService.watchInventoryItems().listen(
      (liveItems) {
        sampleInventoryItems
          ..clear()
          ..addAll(liveItems);
        _resyncIdCounters();
        if (mounted) setState(() {});
      },
      // Same reasoning as the work orders stream's onError above - without this, any
      // stream error (e.g. a transient permission/network hiccup) becomes an uncaught
      // exception instead of just leaving whatever's already in memory in place.
      onError: (e) {},
    );

    try {
      // Fire all the startup reads at once instead of waiting for each one before
      // starting the next - this is what makes the app feel slow to open, since
      // Firestore round-trips were adding up one after another instead of overlapping.
      final seedSitesFuture = DataService.seedSitesIfEmpty(sampleSites);
      final billsFuture = DataService.loadVendorBills();
      final sitesFuture = DataService.loadSites();
      final clientsFuture = DataService.loadClients();
      final notificationsFuture = DataService.loadNotificationsFor(
        widget.currentUser.username,
      );
      final expensesFuture = DataService.loadExpenses();
      final attendanceFuture = DataService.loadAttendance();
      final inventoryTxnsFuture = DataService.loadInventoryTransactions();
      final toolAssignmentsFuture = DataService.loadToolAssignments();
      final ledgerEntriesFuture = DataService.loadLedgerEntries();
      final invoicesFuture = DataService.loadInvoices();
      final leavesFuture = DataService.loadLeaves();
      final accountsFuture = DataService.loadAccounts();
      final journalEntriesFuture = DataService.loadJournalEntries();
      final customersFuture = DataService.loadCustomers();
      final customerReceiptsFuture = DataService.loadCustomerReceipts();
      final payrollProfilesFuture = DataService.loadPayrollProfiles();
      final workingSchedulesFuture = DataService.loadWorkingSchedules();
      final payrollSettingsFuture = DataService.loadPayrollSettings();
      final salaryHistoryFuture = DataService.loadSalaryHistory();
      final payrollPeriodsFuture = DataService.loadPayrollPeriods();
      final payrollRecordsFuture = DataService.loadPayrollRecords();
      final holidaysFuture = DataService.loadHolidays();
      final payrollAuditLogFuture = DataService.loadPayrollAuditLog();

      await seedSitesFuture;
      final loadedBills = await billsFuture;
      final loadedSites = await sitesFuture;
      final loadedClients = await clientsFuture;
      final loadedNotifications = await notificationsFuture;
      final loadedExpenses = await expensesFuture;
      final loadedAttendance = await attendanceFuture;
      final loadedInventoryTxns = await inventoryTxnsFuture;
      final loadedToolAssignments = await toolAssignmentsFuture;
      final loadedLedgerEntries = await ledgerEntriesFuture;
      final loadedInvoices = await invoicesFuture;
      final loadedLeaves = await leavesFuture;
      final loadedAccounts = await accountsFuture;
      final loadedJournalEntries = await journalEntriesFuture;
      final loadedCustomers = await customersFuture;
      final loadedCustomerReceipts = await customerReceiptsFuture;
      final loadedPayrollProfiles = await payrollProfilesFuture;
      final loadedWorkingSchedules = await workingSchedulesFuture;
      final loadedPayrollSettings = await payrollSettingsFuture;
      final loadedSalaryHistory = await salaryHistoryFuture;
      final loadedPayrollPeriods = await payrollPeriodsFuture;
      final loadedPayrollRecords = await payrollRecordsFuture;
      final loadedHolidays = await holidaysFuture;
      final loadedPayrollAuditLog = await payrollAuditLogFuture;
      sampleInvoices
        ..clear()
        ..addAll(loadedInvoices);
      sampleLeaves
        ..clear()
        ..addAll(loadedLeaves);
      sampleVendorBills
        ..clear()
        ..addAll(loadedBills);
      sampleSites
        ..clear()
        ..addAll(loadedSites);
      sampleClients
        ..clear()
        ..addAll(loadedClients);
      sampleNotifications
        ..clear()
        ..addAll(loadedNotifications);
      sampleExpenses
        ..clear()
        ..addAll(loadedExpenses);
      sampleAttendance
        ..clear()
        ..addAll(loadedAttendance);
      sampleInventoryTransactions
        ..clear()
        ..addAll(loadedInventoryTxns);
      sampleToolAssignments
        ..clear()
        ..addAll(loadedToolAssignments);
      sampleLedgerEntries
        ..clear()
        ..addAll(loadedLedgerEntries);
      sampleAccounts
        ..clear()
        ..addAll(loadedAccounts);
      sampleJournalEntries
        ..clear()
        ..addAll(loadedJournalEntries);
      sampleCustomers
        ..clear()
        ..addAll(loadedCustomers);
      sampleCustomerReceipts
        ..clear()
        ..addAll(loadedCustomerReceipts);
      samplePayrollProfiles
        ..clear()
        ..addAll(loadedPayrollProfiles);
      sampleWorkingSchedules
        ..clear()
        ..addAll(loadedWorkingSchedules);
      if (loadedPayrollSettings != null)
        samplePayrollSettings = loadedPayrollSettings;
      sampleSalaryHistory
        ..clear()
        ..addAll(loadedSalaryHistory);
      samplePayrollPeriods
        ..clear()
        ..addAll(loadedPayrollPeriods);
      samplePayrollRecords
        ..clear()
        ..addAll(loadedPayrollRecords);
      sampleHolidays
        ..clear()
        ..addAll(loadedHolidays);
      samplePayrollAuditLog
        ..clear()
        ..addAll(loadedPayrollAuditLog);
      _resyncIdCounters();
    } catch (e) {
      // If Firestore isn't reachable for some reason, fall back to whatever's already in memory
      // rather than blocking the whole app.
    }

    await firstSnapshot.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
    if (mounted) setState(() => _loadingData = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return Scaffold(
        backgroundColor: AESColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AESColors.primaryGreen),
              SizedBox(height: 16),
              Text(
                tr('Loading your data...'),
                style: TextStyle(color: AESColors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 800;
    final perms = Permissions(widget.currentUser);

    final List<_NavItem> navItems = [
      const _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
      if (perms.canViewAllWorkOrders ||
          perms.user.role == UserRole.employee ||
          perms.user.role == UserRole.vendor)
        const _NavItem(icon: Icons.assignment_outlined, label: 'Work Orders'),
      // Quotations are one-to-one with a work order (site, description, WO# all carried
      // over) - same visibility rule as Work Orders itself, not every non-employee/vendor
      // role. Finance's own quotation visibility comes from the separate Regional Finance
      // hub (reads sampleWorkOrders directly), which this doesn't affect.
      if (perms.canViewAllWorkOrders)
        const _NavItem(icon: Icons.receipt_long_outlined, label: 'Quotations'),
      if (perms.canViewReports)
        const _NavItem(icon: Icons.bar_chart_outlined, label: 'Reports'),
      if (perms.canManageInvoices)
        const _NavItem(icon: Icons.receipt_outlined, label: 'Invoices'),
      if (financeModuleEnabled && perms.canViewMultanFinance)
        const _NavItem(
          icon: Icons.account_balance_outlined,
          label: 'Multan Finance',
        ),
      if (financeModuleEnabled && perms.canViewFaisalabadFinance)
        const _NavItem(
          icon: Icons.account_balance_outlined,
          label: 'Faisalabad Finance',
        ),
      // Full 3-region comparison - specifically the accountant (Finance) and admin (CEO)
      // portals, not every role that can see the two regional Finance hubs above.
      if (financeModuleEnabled &&
          (perms.user.role == UserRole.finance ||
              perms.user.role == UserRole.ceo))
        const _NavItem(icon: Icons.trending_up_outlined, label: 'Company P&L'),
      if (perms.user.role == UserRole.vendor)
        const _NavItem(icon: Icons.request_page_outlined, label: 'My Bills'),
      if (perms.canViewVendorBills)
        const _NavItem(
          icon: Icons.request_page_outlined,
          label: 'Vendor Bills',
        ),
      if (perms.canSubmitExpense)
        const _NavItem(icon: Icons.payments_outlined, label: 'My Expenses'),
      if (perms.canViewAllPettyCash)
        const _NavItem(
          icon: Icons.fact_check_outlined,
          label: 'Expense Approvals',
        ),
      if (financeModuleEnabled && perms.canManageLedger)
        const _NavItem(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Ledger',
        ),
      if (financeModuleEnabled && perms.canManageAccounting)
        const _NavItem(
          icon: Icons.insights_outlined,
          label: 'Finance Dashboard',
        ),
      if (financeModuleEnabled && perms.canManageAccounting)
        const _NavItem(icon: Icons.people_alt_outlined, label: 'Customers'),
      if (financeModuleEnabled && perms.canManageAccounting)
        const _NavItem(
          icon: Icons.payments_outlined,
          label: 'Customer Receipts',
        ),
      if (financeModuleEnabled && perms.canManageAccounting)
        const _NavItem(
          icon: Icons.account_tree_outlined,
          label: 'Chart of Accounts',
        ),
      if (financeModuleEnabled && perms.canManageAccounting)
        const _NavItem(
          icon: Icons.menu_book_outlined,
          label: 'Journal Entries',
        ),
      if (financeModuleEnabled && perms.canManageAccounting)
        const _NavItem(
          icon: Icons.summarize_outlined,
          label: 'Accounting Reports',
        ),
      // Payroll is a separate module from Finance/Accounting (deliberately not gated by
      // financeModuleEnabled) - it consumes Attendance data but is its own admin surface with
      // its own permission (canManagePayroll), restricted to Finance/CEO/BDM-HRM-Admin.
      if (perms.canManagePayroll)
        const _NavItem(
          icon: Icons.insights_outlined,
          label: 'Payroll Dashboard',
        ),
      if (perms.canManagePayroll)
        const _NavItem(icon: Icons.badge_outlined, label: 'Employee Payroll'),
      if (perms.canManagePayroll)
        const _NavItem(
          icon: Icons.calculate_outlined,
          label: 'Process Payroll',
        ),
      if (perms.canManagePayroll)
        const _NavItem(icon: Icons.history_outlined, label: 'Payroll History'),
      if (perms.canManagePayroll)
        const _NavItem(
          icon: Icons.summarize_outlined,
          label: 'Payroll Reports',
        ),
      if (perms.canManagePayroll)
        const _NavItem(
          icon: Icons.fact_check_outlined,
          label: 'Payroll Audit Log',
        ),
      if (perms.canManagePayroll)
        const _NavItem(icon: Icons.tune_outlined, label: 'Payroll Settings'),
      if (perms.canViewOwnPayslips)
        const _NavItem(icon: Icons.receipt_long_outlined, label: 'Payslips'),
      if (perms.canCheckInOut || perms.canViewAttendanceReport)
        const _NavItem(icon: Icons.access_time_outlined, label: 'Attendance'),
      if (perms.canSubmitLeave || perms.canApproveLeave)
        const _NavItem(icon: Icons.event_busy_outlined, label: 'Leave'),
      if (perms.canManageSites)
        const _NavItem(
          icon: Icons.location_city_outlined,
          label: 'Manage Sites',
        ),
      if (perms.canManageSites)
        const _NavItem(
          icon: Icons.people_alt_outlined,
          label: 'Manage Clients',
        ),
      if (perms.canViewInventory)
        const _NavItem(icon: Icons.inventory_2_outlined, label: 'Inventory'),
      if (perms.canUseGmailSync)
        const _NavItem(icon: Icons.mail_outline, label: 'Gmail Sync'),
      if (perms.canUseAiAssistant)
        const _NavItem(icon: Icons.smart_toy_outlined, label: 'AI Assistant'),
      if (perms.canManageEmployees)
        const _NavItem(icon: Icons.person_add_outlined, label: 'Add Employee'),
      const _NavItem(icon: Icons.language_outlined, label: 'Language'),
    ];

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, _, __) {
        return PopScope(
          // Sidebar tab switches (Work Orders, Inventory, etc.) are internal state changes on
          // this one screen, not separate pushed routes - so without this, a back gesture/
          // browser-back press while on any tab other than the Dashboard home tab had nothing
          // of its own to pop and fell straight through to whatever's outside the app (the
          // browser's prior page on web, or effectively the login screen's position in the
          // stack on mobile). This makes back correctly return to the Dashboard home tab first,
          // and only actually leaves/exits once already there - the behavior every other app
          // gives for free via real nested routes.
          canPop: _selectedIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            setState(() => _selectedIndex = 0);
          },
          child: Scaffold(
            backgroundColor: AESColors.background,
            // On mobile the nav lives in a slide-out Drawer instead of a permanent icon rail -
            // a persistent 76px-wide strip of 15+ unlabeled icons was eating a fifth of a phone
            // screen and forcing a second internal scroll just to reach the bottom items.
            drawer: isWide
                ? null
                : Drawer(
                    backgroundColor: AESColors.nearBlack,
                    width: 280,
                    child: SafeArea(
                      child: _buildSidebarColumn(
                        navItems,
                        expanded: true,
                        closeDrawerOnSelect: true,
                      ),
                    ),
                  ),
            body: SafeArea(
              child: Row(
                children: [
                  if (isWide)
                    Container(
                      width: 240,
                      color: AESColors.nearBlack,
                      child: _buildSidebarColumn(
                        navItems,
                        expanded: true,
                        closeDrawerOnSelect: false,
                      ),
                    ),
                  // Main content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(
                          user: widget.currentUser,
                          showMenuButton: !isWide,
                        ),
                        Expanded(
                          child: animatedContentSwitcher(
                            contentKey: navItems[_selectedIndex].label,
                            child: _buildBody(navItems, perms),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Shared between the permanent desktop rail and the mobile Drawer so both stay in sync -
  // closeDrawerOnSelect pops the Drawer after a selection/logout since it's a temporary
  // overlay on mobile, not a fixture of the layout the way the desktop rail is.
  Widget _buildSidebarColumn(
    List<_NavItem> navItems, {
    required bool expanded,
    required bool closeDrawerOnSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.settings,
                      color: AESColors.primaryGreen,
                      size: 22,
                    ),
                  ),
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'AES Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Drawer-only account card - the compact mobile top bar drops the role/region text
        // to save space, so it needs to live somewhere the user can still find it.
        if (closeDrawerOnSelect) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AESColors.brightGreen.withValues(
                      alpha: 0.25,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.currentUser.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.currentUser.role.label} · ${widget.currentUser.region == 'All' ? tr('All Regions') : widget.currentUser.region}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < navItems.length; i++)
                  _SidebarTile(
                    item: navItems[i],
                    selected: _selectedIndex == i,
                    expanded: expanded,
                    onTap: () {
                      setState(() => _selectedIndex = i);
                      if (closeDrawerOnSelect) Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ),
        _SidebarTile(
          item: const _NavItem(icon: Icons.logout, label: 'Logout'),
          selected: false,
          expanded: expanded,
          onTap: () async {
            if (closeDrawerOnSelect) Navigator.pop(context);
            LocalNotificationService.stop();
            await AuthService.signOut();
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBody(List<_NavItem> navItems, Permissions perms) {
    final selectedLabel = navItems[_selectedIndex].label;
    switch (selectedLabel) {
      case 'Work Orders':
        return WorkOrdersScreen(currentUser: widget.currentUser, perms: perms);
      case 'Quotations':
        return QuotationsListScreen(
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Reports':
        return ReportsScreen(currentUser: widget.currentUser, perms: perms);
      case 'Invoices':
        return InvoicesListScreen(
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Multan Finance':
        return RegionalFinanceScreen(
          region: 'Multan',
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Faisalabad Finance':
        return RegionalFinanceScreen(
          region: 'Faisalabad',
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Company P&L':
        return const CompanyPnlScreen();
      case 'Add Employee':
        return const AddEmployeeScreen();
      case 'My Bills':
        return VendorMyBillsScreen(currentUser: widget.currentUser);
      case 'Vendor Bills':
        return VendorBillsScreen(currentUser: widget.currentUser);
      case 'My Expenses':
        return MyExpensesScreen(currentUser: widget.currentUser);
      case 'Expense Approvals':
        return ExpensesApprovalScreen(
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Ledger':
        return LedgerScreen(currentUser: widget.currentUser, perms: perms);
      case 'Finance Dashboard':
        return FinanceDashboardScreen(
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Customers':
        return CustomersScreen(currentUser: widget.currentUser, perms: perms);
      case 'Customer Receipts':
        return CustomerReceiptsListScreen(
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Chart of Accounts':
        return ChartOfAccountsScreen(
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Journal Entries':
        return JournalEntriesScreen(currentUser: widget.currentUser);
      case 'Accounting Reports':
        return const AccountingReportsScreen();
      case 'Payroll Dashboard':
        return const PayrollDashboardScreen();
      case 'Employee Payroll':
        return EmployeePayrollScreen(currentUser: widget.currentUser);
      case 'Process Payroll':
        return ProcessPayrollScreen(
          currentUser: widget.currentUser,
          perms: perms,
        );
      case 'Payroll History':
        return PayrollHistoryScreen(currentUser: widget.currentUser);
      case 'Payroll Reports':
        return const PayrollReportsScreen();
      case 'Payroll Audit Log':
        return const PayrollAuditLogScreen();
      case 'Payroll Settings':
        return PayrollSettingsScreen(currentUser: widget.currentUser);
      case 'Payslips':
        return PayslipsScreen(currentUser: widget.currentUser, perms: perms);
      case 'Attendance':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (perms.canCheckInOut) ...[
                MyAttendanceScreen(currentUser: widget.currentUser),
                if (perms.canViewAttendanceReport) const SizedBox(height: 32),
              ],
              if (perms.canViewAttendanceReport)
                AttendanceReportScreen(
                  currentUser: widget.currentUser,
                  perms: perms,
                ),
            ],
          ),
        );
      case 'Leave':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (perms.canSubmitLeave) ...[
                MyLeaveScreen(currentUser: widget.currentUser),
                if (perms.canApproveLeave) const SizedBox(height: 32),
              ],
              if (perms.canApproveLeave)
                LeaveApprovalScreen(currentUser: widget.currentUser),
            ],
          ),
        );
      case 'Manage Sites':
        return ManageSitesScreen(currentUser: widget.currentUser, perms: perms);
      case 'Manage Clients':
        return const ManageClientsScreen();
      case 'Inventory':
        return InventoryScreen(currentUser: widget.currentUser, perms: perms);
      case 'Gmail Sync':
        return const GmailSyncScreen();
      case 'AI Assistant':
        return AiAssistantScreen(currentUser: widget.currentUser);
      case 'Language':
        return LanguageScreen(currentUser: widget.currentUser);
      case 'Dashboard':
      default:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _DashboardContent(user: widget.currentUser, perms: perms),
        );
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _SidebarTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: PressableScale(
        onTap: onTap,
        scaleDown: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? AESColors.primaryGreen.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: Icon(
                        item.icon,
                        color: selected
                            ? AESColors.brightGreen
                            : Colors.white70,
                        size: 22,
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 14,
                          ),
                          child: Text(tr(item.label)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  final AppUser user;
  final bool showMenuButton;
  const _TopBar({required this.user, this.showMenuButton = false});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  // This search box previously had a hint text and nothing else - no controller, no
  // onChanged, no results - typing into it did literally nothing. This wires it up for
  // real: matches work orders by ID, site name, or description (scoped to the user's
  // region like every other list in the app) and shows results in a floating dropdown that
  // doesn't push the rest of the page layout around.
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _searchLayerLink = LayerLink();
  OverlayEntry? _searchOverlay;
  String _query = '';

  @override
  void dispose() {
    _removeSearchOverlay();
    _searchController.dispose();
    super.dispose();
  }

  List<WorkOrder> get _searchResults {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final perms = Permissions(widget.user);
    var scoped = perms.seesAllRegions
        ? sampleWorkOrders
        : sampleWorkOrders
              .where((w) => w.region == widget.user.region)
              .toList();
    // Same visibility rule as WorkOrdersScreen - an employee/vendor only ever searches their
    // own assigned work orders, and roles with no reason to see work orders at all (Finance,
    // Store Manager, Procurement, Office Staff) get no results, so this box can't be used to
    // route around the nav item being hidden for them.
    if (widget.user.role == UserRole.employee) {
      scoped = scoped
          .where((w) => w.assignedEmployeeUsername == widget.user.username)
          .toList();
    } else if (widget.user.role == UserRole.vendor) {
      scoped = scoped
          .where((w) => w.assignedVendorUsername == widget.user.username)
          .toList();
    } else if (!perms.canViewAllWorkOrders) {
      scoped = [];
    }
    return scoped
        .where(
          (w) =>
              w.id.toLowerCase().contains(q) ||
              w.siteName.toLowerCase().contains(q) ||
              w.description.toLowerCase().contains(q),
        )
        .take(8)
        .toList();
  }

  void _updateSearch(String value) {
    setState(() => _query = value);
    _removeSearchOverlay();
    if (_query.trim().isNotEmpty) _showSearchOverlay();
  }

  void _showSearchOverlay() {
    final results = _searchResults;
    _searchOverlay = OverlayEntry(
      // Clamped to the actual screen width (minus a small margin) rather than a flat 420 -
      // the search field itself already shrinks below 420 on a phone-width screen
      // (Container(constraints: BoxConstraints(maxWidth: 420)) above), but this dropdown is
      // positioned via CompositedTransformFollower from the field's top-left corner, so a
      // fixed 420 here would extend past the right edge of a narrow screen regardless of how
      // narrow the field itself actually rendered.
      builder: (context) => Positioned(
        width: min(420.0, MediaQuery.of(context).size.width - 24),
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 46),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: results.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      tr('No matching work orders'),
                      style: TextStyle(color: AESColors.grey, fontSize: 13),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: results
                        .map(
                          (w) => InkWell(
                            onTap: () => _openWorkOrderFromSearch(w),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          w.siteName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AESColors.darkGrey,
                                          ),
                                        ),
                                        Text(
                                          'WO #${w.id} · ${w.region}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AESColors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _StatusBadge(status: w.status),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_searchOverlay!);
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  void _openWorkOrderFromSearch(WorkOrder wo) {
    _removeSearchOverlay();
    _searchController.clear();
    setState(() => _query = '');
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkOrderDetailScreen(
          workOrder: wo,
          perms: Permissions(widget.user),
        ),
      ),
    );
  }

  void _openNotifications() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final myNotifications = sampleNotifications
                .where((n) => n.recipientUsername == widget.user.username)
                .toList()
                .reversed
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Notifications'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AESColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: myNotifications.isEmpty
                            ? Center(
                                child: Text(
                                  tr('No notifications yet'),
                                  style: TextStyle(color: AESColors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: myNotifications.length,
                                itemBuilder: (context, i) {
                                  final n = myNotifications[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: n.read
                                          ? AESColors.lightGrey
                                          : AESColors.lightGreen,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () async {
                                        if (!n.read) {
                                          n.read = true;
                                          setSheetState(() {});
                                          setState(() {});
                                          await DataService.markNotificationRead(
                                            n.id,
                                          );
                                        }
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (!n.read)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  margin: const EdgeInsets.only(
                                                    right: 8,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: AESColors
                                                            .primaryGreen,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  n.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: AESColors.darkGrey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            n.message,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AESColors.darkGrey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            n.timestamp,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AESColors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = sampleNotifications
        .where((n) => n.recipientUsername == widget.user.username && !n.read)
        .length;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: widget.showMenuButton ? 12 : 24,
        vertical: 12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Below this width there's no room for the role/region text alongside the search
          // field, bell, and avatar without everything getting cramped or clipped - drop it
          // here since it's already shown in the Drawer's account card on mobile.
          final compact = constraints.maxWidth < 480;
          return Row(
            children: [
              if (widget.showMenuButton)
                IconButton(
                  icon: const Icon(Icons.menu, color: AESColors.darkGrey),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              Expanded(
                child: CompositedTransformTarget(
                  link: _searchLayerLink,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AESColors.lightGrey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: AESColors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _updateSearch,
                            decoration: InputDecoration(
                              hintText: compact
                                  ? tr('Search...')
                                  : tr('Search work orders, employees...'),
                              hintStyle: const TextStyle(
                                color: AESColors.grey,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _updateSearch('');
                            },
                            child: const Icon(
                              Icons.close,
                              color: AESColors.grey,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PressableScale(
                onTap: _openNotifications,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none,
                        color: AESColors.darkGrey,
                      ),
                      onPressed: _openNotifications,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.6, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.user.role.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AESColors.darkGrey,
                      ),
                    ),
                    Text(
                      widget.user.region == 'All'
                          ? tr('All Regions')
                          : widget.user.region,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AESColors.grey,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 18,
                backgroundColor: AESColors.lightGreen,
                child: Icon(
                  Icons.person,
                  color: AESColors.primaryGreen,
                  size: 20,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final AppUser user;
  final Permissions perms;
  const _DashboardContent({required this.user, required this.perms});

  @override
  Widget build(BuildContext context) {
    // Region stat data - Employees/Vendors see only work orders assigned to them; everyone else sees the full region count
    int countFor(String region) {
      if (user.role == UserRole.employee) {
        return sampleWorkOrders
            .where(
              (w) =>
                  w.region == region &&
                  w.assignedEmployeeUsername == user.username,
            )
            .length;
      }
      if (user.role == UserRole.vendor) {
        return sampleWorkOrders
            .where(
              (w) =>
                  w.region == region &&
                  w.assignedVendorUsername == user.username,
            )
            .length;
      }
      return sampleWorkOrders.where((w) => w.region == region).length;
    }

    final allStats = [
      _StatCard(
        title: 'Multan',
        value: countFor('Multan').toString(),
        icon: Icons.location_on_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkOrdersScreen(
              currentUser: user,
              perms: perms,
              initialRegionFilter: 'Multan',
            ),
          ),
        ),
      ),
      _StatCard(
        title: 'Lahore',
        value: countFor('Lahore').toString(),
        icon: Icons.location_on_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkOrdersScreen(
              currentUser: user,
              perms: perms,
              initialRegionFilter: 'Lahore',
            ),
          ),
        ),
      ),
      _StatCard(
        title: 'Faisalabad',
        value: countFor('Faisalabad').toString(),
        icon: Icons.location_on_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkOrdersScreen(
              currentUser: user,
              perms: perms,
              initialRegionFilter: 'Faisalabad',
            ),
          ),
        ),
      ),
    ];
    // Roles with no operational reason to see work orders at all (Finance, Store Manager,
    // Procurement, Office Staff) shouldn't see per-region work order counts either - showing
    // "0" tiles that don't lead anywhere would just be confusing residue, so these are
    // hidden entirely rather than shown empty.
    final canSeeWorkOrderStats =
        perms.canViewAllWorkOrders ||
        user.role == UserRole.employee ||
        user.role == UserRole.vendor;
    final visibleStats = !canSeeWorkOrderStats
        ? <_StatCard>[]
        : (perms.seesAllRegions
              ? allStats
              : allStats.where((s) => s.title == user.region).toList());

    // Same visibility rules as the stat cards above, reused so the charts below
    // show exactly the work orders this user is allowed to see.
    List<WorkOrder> visibleOrders = perms.seesAllRegions
        ? sampleWorkOrders
        : sampleWorkOrders.where((w) => w.region == user.region).toList();
    if (user.role == UserRole.employee) {
      visibleOrders = visibleOrders
          .where((w) => w.assignedEmployeeUsername == user.username)
          .toList();
    }
    if (user.role == UserRole.vendor) {
      visibleOrders = visibleOrders
          .where((w) => w.assignedVendorUsername == user.username)
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Dashboard'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AESColors.darkGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          perms.seesAllRegions
              ? tr('Overview of all regional work orders')
              : 'Overview of your work orders — ${user.region}',
          style: const TextStyle(color: AESColors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final staggered = [
              for (int i = 0; i < visibleStats.length; i++)
                FadeSlideIn(index: i, child: visibleStats[i]),
            ];
            if (isWide) {
              return Row(
                children: staggered
                    .map(
                      (s) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: s,
                        ),
                      ),
                    )
                    .toList(),
              );
            }
            return Column(
              children: staggered
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: s,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        // Charts show company-wide analytics, which isn't meaningful for Employee/Vendor
        // accounts that only ever see their own small slice of work orders anyway.
        if (perms.canViewReports) ...[
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final statusChart = _StatusBarChartCard(orders: visibleOrders);
              final regionChart = _RegionPieChartCard(orders: visibleOrders);
              final slaChart = _SlaChartCard(orders: visibleOrders);
              final donutRow = isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: regionChart),
                        const SizedBox(width: 16),
                        Expanded(child: slaChart),
                      ],
                    )
                  : Column(
                      children: [
                        regionChart,
                        const SizedBox(height: 16),
                        slaChart,
                      ],
                    );
              return Column(
                children: [statusChart, const SizedBox(height: 16), donutRow],
              );
            },
          ),
        ],
        const SizedBox(height: 32),
        Text(
          tr('Modules'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AESColors.darkGreen,
          ),
        ),
        const SizedBox(height: 14),
        ...() {
          final moduleRows = [
            if (perms.canViewAllWorkOrders ||
                user.role == UserRole.employee ||
                user.role == UserRole.vendor)
              _ModuleRow(
                icon: Icons.assignment_outlined,
                title: tr('Work Orders'),
                subtitle: perms.canViewAllWorkOrders
                    ? tr('Track and manage all work orders')
                    : 'Fill in your assigned work orders',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          WorkOrdersScreen(currentUser: user, perms: perms),
                    ),
                  );
                },
              ),
            if (perms.canViewReports)
              _ModuleRow(
                icon: Icons.bar_chart_outlined,
                title: tr('Reports'),
                subtitle: tr('Full work order sheet, exportable to Excel'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReportsScreen(currentUser: user, perms: perms),
                    ),
                  );
                },
              ),
            _ModuleRow(
              icon: Icons.language_outlined,
              title: tr('English / Urdu'),
              subtitle: tr('Switch app language'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LanguageScreen(currentUser: user),
                  ),
                );
              },
            ),
          ];
          return [
            for (int i = 0; i < moduleRows.length; i++)
              FadeSlideIn(index: i, child: moduleRows[i]),
          ];
        }(),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AESColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AESColors.primaryGreen, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AESColors.darkGreen,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AESColors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Categorical colors for dashboard charts - anchored on the AES brand green, with the
// rest chosen and validated (lightness band, chroma floor, CVD separation, normal-vision
// floor) so every status/region stays visually distinct, not just "different shades of green".
const Map<WorkOrderStatus, Color> _statusChartColors = {
  WorkOrderStatus.pending: Color(0xFF2A78D6),
  WorkOrderStatus.quotationReady: Color(0xFF1B7A3D),
  WorkOrderStatus.backOfficeReview: Color(0xFFE87BA4),
  WorkOrderStatus.managerApproval: Color(0xFFEDA100),
  WorkOrderStatus.approved: Color(0xFF1BAF7A),
  WorkOrderStatus.completed: Color(0xFFEB6834),
};

Widget _chartLegendDot(Color color, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AESColors.darkGrey),
      ),
    ],
  );
}

BoxDecoration _chartCardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);

class _StatusBarChartCard extends StatelessWidget {
  final List<WorkOrder> orders;
  const _StatusBarChartCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in WorkOrderStatus.values)
        s: orders.where((w) => w.status == s).length,
    };
    final maxCount = counts.values.fold<int>(0, (m, c) => c > m ? c : m);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Work Orders by Status'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AESColors.darkGreen,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxCount == 0 ? 1 : maxCount * 1.2,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AESColors.nearBlack,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final status = WorkOrderStatus.values[group.x];
                      return BarTooltipItem(
                        '${status.label}\n${rod.toY.toInt()}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < WorkOrderStatus.values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[WorkOrderStatus.values[i]]!.toDouble(),
                          color: _statusChartColors[WorkOrderStatus.values[i]],
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final s in WorkOrderStatus.values)
                _chartLegendDot(
                  _statusChartColors[s]!,
                  '${s.label} (${counts[s]})',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionPieChartCard extends StatelessWidget {
  final List<WorkOrder> orders;
  const _RegionPieChartCard({required this.orders});

  static const _regions = ['Multan', 'Lahore', 'Faisalabad'];
  static const _colors = [
    Color(0xFF2A78D6),
    Color(0xFF1B7A3D),
    Color(0xFFE87BA4),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final r in _regions) r: orders.where((w) => w.region == r).length,
    };
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Work Orders by Region'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AESColors.darkGreen,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: total == 0
                ? Center(
                    child: Text(
                      tr('No work orders yet'),
                      style: TextStyle(color: AESColors.grey, fontSize: 12),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      pieTouchData: PieTouchData(enabled: true),
                      sections: [
                        for (int i = 0; i < _regions.length; i++)
                          if (counts[_regions[i]]! > 0)
                            PieChartSectionData(
                              value: counts[_regions[i]]!.toDouble(),
                              color: _colors[i],
                              radius: 50,
                              title:
                                  '${(counts[_regions[i]]! / total * 100).round()}%',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _regions.length; i++)
                _chartLegendDot(
                  _colors[i],
                  '${_regions[i]} (${counts[_regions[i]]})',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlaChartCard extends StatelessWidget {
  final List<WorkOrder> orders;
  const _SlaChartCard({required this.orders});

  // Green/red is the clearest match for "met deadline / missed deadline", but that pair
  // reads as near-identical under protan colorblindness - so unlike the other charts,
  // this one never relies on color alone: every value ships with an icon and a label too.
  static const Color _metColor = AESColors.primaryGreen;
  static const Color _missedColor = Color(0xFFE34948);

  @override
  Widget build(BuildContext context) {
    final completed = orders
        .where((w) => w.status == WorkOrderStatus.completed)
        .toList();
    final tracked = completed.where((w) => w.metSla != null).toList();
    final met = tracked.where((w) => w.metSla == true).length;
    final missed = tracked.where((w) => w.metSla == false).length;
    final untracked = completed.length - tracked.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SLA Compliance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AESColors.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tracked.isEmpty
                ? 'No completed jobs with a tracked target date yet'
                : 'Based on ${tracked.length} completed job${tracked.length == 1 ? '' : 's'} with tracked times',
            style: const TextStyle(fontSize: 11, color: AESColors.grey),
          ),
          const SizedBox(height: 20),
          if (tracked.isEmpty)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  tr('Nothing to show yet'),
                  style: TextStyle(color: AESColors.grey, fontSize: 12),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  pieTouchData: PieTouchData(enabled: true),
                  sections: [
                    if (met > 0)
                      PieChartSectionData(
                        value: met.toDouble(),
                        color: _metColor,
                        radius: 40,
                        title: '$met',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (missed > 0)
                      PieChartSectionData(
                        value: missed.toDouble(),
                        color: _missedColor,
                        radius: 40,
                        title: '$missed',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _statusLegend(Icons.check_circle, _metColor, 'SLA ($met)'),
                _statusLegend(Icons.error, _missedColor, 'Non SLA ($missed)'),
              ],
            ),
          ],
          if (untracked > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$untracked completed job${untracked == 1 ? '' : 's'} without a tracked target date not shown',
              style: const TextStyle(fontSize: 10, color: AESColors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusLegend(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AESColors.darkGrey),
        ),
      ],
    );
  }
}
