part of '../main.dart';

// ---------------- PHOTO PICKER (web file input) ----------------
// Shared by WhatsApp share and email so both match the in-app quotation preview
// (vendor registration details, client info, full description, per-line CMEP).
String _formatQuotationForSharing(WorkOrder workOrder, QuotationData quotation, {required bool markdown}) {
  String bold(String s) => markdown ? '*$s*' : s;
  final buffer = StringBuffer();
  buffer.writeln(bold(vendorName));
  buffer.writeln('NTN: $vendorNTN   STRN: $vendorSTRN');
  buffer.writeln(vendorAddress);
  buffer.writeln('');
  buffer.writeln('Quotation: ${quotation.id}');
  buffer.writeln('WO #: ${workOrder.id}');
  buffer.writeln('Site: ${quotation.siteName}');
  buffer.writeln('Date: ${quotation.date}');
  buffer.writeln('Client: ${quotation.clientName} (${quotation.clientCompany})');
  buffer.writeln('');
  buffer.writeln(bold('Description of Work Order:'));
  buffer.writeln(quotation.descriptionOfWorkOrder);
  buffer.writeln('');
  buffer.writeln(bold('Line Items:'));
  for (final item in quotation.lineItems) {
    buffer.writeln(
      '- ${item.description} (${item.cmepStatus}): ${item.qty.toStringAsFixed(0)} ${item.unit} x Rs ${item.rate.toStringAsFixed(0)} '
      '= Rs ${item.amount.toStringAsFixed(0)}'
      '${item.remarks.isNotEmpty ? ' [${item.remarks}]' : ''}',
    );
  }
  buffer.writeln('');
  buffer.writeln('Sub Total: Rs ${quotation.subTotal.toStringAsFixed(0)}');
  buffer.writeln(bold('Quote Total: Rs ${quotation.quoteTotal.toStringAsFixed(0)}'));
  if (quotation.notes.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('Notes: ${quotation.notes}');
  }
  return buffer.toString();
}

void shareQuotationOnWhatsApp(WorkOrder workOrder, QuotationData quotation) {
  final text = _formatQuotationForSharing(workOrder, quotation, markdown: true);
  final encodedText = Uri.encodeComponent(text);
  launchUrl(Uri.parse('https://wa.me/?text=$encodedText'), mode: LaunchMode.externalApplication);
}

