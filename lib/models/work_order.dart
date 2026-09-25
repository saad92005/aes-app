part of '../main.dart';

// ---------------- WORK ORDERS ----------------
enum WorkOrderStatus { pending, quotationReady, backOfficeReview, managerApproval, approved, completed }

extension WorkOrderStatusLabel on WorkOrderStatus {
  String get label {
    switch (this) {
      case WorkOrderStatus.pending:
        return 'Pending';
      case WorkOrderStatus.quotationReady:
        return 'Quotation Ready';
      case WorkOrderStatus.backOfficeReview:
        return 'Back Office Review';
      case WorkOrderStatus.managerApproval:
        return 'Manager Approval';
      case WorkOrderStatus.approved:
        return 'Approved';
      case WorkOrderStatus.completed:
        return 'Completed';
    }
  }

  Color get color {
    switch (this) {
      case WorkOrderStatus.pending:
        return const Color(0xFF9A9A9A);
      case WorkOrderStatus.quotationReady:
        return const Color(0xFF2196F3);
      case WorkOrderStatus.backOfficeReview:
        return const Color(0xFFFF9800);
      case WorkOrderStatus.managerApproval:
        return const Color(0xFF9C27B0);
      case WorkOrderStatus.approved:
        return AESColors.primaryGreen;
      case WorkOrderStatus.completed:
        return const Color(0xFF14562C);
    }
  }
}

// Quotations get their own independent ID sequence: AES/<REGION_CODE>/<number>
int _quotationCounter = 1750;
const Map<String, String> _regionCode = {'Multan': 'MUL', 'Lahore': 'LHR', 'Faisalabad': 'FSD'};
String _nextQuotationId(String region) {
  final code = _regionCode[region] ?? 'HQ';
  return 'AES/$code/${_quotationCounter++}';
}

// Static vendor details (your company info, shown on every quotation)
const String vendorName = 'Al-Areesh Engineering Solutions (Pvt) Ltd';
const String vendorNTN = '4943191-4';
const String vendorSTRN = '32-7787-6217-416';
const String vendorAddress = '751 Ghaznavi Block, Street No 35, Sector F, Bahria Town, Lahore';

enum TaxType { none, percentage, fixed }

class QuotationLineItem {
  String description;
  String unit;
  double qty;
  double rate;
  String cmepStatus; // 'CMEP BOQ' or 'Non CMEP'
  TaxType taxType;
  double taxValue; // percentage number (e.g. 17) or fixed amount, depending on taxType
  // What this line actually costs the company (materials/labor) - internal-only, never
  // included in anything the client sees (the emailed/WhatsApp'd quotation, the PDF-style
  // in-app preview shown to vendors/employees). Only shown to Back Office/CEO/Finance/Head
  // of Operations so the internal profit margin stays internal.
  double internalCost;
  // "AES Remarks" column on the real quotation format - a per-line note (e.g. "Ok." or an
  // explanation when a rate doesn't match CMEP's list price). Unlike internalCost, this IS
  // shown to the client - it's part of the quotation itself, not internal-only.
  String remarks;

  QuotationLineItem({
    required this.description,
    this.unit = 'Job',
    this.qty = 1,
    this.rate = 0,
    this.cmepStatus = 'Non CMEP',
    this.taxType = TaxType.none,
    this.taxValue = 0,
    this.internalCost = 0,
    this.remarks = '',
  });

  double get baseAmount => qty * rate;

  double get taxAmount {
    switch (taxType) {
      case TaxType.percentage:
        return baseAmount * (taxValue / 100);
      case TaxType.fixed:
        return taxValue;
      case TaxType.none:
        return 0;
    }
  }

  double get amount => baseAmount + taxAmount;

  Map<String, dynamic> toMap() => {
        'description': description,
        'unit': unit,
        'qty': qty,
        'rate': rate,
        'cmepStatus': cmepStatus,
        'taxType': taxType.name,
        'taxValue': taxValue,
        'internalCost': internalCost,
        'remarks': remarks,
      };

