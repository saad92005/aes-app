part of '../main.dart';

// ---------------- EXPORT SERVICE (PDF / Excel / Image generation) ----------------
// Everything here is generated client-side and handed to share_plus (same as the CSV
// exports already were) or attached to a Gmail message - nothing is persisted to a file
// store, so this stays entirely within the free Firestore-only plan.
class ExportService {
  // ---- Generic tabular reports - reused by every report screen that used to only offer
  // a CSV download (attendance, expenses, inventory, work orders). rows[0] is treated as
  // the header row. ----
  static Future<Uint8List> rowsToPdfBytes(
    String title,
    List<List<String>> rows,
  ) async {
    final doc = pw.Document();
    final headers = rows.isNotEmpty ? rows.first : <String>[];
    final data = rows.length > 1 ? rows.sublist(1) : <List<String>>[];
    doc.addPage(
      pw.MultiPage(
        pageFormat: pw.PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: pw.PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pw.PdfColors.grey300),
                children: headers
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              for (final row in data)
                pw.TableRow(
                  children: row
                      .map(
                        (c) => pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            c,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ---- Payslip PDF - a single employee's payslip for a single period, formatted like a real
  // payslip rather than the generic rowsToPdfBytes table. ----
  static Future<Uint8List> payslipPdfBytes(
    PayrollRecord record,
    PayrollPeriod? period,
  ) async {
    final doc = pw.Document();
    final green = pw.PdfColor.fromHex('#1B7A3D');
    final grey = pw.PdfColors.grey300;

    pw.Widget row(String label, String value, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                label,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: pw.PdfColors.grey700,
                ),
              ),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        );

    pw.Widget section(String title, List<pw.Widget> children) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: grey, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: green,
            ),
          ),
          pw.Divider(height: 10),
          ...children,
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: pw.PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  vendorName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: green,
                  ),
                ),
                pw.Text(
                  'Payslip',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              period?.monthLabel ?? record.periodId,
              style: const pw.TextStyle(
                fontSize: 11,
                color: pw.PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 12),
            section('Employee', [
              row('Employee', record.username),
              row('Region', record.region),
              row('Employee Type', record.employeeType.label),
              row('Status', period?.status.label ?? '-'),
            ]),
            section('Attendance Summary', [
              row('Total Working Days', '${record.totalWorkingDays}'),
              row('Present Days', '${record.presentDays}'),
              row('Absent Days', '${record.absentDays}'),
              row('Paid Leave Days', '${record.paidLeaveDays}'),
              row('Unpaid Leave Days', '${record.unpaidLeaveDays}'),
              row('Holiday Days', '${record.holidayDays}'),
              row(
                'Late Days',
                '${record.lateDays} (${record.lateMinutesTotal} min)',
              ),
              row(
                'Early Checkout Days',
                '${record.earlyCheckoutDays} (${record.earlyCheckoutMinutesTotal} min)',
              ),
              row('Overtime Hours', record.overtimeHours.toStringAsFixed(1)),
            ]),
            section('Earnings', [
              row(
                'Basic Salary',
                'Rs ${record.basicSalary.toStringAsFixed(0)}',
              ),
              row(
                'Earned Basic (Attendance-Adjusted)',
                'Rs ${record.earnedBasicSalary.toStringAsFixed(0)}',
              ),
              row(
                'Overtime Pay',
                'Rs ${record.overtimePay.toStringAsFixed(0)}',
              ),
              for (final a in record.allowances)
                row(
                  'Allowance: ${a.label}',
                  'Rs ${a.amount.toStringAsFixed(0)}',
                ),
              for (final b in record.bonuses)
                row('Bonus: ${b.label}', 'Rs ${b.amount.toStringAsFixed(0)}'),
              pw.Divider(height: 10),
              row(
                'Gross Salary',
                'Rs ${record.grossSalary.toStringAsFixed(0)}',
                bold: true,
              ),
            ]),
            section('Deductions', [
              row(
                'Late Arrival Deduction',
                'Rs ${record.lateDeduction.toStringAsFixed(0)}',
              ),
              row(
                'Early Checkout Deduction',
                'Rs ${record.earlyCheckoutDeduction.toStringAsFixed(0)}',
              ),
              for (final d in record.manualDeductions)
                row(d.label, 'Rs ${d.amount.toStringAsFixed(0)}'),
              pw.Divider(height: 10),
              row(
                'Total Deductions',
                'Rs ${record.totalDeductions.toStringAsFixed(0)}',
                bold: true,
              ),
            ]),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: green,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Net Salary',
                    style: pw.TextStyle(
                      color: pw.PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Rs ${record.netSalary.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      color: pw.PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated: ${record.calculatedAt.split('T').first}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: pw.PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Uint8List rowsToCsvBytes(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(
        row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
      );
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  // Lets the user pick CSV / Excel / PDF for any of the report screens (attendance,
  // expenses, inventory, work orders) instead of only ever getting a CSV.
  static Future<void> exportRowsWithFormatChoice(
    BuildContext context, {
    required String title,
    required List<List<String>> rows,
    required String filenameBase,
  }) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                tr('Export as'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AESColors.darkGreen,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: AESColors.primaryGreen,
              ),
              title: const Text('CSV'),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on, color: AESColors.primaryGreen),
              title: Text(tr('Excel (.xlsx)')),
              onTap: () => Navigator.pop(context, 'excel'),
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AESColors.primaryGreen,
              ),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (format == null || !context.mounted) return;

    Uint8List bytes;
    String name;
    String mimeType;
    switch (format) {
      case 'excel':
        bytes = rowsToExcelBytes(title, rows);
        name = '$filenameBase.xlsx';
        mimeType =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        break;
      case 'pdf':
        bytes = await rowsToPdfBytes(title, rows);
        name = '$filenameBase.pdf';
        mimeType = 'application/pdf';
        break;
      default:
        bytes = rowsToCsvBytes(rows);
        name = '$filenameBase.csv';
        mimeType = 'text/csv';
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: name, mimeType: mimeType)],
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name ready to share/download'),
          backgroundColor: AESColors.darkGreen,
        ),
      );
    }
  }

  static Uint8List rowsToExcelBytes(String sheetName, List<List<String>> rows) {
    final workbook = xls.Excel.createExcel();
    final defaultName = workbook.getDefaultSheet();
    // Excel sheet names can't exceed 31 chars or contain []:*?/\ - the titles this app
    // passes in are short plain words, so a plain truncation is enough to stay valid.
    final safeName = sheetName.length > 31
        ? sheetName.substring(0, 31)
        : sheetName;
    if (defaultName != null && defaultName != safeName) {
      workbook.rename(defaultName, safeName);
    }
    final sheet = workbook[safeName];
    for (final row in rows) {
      sheet.appendRow(
        row.map<xls.CellValue?>((c) => xls.TextCellValue(c)).toList(),
      );
    }
    final bytes = workbook.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  // ---- Quotation-specific exports: PDF / Excel / Image choice at send time ----
  static Future<Uint8List> quotationPdfBytes(
    WorkOrder workOrder,
    QuotationData quotation,
  ) async {
    final doc = pw.Document();
    final gold = pw.PdfColor.fromHex('#F3B41B');
    final green = pw.PdfColor.fromHex('#A6D785');
    pw.Widget cell(
      String text, {
      bool bold = false,
      pw.PdfColor? bg,
      double size = 9,
    }) => pw.Container(
      padding: const pw.EdgeInsets.all(5),
      color: bg,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: pw.PdfColors.black, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                children: [
                  cell(vendorName, bold: true, bg: gold, size: 13),
                  cell('Quotation', bold: true, bg: gold, size: 15),
                  cell('', bg: green),
                  cell('', bg: gold),
                ],
              ),
              pw.TableRow(
                children: [
                  cell('Vendor Details', bold: true),
                  cell('Client Information', bold: true),
                  cell('Date:', bold: true),
                  cell(quotation.date),
                ],
              ),
              pw.TableRow(
                children: [
                  cell('NTN: $vendorNTN\nSTRN: $vendorSTRN'),
                  cell('${quotation.clientName}\n${quotation.clientCompany}'),
                  cell('WO#', bold: true),
                  cell(workOrder.id, bg: green),
                ],
              ),
              pw.TableRow(
                children: [
                  cell(vendorAddress),
                  cell(''),
                  cell('Quotation#', bold: true),
                  cell(quotation.id),
                ],
              ),
              pw.TableRow(
                children: [
                  cell('Site Name:', bold: true),
                  cell(quotation.siteName),
                  cell(''),
                  cell(''),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            tr('Description of Work Order:'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.Text(
            quotation.descriptionOfWorkOrder,
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: pw.PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: pw.PdfColor.fromHex('#F3B41B'),
                ),
                children:
                    [
                          'Sr#',
                          'Description',
                          'Units',
                          'Qty',
                          'Rate (PKR)',
                          'Amount (PKR)',
                          'CMEP BOQ or Not',
                          'AES Remarks',
                        ]
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              for (int i = 0; i < quotation.lineItems.length; i++)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '${i + 1}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        quotation.lineItems[i].description,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        quotation.lineItems[i].unit,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        quotation.lineItems[i].qty.toStringAsFixed(0),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        quotation.lineItems[i].rate.toStringAsFixed(0),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        quotation.lineItems[i].amount.toStringAsFixed(0),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        quotation.lineItems[i].cmepStatus,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        quotation.lineItems[i].remarks,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: pw.PdfColor.fromHex('#F3B41B'),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      tr('Sub Total'),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      quotation.subTotal.toStringAsFixed(0),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                ],
              ),
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: pw.PdfColor.fromHex('#F3B41B'),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      tr('Quote Total'),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      quotation.quoteTotal.toStringAsFixed(0),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.SizedBox(),
                  ),
                ],
              ),
            ],
          ),
          if (quotation.notes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              tr('Notes / Terms:'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.Text(quotation.notes, style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static Uint8List quotationExcelBytes(
    WorkOrder workOrder,
    QuotationData quotation,
  ) {
    final rows = <List<String>>[
      [vendorName, '', 'Quotation', '', ''],
      ['NTN: $vendorNTN  STRN: $vendorSTRN', '', '', '', ''],
      [vendorAddress, '', '', '', ''],
      [],
      [
        'Client Information',
        '${quotation.clientName} / ${quotation.clientCompany}',
        '',
        'Date:',
        quotation.date,
      ],
      ['', '', '', 'WO#', workOrder.id],
      ['', '', '', 'Quotation#', quotation.id],
      ['Site Name:', quotation.siteName, '', '', ''],
      [],
      ['Description of Work Order'],
      [quotation.descriptionOfWorkOrder],
      [],
      [
        'Sr#',
        'Description',
        'Units',
        'Qty',
        'Rate (PKR)',
        'Amount (PKR)',
        'CMEP BOQ or Not',
        'AES Remarks',
      ],
      for (int i = 0; i < quotation.lineItems.length; i++)
        [
          '${i + 1}',
          quotation.lineItems[i].description,
          quotation.lineItems[i].unit,
          quotation.lineItems[i].qty.toStringAsFixed(0),
          quotation.lineItems[i].rate.toStringAsFixed(0),
          quotation.lineItems[i].amount.toStringAsFixed(0),
          quotation.lineItems[i].cmepStatus,
          quotation.lineItems[i].remarks,
        ],
      [
        '',
        '',
        '',
        '',
        'Sub Total',
        quotation.subTotal.toStringAsFixed(0),
        '',
        '',
      ],
      [
        '',
        '',
        '',
        '',
        'Quote Total',
        quotation.quoteTotal.toStringAsFixed(0),
        '',
        '',
      ],
      if (quotation.notes.isNotEmpty) ...[
        [],
        ['Notes / Terms', quotation.notes],
      ],
    ];
    return rowsToExcelBytes('Quotation ${quotation.id}', rows);
  }

  static Future<Uint8List> quotationImageBytes(
    BuildContext context,
    WorkOrder workOrder,
    QuotationData quotation,
  ) {
    return captureWidgetAsPngBytes(
      context,
      _QuotationPrintableWidget(workOrder: workOrder, quotation: quotation),
    );
  }

  // Renders an arbitrary widget off-screen (via a temporary Overlay entry) and captures it
  // as PNG bytes. Used for the quotation "Image" export - there's no dedicated screenshot
  // package dependency needed since Flutter's own RenderRepaintBoundary covers this on
  // every platform this app targets, including web.
  static Future<Uint8List> captureWidgetAsPngBytes(
    BuildContext context,
    Widget widget, {
    double pixelRatio = 2,
    double width = 800,
  }) async {
    final repaintKey = GlobalKey();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final completer = Completer<Uint8List>();
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -5000,
        top: 0,
        child: Material(
          color: Colors.white,
          child: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(width: width, child: widget),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Give layout/painting a moment to fully settle before capturing.
        await Future.delayed(const Duration(milliseconds: 100));
        final boundary =
            repaintKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        completer.complete(byteData!.buffer.asUint8List());
      } catch (e) {
        completer.completeError(e);
      } finally {
        entry.remove();
      }
    });
    return completer.future;
  }
}

