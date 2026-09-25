part of '../main.dart';

// ---------------- FIRESTORE DATA SERVICE (Work Orders & Vendor Bills) ----------------
class DataService {
  static final _db = FirebaseFirestore.instance;

  // Loads every work order from Firestore. Returns an empty list if none exist yet.
  //
  // Photos are deliberately NOT attached here - work order list/board views never render
  // photos, only detail screens do, and those screens fetch their own work order's photos
  // on demand via PhotoRepo (loadWorkOrderPhotos/watchWorkOrderPhotos below). Attaching
  // every photo of every work order on every list load doesn't scale once orders start
  // holding tens or hundreds of photos each.
  static Future<List<WorkOrder>> loadWorkOrders() async {
    final snapshot = await _db.collection('workOrders').get();
    return snapshot.docs.map((doc) => WorkOrder.fromMap(doc.data())).toList();
  }

  // Live feed of every work order - fires immediately with the current data, then again
  // any time a doc is added/changed/removed (e.g. back office assigns a work order to an
  // employee). Used so an employee who's already logged in sees new assignments without
  // needing to refresh the page.
  static Stream<List<WorkOrder>> watchWorkOrders() {
    return _db.collection('workOrders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => WorkOrder.fromMap(doc.data())).toList();
    });
  }

  // Saves (creates or overwrites) a single work order - call this after any change.
  //
  // Photos are NOT embedded in this document - a few photos as base64 easily blow past
  // Firestore's 1 MiB-per-document limit (this happened in testing with just 2 photos).
  // Instead each photo lives in its own small doc in `workOrders/{id}/photos` (see
  // PhotoRepo), and saveWorkOrderPhotos() below reconciles that subcollection to match
  // whatever the caller currently has in memory.
  static Future<void> saveWorkOrder(WorkOrder wo) async {
    final map = wo.toMap()
      ..remove('employeePhotoUrls')
      ..remove('afterPhotoUrls');
    await _db.collection('workOrders').doc(wo.id).set(map);
  }

  // Call after editing wo.employeePhotoUrls/afterPhotoUrls locally to persist the change -
  // separate from saveWorkOrder so screens that don't touch photos don't pay for a photo
  // subcollection round-trip on every save.
  static Future<void> saveWorkOrderPhotos(
    String workOrderId,
    String kind,
    List<String> photos,
    String uploaderUsername,
  ) async {
    await PhotoRepo.replaceAll(
      parentCollection: 'workOrders',
      parentId: workOrderId,
      kind: kind,
      dataUrls: photos,
      uploaderUsername: uploaderUsername,
    );
  }

  static Future<List<String>> loadWorkOrderPhotos(
    String workOrderId,
    String kind,
  ) => PhotoRepo.loadDataUrls('workOrders', workOrderId, kind: kind);

  static Stream<List<String>> watchWorkOrderPhotos(
    String workOrderId,
    String kind,
  ) => PhotoRepo.watchDataUrls('workOrders', workOrderId, kind: kind);

  // Permanently removes a work order from Firestore. This cannot be undone.
  static Future<void> deleteWorkOrder(String id) async {
    await _db.collection('workOrders').doc(id).delete();
  }

  static Future<List<VendorBill>> loadVendorBills() async {
    final snapshot = await _db.collection('vendorBills').get();
    return snapshot.docs.map((doc) => VendorBill.fromMap(doc.data())).toList();
  }

  static Future<void> saveVendorBill(VendorBill bill) async {
    await _db.collection('vendorBills').doc(bill.id).set(bill.toMap());
  }

  static Future<void> deleteVendorBill(String id) async {
    await _db.collection('vendorBills').doc(id).delete();
  }

  static Future<List<ExpenseClaim>> loadExpenses() async {
    final snapshot = await _db.collection('expenses').get();
    return snapshot.docs
        .map((doc) => ExpenseClaim.fromMap(doc.data()))
        .toList();
  }

  static Future<void> saveExpense(ExpenseClaim expense) async {
    await _db.collection('expenses').doc(expense.id).set(expense.toMap());
  }

  static Future<void> deleteExpense(String id) async {
    await _db.collection('expenses').doc(id).delete();
  }

  static Future<void> saveExpensePhotos(
    String expenseId,
    List<String> photos,
    String uploaderUsername,
  ) => PhotoRepo.replaceAll(
    parentCollection: 'expenses',
    parentId: expenseId,
    dataUrls: photos,
    uploaderUsername: uploaderUsername,
  );

  static Future<List<String>> loadExpensePhotos(String expenseId) =>
      PhotoRepo.loadDataUrls('expenses', expenseId);

  static Future<void> saveVendorBillPhotos(
    String billId,
    List<String> photos,
    String uploaderUsername,
  ) => PhotoRepo.replaceAll(
    parentCollection: 'vendorBills',
    parentId: billId,
    dataUrls: photos,
    uploaderUsername: uploaderUsername,
  );

  static Future<List<String>> loadVendorBillPhotos(String billId) =>
      PhotoRepo.loadDataUrls('vendorBills', billId);

  static Future<List<AttendanceRecord>> loadAttendance() async {
    final snapshot = await _db.collection('attendance').get();
    return snapshot.docs
        .map((doc) => AttendanceRecord.fromMap(doc.data()))
        .toList();
  }

  static Future<void> saveAttendance(AttendanceRecord record) async {
    await _db.collection('attendance').doc(record.id).set(record.toMap());
  }

  static Future<List<InventoryItem>> loadInventoryItems() async {
    final snapshot = await _db.collection('inventoryItems').get();
    return snapshot.docs
        .map((doc) => InventoryItem.fromMap(doc.data()))
        .toList();
  }

  // Live feed of inventory items, same pattern as watchWorkOrders() - without this, two
  // people using the app on different devices at the same time each hold their own stale
  // in-memory copy of the stock count for the whole session, with no way to see the other
  // person's stock in/out until a full page reload.
  static Stream<List<InventoryItem>> watchInventoryItems() {
    return _db
        .collection('inventoryItems')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromMap(doc.data()))
              .toList(),
        );
  }

  static Future<void> saveInventoryItem(InventoryItem item) async {
    await _db.collection('inventoryItems').doc(item.id).set(item.toMap());
  }

  static Future<void> deleteInventoryItem(String id) async {
    await _db.collection('inventoryItems').doc(id).delete();
  }

  // Atomically adjusts a stock quantity by delta (positive for stock in, negative for stock
  // out) inside a Firestore transaction - this is what actually prevents two concurrent
  // stock-out operations on the same item from over-drawing it. A plain read-current-
  // quantity-then-write-new-quantity (what this replaces) can silently lose one of two
  // simultaneous changes, or let stock go negative, if two people use the app on different
  // devices at the same moment - the transaction reads the true current value and rejects
  // the change instead of corrupting it if there truly isn't enough stock left.
  static Future<void> adjustInventoryQuantity(
    String itemId,
    double delta,
  ) async {
    final ref = _db.collection('inventoryItems').doc(itemId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = (snapshot.data()?['quantity'] as num?)?.toDouble() ?? 0;
      final updated = current + delta;
      if (updated < 0) {
        throw Exception(
          'Not enough stock - only ${current.toStringAsFixed(0)} left',
        );
      }
      transaction.update(ref, {'quantity': updated});
    });
  }

  static Future<List<InventoryTransaction>> loadInventoryTransactions() async {
    final snapshot = await _db.collection('inventoryTransactions').get();
    return snapshot.docs
        .map((doc) => InventoryTransaction.fromMap(doc.data()))
        .toList();
  }

  static Future<void> saveInventoryTransaction(InventoryTransaction txn) async {
    await _db.collection('inventoryTransactions').doc(txn.id).set(txn.toMap());
  }

  static Future<List<ToolAssignment>> loadToolAssignments() async {
    final snapshot = await _db.collection('toolAssignments').get();
    return snapshot.docs
        .map((doc) => ToolAssignment.fromMap(doc.data()))
        .toList();
  }

  static Future<void> saveToolAssignment(ToolAssignment assignment) async {
    await _db
        .collection('toolAssignments')
        .doc(assignment.id)
        .set(assignment.toMap());
  }

  static Future<void> deleteToolAssignment(String id) async {
    await _db.collection('toolAssignments').doc(id).delete();
  }

  static Future<List<LedgerEntry>> loadLedgerEntries() async {
    final snapshot = await _db.collection('ledgerEntries').get();
    return snapshot.docs.map((doc) => LedgerEntry.fromMap(doc.data())).toList();
  }

  static Future<void> saveLedgerEntry(LedgerEntry entry) async {
    await _db.collection('ledgerEntries').doc(entry.id).set(entry.toMap());
  }

  static Future<void> deleteLedgerEntry(String id) async {
    await _db.collection('ledgerEntries').doc(id).delete();
  }

  // ---- Chart of Accounts / General Ledger ----
  static Future<List<Account>> loadAccounts() async {
    final snapshot = await _db.collection('accounts').get();
    return snapshot.docs.map((doc) => Account.fromMap(doc.data())).toList();
  }

  static Future<void> saveAccount(Account account) async {
    await _db.collection('accounts').doc(account.code).set(account.toMap());
  }

  // Only ever called after the caller has already verified the account has no journal
  // activity (see ChartOfAccountsScreen._deleteAccount) - accounts with transactions must be
  // deactivated, never deleted, so historical journal entries always resolve to a real account.
  static Future<void> deleteAccount(String code) async {
    await _db.collection('accounts').doc(code).delete();
  }

  static Future<List<JournalEntry>> loadJournalEntries() async {
    final snapshot = await _db.collection('journalEntries').get();
    return snapshot.docs
        .map((doc) => JournalEntry.fromMap(doc.data()))
        .toList();
  }

  // Journal entries are never edited or deleted once posted - correcting one means posting a
  // new reversing entry (see JournalEntriesScreen._reverseEntry). This save path is also used
  // for that one legitimate post-posting mutation: stamping reversedByEntryId back onto the
  // original entry once its reversal has been posted, which changes no financial figure on it.
  static Future<void> saveJournalEntry(JournalEntry entry) async {
    await _db.collection('journalEntries').doc(entry.id).set(entry.toMap());
  }

  // ---- Customers / Accounts Receivable ----
  static Future<List<Customer>> loadCustomers() async {
    final snapshot = await _db.collection('customers').get();
    return snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
  }

  static Future<void> saveCustomer(Customer customer) async {
    await _db.collection('customers').doc(customer.id).set(customer.toMap());
  }

  static Future<List<CustomerReceipt>> loadCustomerReceipts() async {
    final snapshot = await _db.collection('customerReceipts').get();
    return snapshot.docs
        .map((doc) => CustomerReceipt.fromMap(doc.data()))
        .toList();
  }

  // Receipts are effectively append-only like journal entries (the amount/journal entry never
  // changes after posting) - this save path is only ever used for the initial post and for
  // later edits to `allocations` (which invoices a payment covers), never the posted amount.
  static Future<void> saveCustomerReceipt(CustomerReceipt receipt) async {
    await _db
        .collection('customerReceipts')
        .doc(receipt.id)
        .set(receipt.toMap());
  }

  // ---- Payroll ----
  static Future<List<PayrollProfile>> loadPayrollProfiles() async {
    final snapshot = await _db.collection('payrollProfiles').get();
    return snapshot.docs
        .map((doc) => PayrollProfile.fromMap(doc.data()))
        .toList();
  }

  static Future<void> savePayrollProfile(PayrollProfile profile) async {
    await _db
        .collection('payrollProfiles')
        .doc(profile.username)
        .set(profile.toMap());
  }

  static Future<List<WorkingSchedule>> loadWorkingSchedules() async {
    final snapshot = await _db.collection('workingSchedules').get();
    return snapshot.docs
        .map((doc) => WorkingSchedule.fromMap(doc.data()))
        .toList();
  }

  static Future<void> saveWorkingSchedule(WorkingSchedule schedule) async {
    await _db
        .collection('workingSchedules')
        .doc(schedule.employeeType.name)
        .set(schedule.toMap());
  }

  // Singleton document ("global") - one shared payroll configuration for the whole company.
  static Future<PayrollSettings?> loadPayrollSettings() async {
    final doc = await _db.collection('payrollSettings').doc('global').get();
    if (!doc.exists) return null;
    return PayrollSettings.fromMap(doc.data()!);
  }

  static Future<void> savePayrollSettings(PayrollSettings settings) async {
    await _db.collection('payrollSettings').doc('global').set(settings.toMap());
  }

  static Future<List<SalaryHistoryEntry>> loadSalaryHistory() async {
    final snapshot = await _db.collection('salaryHistory').get();
    return snapshot.docs
        .map((doc) => SalaryHistoryEntry.fromMap(doc.data()))
        .toList();
  }

  static Future<void> saveSalaryHistoryEntry(SalaryHistoryEntry entry) async {
    await _db.collection('salaryHistory').doc(entry.id).set(entry.toMap());
  }

  static Future<List<PayrollPeriod>> loadPayrollPeriods() async {
    final snapshot = await _db.collection('payrollPeriods').get();
    return snapshot.docs
        .map((doc) => PayrollPeriod.fromMap(doc.data()))
        .toList();
  }

  static Future<void> savePayrollPeriod(PayrollPeriod period) async {
    await _db.collection('payrollPeriods').doc(period.id).set(period.toMap());
  }

  static Future<List<PayrollRecord>> loadPayrollRecords() async {
    final snapshot = await _db.collection('payrollRecords').get();
    return snapshot.docs
        .map((doc) => PayrollRecord.fromMap(doc.data()))
        .toList();
  }

  static Future<void> savePayrollRecord(PayrollRecord record) async {
    await _db.collection('payrollRecords').doc(record.id).set(record.toMap());
  }

  static Future<List<Holiday>> loadHolidays() async {
    final snapshot = await _db.collection('holidays').get();
    return snapshot.docs.map((doc) => Holiday.fromMap(doc.data())).toList();
  }

  static Future<void> saveHoliday(Holiday holiday) async {
    await _db.collection('holidays').doc(holiday.id).set(holiday.toMap());
  }

  static Future<void> deleteHoliday(String id) async {
    await _db.collection('holidays').doc(id).delete();
  }

  static Future<List<PayrollAuditEntry>> loadPayrollAuditLog() async {
    final snapshot = await _db.collection('payrollAuditLog').get();
    return snapshot.docs
        .map((doc) => PayrollAuditEntry.fromMap(doc.data()))
        .toList();
  }

  static Future<void> savePayrollAuditEntry(PayrollAuditEntry entry) async {
    await _db.collection('payrollAuditLog').doc(entry.id).set(entry.toMap());
  }

  static Future<List<SiteEntry>> loadSites() async {
    final snapshot = await _db.collection('sites').get();
    return snapshot.docs.map((doc) => SiteEntry.fromMap(doc.data())).toList();
  }

  static Future<void> saveSite(SiteEntry site) async {
    await _db.collection('sites').doc(site.id).set(site.toMap());
  }

  static Future<void> deleteSite(String id) async {
    await _db.collection('sites').doc(id).delete();
  }

  // Loads only the notifications meant for one specific person.
  static Future<List<AppNotification>> loadNotificationsFor(
    String username,
  ) async {
    final snapshot = await _db
        .collection('notifications')
        .where('recipientUsername', isEqualTo: username)
        .get();
    return snapshot.docs
        .map((doc) => AppNotification.fromMap(doc.data()))
        .toList();
  }

  static Future<void> saveNotification(AppNotification notification) async {
    await _db
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toMap());
  }

  static Future<void> markNotificationRead(String id) async {
    await _db.collection('notifications').doc(id).update({'read': true});
  }

  static Future<List<Invoice>> loadInvoices() async {
    final snapshot = await _db.collection('invoices').get();
    return snapshot.docs.map((doc) => Invoice.fromMap(doc.data())).toList();
  }

  static Future<void> saveInvoice(Invoice invoice) async {
    await _db.collection('invoices').doc(invoice.id).set(invoice.toMap());
  }

  static Future<List<LeaveRequest>> loadLeaves() async {
    final snapshot = await _db.collection('leaves').get();
    return snapshot.docs
        .map((doc) => LeaveRequest.fromMap(doc.data()))
        .toList();
  }

  static Future<void> saveLeave(LeaveRequest leave) async {
    await _db.collection('leaves').doc(leave.id).set(leave.toMap());
  }

  static Future<void> deleteLeave(String id) async {
    await _db.collection('leaves').doc(id).delete();
  }

  static Future<void> seedSitesIfEmpty(List<SiteEntry> currentSites) async {
    final existing = await _db.collection('sites').limit(1).get();
    if (existing.docs.isEmpty) {
      for (final site in currentSites) {
        await saveSite(site);
      }
    }
  }

  static Future<List<ClientEntry>> loadClients() async {
    final snapshot = await _db.collection('clients').get();
    return snapshot.docs.map((doc) => ClientEntry.fromMap(doc.data())).toList();
  }

  static Future<void> saveClient(ClientEntry client) async {
    await _db.collection('clients').doc(client.id).set(client.toMap());
  }

  static Future<void> deleteClient(String id) async {
    await _db.collection('clients').doc(id).delete();
  }

  // One session document per past conversation, under a subcollection keyed by username
  // (same per-person scoping as notifications/expenses elsewhere) - lets someone keep
  // multiple named chats around and pick any of them back up, rather than one single
  // ever-growing conversation with no way to start fresh.
  static Future<List<Map<String, dynamic>>> loadAiChatSessions(
    String username,
  ) async {
    final snapshot = await _db
        .collection('aiChats')
        .doc(username)
        .collection('sessions')
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<void> saveAiChatSession(
    String username,
    String sessionId, {
    required String title,
    required List<Map<String, dynamic>> messages,
  }) async {
    await _db
        .collection('aiChats')
        .doc(username)
        .collection('sessions')
        .doc(sessionId)
        .set({
          'title': title,
          'messages': messages,
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  static Future<void> deleteAiChatSession(
    String username,
    String sessionId,
  ) async {
    await _db
        .collection('aiChats')
        .doc(username)
        .collection('sessions')
        .doc(sessionId)
        .delete();
  }
}