  static QuotationLineItem fromMap(Map<String, dynamic> m) => QuotationLineItem(
        description: m['description'] ?? '',
        unit: m['unit'] ?? 'Job',
        qty: (m['qty'] ?? 1).toDouble(),
        rate: (m['rate'] ?? 0).toDouble(),
        cmepStatus: m['cmepStatus'] ?? 'Non CMEP',
        taxType: TaxType.values.firstWhere((t) => t.name == m['taxType'], orElse: () => TaxType.none),
        taxValue: (m['taxValue'] ?? 0).toDouble(),
        internalCost: (m['internalCost'] ?? 0).toDouble(),
        remarks: m['remarks'] ?? '',
      );
}

class QuotationData {
  final String id;
  final String date;
  String clientName;
  String clientCompany;
  String siteName;
  String descriptionOfWorkOrder;
  List<QuotationLineItem> lineItems;
  List<String> beforePhotoUrls;
  String notes;
  // Set only once the quotation is actually emailed successfully (sendQuotationViaEmail) -
  // drives which calendar month/client an invoice can bundle this quotation into. Null means
  // never sent (or only shared via WhatsApp/manual compose, neither of which confirm delivery
  // the way a successful Gmail API send does).
  String? sentAt;
  String? sentToEmail;
  String? sentCc;

  QuotationData({
    String? id,
    String? date,
    required this.clientName,
    required this.clientCompany,
    required this.siteName,
    required this.descriptionOfWorkOrder,
    required this.lineItems,
    required String region,
    List<String>? beforePhotoUrls,
    this.notes = '',
    this.sentAt,
    this.sentToEmail,
    this.sentCc,
  })  : id = id ?? _nextQuotationId(region),
        date = date ?? '${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year.toString().substring(2)}',
        beforePhotoUrls = beforePhotoUrls ?? [];

  double get subTotal => lineItems.fold(0, (sum, i) => sum + i.baseAmount);
  double get totalTax => lineItems.fold(0, (sum, i) => sum + i.taxAmount);
  double get quoteTotal => subTotal + totalTax;

  // Internal-only figures - never surfaced anywhere the client sees (email/WhatsApp text).
  double get totalInternalCost => lineItems.fold(0, (sum, i) => sum + i.internalCost);
  double get profitMargin => quoteTotal - totalInternalCost;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'clientName': clientName,
        'clientCompany': clientCompany,
        'siteName': siteName,
        'descriptionOfWorkOrder': descriptionOfWorkOrder,
        'lineItems': lineItems.map((i) => i.toMap()).toList(),
        'beforePhotoUrls': beforePhotoUrls,
        'notes': notes,
        'sentAt': sentAt,
        'sentToEmail': sentToEmail,
        'sentCc': sentCc,
      };

  static QuotationData fromMap(Map<String, dynamic> m) => QuotationData(
        id: m['id'],
        date: m['date'],
        clientName: m['clientName'] ?? '',
        clientCompany: m['clientCompany'] ?? '',
        siteName: m['siteName'] ?? '',
        descriptionOfWorkOrder: m['descriptionOfWorkOrder'] ?? '',
        lineItems: (m['lineItems'] as List? ?? []).map((i) => QuotationLineItem.fromMap(Map<String, dynamic>.from(i))).toList(),
        region: '',
        beforePhotoUrls: List<String>.from(m['beforePhotoUrls'] ?? []),
        notes: m['notes'] ?? '',
        sentAt: m['sentAt'],
        sentToEmail: m['sentToEmail'],
        sentCc: m['sentCc'],
      );
}