// Opens a real Gmail compose window with the quotation pre-filled (subject + plain-text
// body) so the user reviews it in their own inbox and clicks Send themselves - the
// recipient is left for them to type in Gmail directly, not pre-filled by the app. A
// compose window only ever accepts plain text, never the styled HTML look of the in-app
// preview - that's a hard limit of how every mail provider's compose deep link works, not
// something this app can work around.
// Builds the quotation as styled HTML matching AES's real quotation sheet format (gold
// header banner with the company name and "Quotation" title, a green swatch, a 3-column
// Vendor Details / Client Information / Date-WO#-Quotation# grid, Site Name and Description
// rows, then the line-items table with CMEP and AES Remarks columns and a Sub Total + Quote
// Total footer) - this is the actual email body sent through Gmail's API when "Send
// Quotation via Email" is clicked, so it matches what the client is used to receiving
// instead of arriving as a plain, unbranded table.
String _quotationEmailHtml(WorkOrder workOrder, QuotationData quotation, {String? customMessage}) {
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  String nl2br(String s) => esc(s).replaceAll('\n', '<br>');
  const gold = '#F3B41B';
  const green = '#A6D785';
  const border = '#000000';
  const cellStyle = 'border:1px solid $border;padding:6px 10px;font-family:Arial,Helvetica,sans-serif;font-size:12px;';

  final rows = StringBuffer();
  for (int i = 0; i < quotation.lineItems.length; i++) {
    final item = quotation.lineItems[i];
    rows.write(
      '<tr>'
      '<td style="$cellStyle">${i + 1}</td>'
      '<td style="$cellStyle">${esc(item.description)}</td>'
      '<td style="$cellStyle">${esc(item.unit)}</td>'
      '<td style="$cellStyle">${item.qty.toStringAsFixed(0)}</td>'
      '<td style="$cellStyle text-align:right;">${_thousands(item.rate)}</td>'
      '<td style="$cellStyle text-align:right;font-weight:bold;">${_thousands(item.amount)}</td>'
      '<td style="$cellStyle">${esc(item.cmepStatus)}</td>'
      '<td style="$cellStyle">${esc(item.remarks)}</td>'
      '</tr>',
    );
  }

  final messageHtml = (customMessage != null && customMessage.trim().isNotEmpty)
      ? '<p style="font-family:Arial,Helvetica,sans-serif;font-size:13px;color:#222;">${nl2br(customMessage.trim())}</p>'
      : '';

  return '<div style="font-family:Arial,Helvetica,sans-serif;">'
      '$messageHtml'
      '<table style="border-collapse:collapse;width:100%;max-width:900px;" cellspacing="0">'
      // ---- Header banner: company name | "Quotation" | green swatch ----
      '<tr>'
      '<td colspan="2" style="$cellStyle background:$gold;font-weight:bold;font-size:16px;">${esc(vendorName)}</td>'
      '<td colspan="2" style="$cellStyle background:$gold;font-weight:bold;font-size:20px;text-align:center;">Quotation</td>'
      '<td style="$cellStyle background:$green;">&nbsp;</td>'
      '</tr>'
      // ---- Vendor Details | Client Information | Date/WO#/Quotation# ----
      '<tr>'
      '<td colspan="2" style="$cellStyle font-weight:bold;">Vendor Details</td>'
      '<td style="$cellStyle font-weight:bold;">Client Information</td>'
      '<td style="$cellStyle font-weight:bold;">Date:</td>'
      '<td style="$cellStyle">${esc(quotation.date)}</td>'
      '</tr>'
      '<tr>'
      '<td colspan="2" style="$cellStyle">NTN: $vendorNTN<br>STRN: $vendorSTRN</td>'
      '<td rowspan="2" style="$cellStyle">${nl2br(quotation.clientName)}<br>${nl2br(quotation.clientCompany)}</td>'
      '<td style="$cellStyle font-weight:bold;">WO#</td>'
      '<td style="$cellStyle background:$green;">${esc(workOrder.id)}</td>'
      '</tr>'
      '<tr>'
      '<td colspan="2" style="$cellStyle">${esc(vendorAddress)}</td>'
      '<td style="$cellStyle font-weight:bold;">Quotation#</td>'
      '<td style="$cellStyle">${esc(quotation.id)}</td>'
      '</tr>'
      // ---- Site Name ----
      '<tr>'
      '<td style="$cellStyle font-weight:bold;">Site Name:</td>'
      '<td colspan="4" style="$cellStyle">${esc(quotation.siteName)}</td>'
      '</tr>'
      // ---- Description of Work Order ----
      '<tr>'
      '<td colspan="5" style="$cellStyle font-weight:bold;">Description of Work Order</td>'
      '</tr>'
      '<tr>'
      '<td colspan="5" style="$cellStyle">${esc(quotation.descriptionOfWorkOrder)}</td>'
      '</tr>'
      '</table>'
      '<table style="border-collapse:collapse;width:100%;max-width:900px;margin-top:6px;" cellspacing="0">'
      '<tr style="background:$gold;">'
      '<th style="$cellStyle">Sr #</th>'
      '<th style="$cellStyle">Description</th>'
      '<th style="$cellStyle">Units</th>'
      '<th style="$cellStyle">Qty</th>'
      '<th style="$cellStyle">Rate (PKR)</th>'
      '<th style="$cellStyle">Amount (PKR)</th>'
      '<th style="$cellStyle">CMEP BOQ or Not</th>'
      '<th style="$cellStyle">AES Remarks</th>'
      '</tr>'
      '$rows'
      '<tr style="background:$gold;font-weight:bold;">'
      '<td colspan="5" style="$cellStyle text-align:right;">Sub Total</td>'
      '<td colspan="3" style="$cellStyle text-align:right;">${_thousands(quotation.subTotal)}</td>'
      '</tr>'
      '<tr style="background:$gold;font-weight:bold;">'
      '<td colspan="5" style="$cellStyle text-align:right;">Quote Total</td>'
      '<td colspan="3" style="$cellStyle text-align:right;">${_thousands(quotation.quoteTotal)}</td>'
      '</tr>'
      '</table>'
      '${quotation.notes.isNotEmpty ? '<p style="font-family:Arial,Helvetica,sans-serif;font-size:12px;"><b>Notes / Terms:</b><br>${nl2br(quotation.notes)}</p>' : ''}'
      '</div>';
}

// Thousands-separated whole number (e.g. 172939 -> "172,939") - matches how the real
// quotation sheet formats every currency figure.
String _thousands(double value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return (rounded < 0 ? '-' : '') + buffer.toString();
}

// Sends the quotation as a styled HTML email directly through Gmail - no compose window,
// no manual copy-paste. Requires the company Gmail account to be connected on the Gmail
// Sync page with send permission granted (see GmailService.sendEmail for what happens if
// that permission hasn't been granted yet).
Future<void> sendQuotationViaEmail(
  WorkOrder workOrder,
  QuotationData quotation,
  String recipientEmail, {
  String? ccEmail,
  String? subject,
  String? customMessage,
  EmailAttachment? attachment,
}) async {
  final html = _quotationEmailHtml(workOrder, quotation, customMessage: customMessage);
  await GmailService.sendEmail(
    to: recipientEmail,
    cc: ccEmail,
    subject: subject ?? 'Quotation ${quotation.id} - ${quotation.siteName}',
    htmlBody: html,
    attachments: attachment != null ? [attachment] : const [],
    // Only populated for a work order that actually came in via Gmail sync - lands this
    // quotation inside that same original thread instead of a disconnected new email. A
    // manually-created work order has neither field set, so this is a no-op for it.
    threadId: workOrder.gmailThreadId,
    inReplyToMessageId: workOrder.gmailMessageId,
  );
}

void pickImageFile(void Function(String dataUrl) onLoaded, {bool useCamera = false}) async {
  // Constrained and re-encoded so a single photo stays well under Firestore's
  // 1 MiB per-document limit once base64-encoded (photos are stored inline, not in Storage).
  final picked = await ImagePicker().pickImage(
    source: useCamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 70,
  );
  if (picked == null) return;
  final bytes = await picked.readAsBytes();
  final mimeType = picked.mimeType ?? 'image/jpeg';
  onLoaded('data:$mimeType;base64,${base64Encode(bytes)}');
}

Uint8List _decodeDataUrl(String dataUrl) {
  final base64Part = dataUrl.split(',').last;
  return base64Decode(base64Part);
}