// Plain-Flutter-widget rendition of the quotation, used only for the "Image" export path
// (mirrors the layout of _quotationEmailHtml, since that one is HTML and can't be captured
// as a widget screenshot).
class _QuotationPrintableWidget extends StatelessWidget {
  final WorkOrder workOrder;
  final QuotationData quotation;
  const _QuotationPrintableWidget({
    required this.workOrder,
    required this.quotation,
  });

  static const _gold = Color(0xFFF3B41B);
  static const _green = Color(0xFFA6D785);

  Widget _cell(
    String text, {
    bool bold = false,
    Color? bg,
    double size = 10,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(6),
        color: bg,
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: Colors.black, width: 0.5);
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(border: border),
            child: Row(
              children: [
                _cell(vendorName, bold: true, bg: _gold, size: 15, flex: 3),
                _cell('Quotation', bold: true, bg: _gold, size: 17, flex: 2),
                _cell('', bg: _green, flex: 1),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: border),
            child: Row(
              children: [
                _cell('Vendor Details', bold: true, flex: 3),
                _cell('Client Information', bold: true, flex: 2),
                _cell('Date:', bold: true, flex: 1),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: border),
            child: Row(
              children: [
                _cell('NTN: $vendorNTN\nSTRN: $vendorSTRN', flex: 3),
                _cell(
                  '${quotation.clientName}\n${quotation.clientCompany}',
                  flex: 2,
                ),
                _cell(quotation.date, flex: 1),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: border),
            child: Row(
              children: [
                _cell(vendorAddress, flex: 5),
                _cell('WO#', bold: true, flex: 1),
                _cell(workOrder.id, bg: _green, flex: 1),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: border),
            child: Row(
              children: [
                _cell('', flex: 5),
                _cell('Quotation#', bold: true, flex: 1),
                _cell(quotation.id, flex: 1),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: border),
            child: Row(
              children: [
                _cell('Site Name:', bold: true, flex: 1),
                _cell(quotation.siteName, flex: 6),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr('Description of Work Order:'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          Text(
            quotation.descriptionOfWorkOrder,
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
          const SizedBox(height: 14),
          Table(
            border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _gold),
                children:
                    [
                          'Sr#',
                          'Description',
                          'Units',
                          'Qty',
                          'Rate (PKR)',
                          'Amount (PKR)',
                          'CMEP BOQ or Not',
                          'AES Remarks',
                        ]
                        .map(
                          (h) => Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              h,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              for (int i = 0; i < quotation.lineItems.length; i++)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        quotation.lineItems[i].description,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        quotation.lineItems[i].unit,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        quotation.lineItems[i].qty.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        quotation.lineItems[i].rate.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        quotation.lineItems[i].amount.toStringAsFixed(0),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        quotation.lineItems[i].cmepStatus,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        quotation.lineItems[i].remarks,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              TableRow(
                decoration: const BoxDecoration(color: _gold),
                children: [
                  const SizedBox(),
                  const SizedBox(),
                  const SizedBox(),
                  const SizedBox(),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      tr('Sub Total'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      quotation.subTotal.toStringAsFixed(0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(),
                  const SizedBox(),
                ],
              ),
              TableRow(
                decoration: const BoxDecoration(color: _gold),
                children: [
                  const SizedBox(),
                  const SizedBox(),
                  const SizedBox(),
                  const SizedBox(),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      tr('Quote Total'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      quotation.quoteTotal.toStringAsFixed(0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(),
                  const SizedBox(),
                ],
              ),
            ],
          ),
          if (quotation.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tr('Notes / Terms:'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black,
              ),
            ),
            Text(
              quotation.notes,
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ],
        ],
      ),
    );
  }
}