class WorkOrder {
  final String id;
  // Mutable (not final) - Back Office can edit these via WorkOrderDetailScreen's Edit action
  // (see Permissions.canEditWorkOrder). id and reportedDate stay final: id is the document's
  // stable identity, and reportedDate is a historical fact (when the client actually reported
  // it), not something that should be editable after the fact.
  String siteName;
  String address;
  String region;
  int priority;
  String description;
  String targetDate;
  final String reportedDate;
  WorkOrderStatus status;
  QuotationData? quotation;
  List<String> afterPhotoUrls;
  String? rejectionNote;
  String? rejectedByRole;
  String? assignedEmployeeUsername;
  String? employeeNotes;
  List<String> employeePhotoUrls;
  String? assignedVendorUsername;
  String? workType;
  // ISO 8601 - the real deadline picked at creation time, distinct from the display-only
  // `targetDate` string. Null on work orders created before this field existed.
  String? targetDateIso;
  // ISO 8601 - the real report date, distinct from the display-only `reportedDate` string.
  // Null on work orders created before this field existed (see reportedDateTime, which falls
  // back to parsing the display string for those).
  String? reportedDateIso;
  // ISO 8601 - when the employee actually confirmed the job done. Set alongside
  // afterPhotoUrls in the Mark as Completed flow.
  String? completedAt;
  // ISO 8601 - when the employee actually started work on site. Set via the Start Job
  // action, separate from completedAt so both ends of the job are tracked, not just
  // whether it beat the deadline.
  String? startedAt;
  // Free-text note captured at the moment a work order is marked completed (Confirm
  // Completion), separate from employeeNotes (the site-visit description filled in earlier).
  String? completionRemarks;
  // The Gmail thread/message this work order was created from (see GmailService), if it came
  // in via Gmail sync rather than being entered manually. Lets "Send Quotation via Email"
  // reply inside that same Gmail thread instead of starting a disconnected new email -
  // gmailMessageId is the RFC "Message-ID" header value (needed for the In-Reply-To/
  // References headers), gmailThreadId is Gmail's own thread identifier.
  String? gmailMessageId;
  String? gmailThreadId;
  // Gmail's own internal message id (distinct from gmailMessageId, the RFC header) - always
  // present on every email regardless of whether it has a parseable Message-ID header, so this
  // is the dedup key used to recognize "this exact email already created a work order" even
  // when the work-order-number parse fails on a later sync run.
  String? gmailSourceMessageId;

  WorkOrder({
    required this.id,
    required this.siteName,
    required this.address,
    required this.region,
    required this.priority,
    required this.description,
    required this.targetDate,
    required this.status,
    required this.reportedDate,
    this.quotation,
    List<String>? afterPhotoUrls,
    this.rejectionNote,
    this.rejectedByRole,
    this.assignedEmployeeUsername,
    this.employeeNotes,
    List<String>? employeePhotoUrls,
    this.assignedVendorUsername,
    this.workType,
    this.targetDateIso,
    this.reportedDateIso,
    this.completedAt,
    this.startedAt,
    this.completionRemarks,
    this.gmailMessageId,
    this.gmailThreadId,
    this.gmailSourceMessageId,
  })  : afterPhotoUrls = afterPhotoUrls ?? [],
        employeePhotoUrls = employeePhotoUrls ?? [];

  // Wall-clock time actually spent on the job, start to finish - null if either end is
  // missing (job not started/finished yet, or started before this field existed).
  Duration? get jobDuration {
    if (startedAt == null || completedAt == null) return null;
    final start = DateTime.tryParse(startedAt!);
    final end = DateTime.tryParse(completedAt!);
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    return diff.isNegative ? null : diff;
  }

  // The real report date/time as a DateTime, for grouping/sorting (e.g. the month-wise Work
  // Orders view) - prefers the structured reportedDateIso, falling back to parsing the
  // display-only reportedDate string (always produced by the shared "dd-MMM-yyyy HH:mm"
  // formatter, see _formatDateTimeDisplay) for work orders created before reportedDateIso
  // existed. Null only if neither is parseable.
  DateTime? get reportedDateTime {
    if (reportedDateIso != null) {
      final parsed = DateTime.tryParse(reportedDateIso!);
      if (parsed != null) return parsed;
    }
    return _parseDisplayDateTime(reportedDate);
  }

  // true = finished on or before the target date (SLA met), false = finished late (Non SLA),
  // null = can't be determined (no structured target date, or not completed yet).
  bool? get metSla {
    if (targetDateIso == null || completedAt == null) return null;
    final target = DateTime.tryParse(targetDateIso!);
    final completed = DateTime.tryParse(completedAt!);
    if (target == null || completed == null) return null;
    return !completed.isAfter(target);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'siteName': siteName,
        'address': address,
        'region': region,
        'priority': priority,
        'description': description,
        'targetDate': targetDate,
        'reportedDate': reportedDate,
        'status': status.name,
        'quotation': quotation?.toMap(),
        'afterPhotoUrls': afterPhotoUrls,
        'rejectionNote': rejectionNote,
        'rejectedByRole': rejectedByRole,
        'assignedEmployeeUsername': assignedEmployeeUsername,
        'employeeNotes': employeeNotes,
        'employeePhotoUrls': employeePhotoUrls,
        'assignedVendorUsername': assignedVendorUsername,
        'workType': workType,
        'targetDateIso': targetDateIso,
        'reportedDateIso': reportedDateIso,
        'completedAt': completedAt,
        'startedAt': startedAt,
        'completionRemarks': completionRemarks,
        'gmailMessageId': gmailMessageId,
        'gmailThreadId': gmailThreadId,
        'gmailSourceMessageId': gmailSourceMessageId,
      };

  static WorkOrder fromMap(Map<String, dynamic> m) => WorkOrder(
        // Every other field here has a fallback default - id didn't, so one stray doc with a
        // missing/null id (e.g. a manual edit in the Firestore console) would throw a type
        // error inside the .map() in loadWorkOrders/watchWorkOrders and take down the entire
        // work order list app-wide, not just that one row.
        id: m['id'] ?? '',
        siteName: m['siteName'] ?? '',
        address: m['address'] ?? '',
        region: m['region'] ?? '',
        priority: m['priority'] ?? 2,
        description: m['description'] ?? '',
        targetDate: m['targetDate'] ?? '',
        reportedDate: m['reportedDate'] ?? '',
        status: WorkOrderStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => WorkOrderStatus.pending),
        quotation: m['quotation'] != null ? QuotationData.fromMap(Map<String, dynamic>.from(m['quotation'])) : null,
        afterPhotoUrls: List<String>.from(m['afterPhotoUrls'] ?? []),
        rejectionNote: m['rejectionNote'],
        rejectedByRole: m['rejectedByRole'],
        assignedEmployeeUsername: m['assignedEmployeeUsername'],
        employeeNotes: m['employeeNotes'],
        employeePhotoUrls: List<String>.from(m['employeePhotoUrls'] ?? []),
        assignedVendorUsername: m['assignedVendorUsername'],
        workType: m['workType'],
        targetDateIso: m['targetDateIso'],
        reportedDateIso: m['reportedDateIso'],
        completedAt: m['completedAt'],
        startedAt: m['startedAt'],
        completionRemarks: m['completionRemarks'],
        gmailMessageId: m['gmailMessageId'],
        gmailThreadId: m['gmailThreadId'],
        gmailSourceMessageId: m['gmailSourceMessageId'],
      );
}

// Parses the shared "dd-MMM-yyyy HH:mm" display format (see _formatDateTimeDisplay) back into
// a DateTime - used as the fallback for reportedDateTime on work orders that predate the
// structured reportedDateIso field. Returns null on anything that doesn't match.
DateTime? _parseDisplayDateTime(String s) {
  final parts = s.trim().split(' ');
  if (parts.isEmpty) return null;
  final dateParts = parts[0].split('-');
  if (dateParts.length != 3) return null;
  final day = int.tryParse(dateParts[0]);
  final monthIdx = _monthAbbrevs.indexOf(dateParts[1]);
  final year = int.tryParse(dateParts[2]);
  if (day == null || monthIdx == -1 || year == null) return null;
  int hour = 0;
  int minute = 0;
  if (parts.length > 1) {
    final timeParts = parts[1].split(':');
    if (timeParts.length == 2) {
      hour = int.tryParse(timeParts[0]) ?? 0;
      minute = int.tryParse(timeParts[1]) ?? 0;
    }
  }
  return DateTime(year, monthIdx + 1, day, hour, minute);
}

