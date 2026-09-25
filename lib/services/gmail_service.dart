part of '../main.dart';

// ---------------- GMAIL INTEGRATION ----------------
class ParsedEmailWorkOrder {
  final String? workOrderNumber;
  final String? siteName;
  final String address;
  final String description;
  final int? priority;
  final String? workType;
  final String? targetDate;
  final String? reportedDate;

  ParsedEmailWorkOrder({
    this.workOrderNumber,
    this.siteName,
    required this.address,
    required this.description,
    this.priority,
    this.workType,
    this.targetDate,
    this.reportedDate,
  });
}

class EmailSummary {
  final String messageId;
  // Gmail's thread identifier, plus the RFC "Message-ID" header value - together these are
  // what let a later "Send Quotation via Email" reply land inside this same Gmail thread
  // instead of starting a disconnected new email. Null for anything fetched before these
  // were added, or if the email genuinely had no Message-ID header (rare, but not fatal -
  // sendEmail just falls back to a normal non-threaded send).
  final String? threadId;
  final String? rfcMessageId;
  final String subject;
  final String? attachmentName;
  final String? workOrderNumber;
  final int? priority;
  final String? siteName;
  final String? siteCode;
  final String? alertNote;
  final String? from;
  final String? date;
  final String? snippet;

  EmailSummary({
    required this.messageId,
    this.threadId,
    this.rfcMessageId,
    required this.subject,
    this.attachmentName,
    this.workOrderNumber,
    this.priority,
    this.siteName,
    this.siteCode,
    this.alertNote,
    this.from,
    this.date,
    this.snippet,
  });
}

class EmailAttachment {
  final String filename;
  final String mimeType;
  final Uint8List bytes;
  const EmailAttachment({required this.filename, required this.mimeType, required this.bytes});
}

class _ParsedSubject {
  final String? workOrderNumber;
  final int? priority;
  final String? siteCode;
  final String? siteName;
  final String? alertNote;

  _ParsedSubject({this.workOrderNumber, this.priority, this.siteCode, this.siteName, this.alertNote});
}

class GmailService {
  // Only this exact company Gmail account is allowed to connect - anything else gets rejected.
  // workorder@aesengg.com (the Outlook inbox this eventually gets forwarded to) can't be used
  // here - the Gmail API only talks to real Gmail/Google Workspace mailboxes, and this is the
  // Gmail account the emails actually land in first, before that forward happens.
  static const String companyEmail = 'alareesheng@gmail.com';

  // Read access (to find/parse work order emails) plus send-only access (gmail.send lets
  // this app compose and send new messages on the user's behalf - it still can never read,
  // delete, or modify anything beyond what gmail.readonly already allowed, and can't touch
  // any existing email). Anyone already connected from before this scope was added needs to
  // Disconnect and Connect again - Google only grants newly-added scopes on fresh consent.
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: 'YOUR_GOOGLE_OAUTH_CLIENT_ID.apps.googleusercontent.com',
    scopes: [
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.send',
    ],
  );

  static GoogleSignInAccount? currentAccount;

  // Popup-based sign-in - the single consent popup grants both identity and the Gmail scope
  // access token together, so a work order sync can run immediately after this returns.
  static Future<GoogleSignInAccount?> connect() async {
    final account = await _googleSignIn.signIn();
    if (account != null && account.email.toLowerCase() != companyEmail.toLowerCase()) {
      await _googleSignIn.signOut();
      throw Exception('Please sign in with the company account ($companyEmail), not ${account.email}');
    }
    currentAccount = account;
    return account;
  }

  // Tries to silently restore a previous sign-in (e.g. after a page refresh) without
  // showing any popup, as long as the browser still remembers the company account.
  static Future<bool> tryRestoreSession() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null && account.email.toLowerCase() == companyEmail.toLowerCase()) {
        currentAccount = account;
        return true;
      }
    } catch (_) {
      // No previous session to restore - that's fine, just stay disconnected.
    }
    return false;
  }

  static Future<void> disconnect() async {
    await _googleSignIn.signOut();
    currentAccount = null;
  }

  static bool get isConnected => currentAccount != null;

  static Future<String?> _getAccessToken() async {
    if (currentAccount == null) {
      // Connection may have silently dropped - try one automatic reconnect before giving up.
      await tryRestoreSession();
    }
    if (currentAccount == null) return null;
    try {
      final auth = await currentAccount!.authentication;
      return auth.accessToken;
    } catch (_) {
      // The stored session turned out to be stale - try restoring once more.
      await tryRestoreSession();
      if (currentAccount == null) return null;
      final auth = await currentAccount!.authentication;
      return auth.accessToken;
    }
  }

  // Searches Gmail for CBRE work order emails from the last 3 weeks and returns the raw
  // list of message IDs found. Gmail returns matches newest-first and only one page (100
  // max) per request, so without pagination and a generous maxTotal, a single Refresh could
  // silently stop after the first page even though more matching emails exist in that
  // window - this walks multiple pages until either the window is exhausted or maxTotal is
  // hit, so one click picks up everything from the last few weeks, not just the newest one.
  static Future<List<String>> findWorkOrderEmailIds({int maxTotal = 200}) async {
    final token = await _getAccessToken();
    if (token == null) throw Exception('Connection was lost. Please click Disconnect, then Connect with Google again.');

    final query = Uri.encodeComponent('from:FMPlatformDoNotReply@cbre.com subject:"Work Order" newer_than:21d');
    final ids = <String>[];
    String? pageToken;
    do {
      final pageParam = pageToken != null ? '&pageToken=$pageToken' : '';
      final url = Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages?q=$query&maxResults=100$pageParam');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode != 200) {
        throw Exception('Gmail search failed (${response.statusCode})');
      }
      final data = jsonDecode(response.body);
      final messages = (data['messages'] as List?) ?? [];
      ids.addAll(messages.map((m) => m['id'] as String));
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null && ids.length < maxTotal);

    return ids.take(maxTotal).toList();
  }

  // Fetches the full body text of one email by its message ID. CBRE's work order dispatch
  // emails are styled HTML tables (colored headers, no plain-text alternative), so this
  // prefers a true text/plain part if one exists, but otherwise strips the HTML down to
  // readable text instead of handing back raw markup - the label-based parsing in
  // parseWorkOrderEmail needs plain text like "Description: ..." to match against, not
  // "<td>Description:</td><td>...".
  static Future<String> fetchEmailBody(String messageId) async {
    final token = await _getAccessToken();
    if (token == null) throw Exception('Not connected to Gmail');

    final url = Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId?format=full');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode != 200) {
      throw Exception('Could not read email (${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    final plain = _findMimePart(data['payload'], 'text/plain');
    if (plain != null) return plain;
    final html = _findMimePart(data['payload'], 'text/html');
    if (html != null) return _htmlToPlainText(html);
    return '';
  }

  // Walks the MIME part tree looking for a specific content type (e.g. 'text/plain' or
  // 'text/html') and returns its decoded body, or null if that type isn't present anywhere.
  static String? _findMimePart(Map<String, dynamic>? payload, String mimeType) {
    if (payload == null) return null;
    if (payload['mimeType'] == mimeType && payload['body']?['data'] != null) {
      return _decodeBase64Url(payload['body']['data']);
    }
    final parts = payload['parts'] as List?;
    if (parts != null) {
      for (final part in parts) {
        final found = _findMimePart(Map<String, dynamic>.from(part), mimeType);
        if (found != null) return found;
      }
    }
    return null;
  }

  // Converts HTML email markup into readable plain text: turns block/row/cell boundaries
  // into line breaks or spaces (so table cells like "Description:" and its value don't run
  // together with no separator), strips all remaining tags, and decodes the handful of HTML
  // entities these emails actually use.
  static String _htmlToPlainText(String html) {
    var text = html
        .replaceAll(RegExp(r'<(br|/tr|/p|/div)\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<(td|th)[^>]*>', caseSensitive: false), '  ')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  // Sends a brand-new email through Gmail (compose + send in one call) - this never reads,
  // modifies, or deletes any existing email, it only ever creates a new outgoing one.
  // Requires the gmail.send scope granted above; an account connected before that scope
  // existed won't have it and Gmail's API will reject the request until they Disconnect and
  // Connect again to grant the new permission (Google only adds scopes on fresh consent).
  // threadId/inReplyToMessageId are both optional and only ever set for a work order that
  // came in via Gmail sync (see WorkOrder.gmailThreadId/gmailMessageId) - when present, this
  // sends as a reply inside that original thread instead of a disconnected new email, so it
  // shows up grouped with the original dispatch email in the connected account's own Gmail
  // conversation view. A manually-created work order (no Gmail origin) just sends normally.
  static Future<void> sendEmail({
    required String to,
    String? cc,
    required String subject,
    required String htmlBody,
    List<EmailAttachment> attachments = const [],
    String? threadId,
    String? inReplyToMessageId,
  }) async {
    final token = await _getAccessToken();
    if (token == null) throw Exception('Not connected to Gmail');

    final encodedSubject = '=?UTF-8?B?${base64.encode(utf8.encode(subject))}?=';
    final ccHeader = (cc != null && cc.trim().isNotEmpty) ? 'Cc: ${cc.trim()}\r\n' : '';
    final replyHeaders = (inReplyToMessageId != null && inReplyToMessageId.trim().isNotEmpty)
        ? 'In-Reply-To: ${inReplyToMessageId.trim()}\r\nReferences: ${inReplyToMessageId.trim()}\r\n'
        : '';
    final headerPrefix = 'To: $to\r\n${ccHeader}Subject: $encodedSubject\r\n${replyHeaders}MIME-Version: 1.0\r\n';

    String mime;
    if (attachments.isEmpty) {
      // Unchanged single-part path when there's nothing to attach - zero behavior change
      // for every caller that doesn't need this.
      mime = '$headerPrefix'
          'Content-Type: text/html; charset="UTF-8"\r\n'
          '\r\n'
          '$htmlBody';
    } else {
      final boundary = 'aes_${DateTime.now().microsecondsSinceEpoch}';
      final buffer = StringBuffer()
        ..write(headerPrefix)
        ..write('Content-Type: multipart/mixed; boundary="$boundary"\r\n')
        ..write('\r\n')
        ..write('--$boundary\r\n')
        ..write('Content-Type: text/html; charset="UTF-8"\r\n')
        ..write('\r\n')
        ..write('$htmlBody\r\n');
      for (final attachment in attachments) {
        final encoded = base64.encode(attachment.bytes);
        // RFC 2045 requires base64 body lines wrapped at 76 chars.
        final wrapped = StringBuffer();
        for (int i = 0; i < encoded.length; i += 76) {
          wrapped.writeln(encoded.substring(i, i + 76 > encoded.length ? encoded.length : i + 76));
        }
        buffer
          ..write('--$boundary\r\n')
          ..write('Content-Type: ${attachment.mimeType}; name="${attachment.filename}"\r\n')
          ..write('Content-Disposition: attachment; filename="${attachment.filename}"\r\n')
          ..write('Content-Transfer-Encoding: base64\r\n')
          ..write('\r\n')
          ..write(wrapped.toString())
          ..write('\r\n');
      }
      buffer.write('--$boundary--');
      mime = buffer.toString();
    }
    final raw = base64Url.encode(utf8.encode(mime)).replaceAll('=', '');

    final url = Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send');
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'raw': raw,
        if (threadId != null && threadId.trim().isNotEmpty) 'threadId': threadId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gmail rejected the send request (${response.statusCode}). If this Gmail account was '
        'connected before send permission was added, go to Gmail Sync, click Disconnect, then '
        'Connect with Google again to grant it.',
      );
    }
  }

  // Reads just the subject line and attachment filename - the attachment filename usually
  // contains the real work order number (e.g. "Work Order - 1711386.pdf"), which is reliable
  // to read without needing to open/parse the PDF itself.
  static Future<EmailSummary> fetchEmailSummary(String messageId) async {
    final token = await _getAccessToken();
    if (token == null) throw Exception('Not connected to Gmail');

    final url = Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId?format=full');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode != 200) {
      throw Exception('Could not read email (${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    final headers = (data['payload']?['headers'] as List?) ?? [];
    String subject = '(no subject)';
    String? from;
    String? date;
    String? rfcMessageId;
    for (final h in headers) {
      if (h['name'] == 'Subject') subject = h['value'] ?? subject;
      if (h['name'] == 'From') from = h['value'];
      if (h['name'] == 'Date') date = h['value'];
      // Gmail is consistent about the "Message-ID" casing on outgoing mail, but not every
      // sender's mail server is - checking both common casings rather than one.
      if (h['name'] == 'Message-ID' || h['name'] == 'Message-Id') rfcMessageId = h['value'];
    }

    final parsed = _parseSubjectLine(subject);

    final attachmentName = _findAttachmentFilename(data['payload']);
    // Prefer the WO number parsed from the subject; fall back to the attachment filename.
    String? workOrderNumber = parsed.workOrderNumber;
    if (workOrderNumber == null && attachmentName != null) {
      workOrderNumber = RegExp(r'(\d{5,})').firstMatch(attachmentName)?.group(1);
    }

    return EmailSummary(
      messageId: messageId,
      threadId: data['threadId'] as String?,
      rfcMessageId: rfcMessageId,
      subject: subject,
      attachmentName: attachmentName,
      workOrderNumber: workOrderNumber,
      priority: parsed.priority,
      siteName: parsed.siteName,
      siteCode: parsed.siteCode,
      alertNote: parsed.alertNote,
      from: from,
      date: date,
      // Gmail generates this short plain-text preview itself - cheaper than fetching and
      // stripping the full HTML body just to show a snippet in a list.
      snippet: data['snippet'] as String?,
    );
  }

  // These CBRE-style subject lines pack a lot of structured info into one line, e.g:
  // "Fw: A WAFI ENERGY PAKISTAN Work Order Dispatch, Priority 2:WO 1705711, SHE_06_005,
  //  Alert: High Tension Line &High Risk Confined Space -  WEPL MUMTAZABAD SERVICE STATION 10041129"
  // This pulls out: priority=2, workOrderNumber=1705711, siteCode=SHE_06_005, siteName=WEPL MUMTAZABAD SERVICE STATION
  static _ParsedSubject _parseSubjectLine(String subject) {
    final cleaned = subject.replaceFirst(RegExp(r'^(Re:|Fw:|Fwd:)\s*', caseSensitive: false), '');

    final priorityMatch = RegExp(r'Priority\s*(\d+)\s*:?\s*(?:WO\s*)?(\d{5,7})', caseSensitive: false).firstMatch(cleaned);
    if (priorityMatch == null) {
      // Couldn't find the expected pattern - just try to grab any long number as a fallback
      // WO#. Word boundaries matter here: without them, an 8-digit site ID like "10041129"
      // would match a truncated 7-digit slice of itself ("1004112") instead of correctly
      // failing to match at all, producing a wrong work order number/dedupe key.
      final fallbackNum = RegExp(r'\b(\d{6,7})\b').firstMatch(cleaned)?.group(1);
      return _ParsedSubject(workOrderNumber: fallbackNum, priority: null, siteCode: null, siteName: null);
    }

    final priority = int.tryParse(priorityMatch.group(1)!);
    final woNumber = priorityMatch.group(2);
    final afterMatch = cleaned.substring(priorityMatch.end);

    // Next up should be ", SITE_CODE, <rest>"
    final siteCodeMatch = RegExp(r'^,\s*([A-Z0-9]+_\d+_\d+)\s*,\s*(.*)$').firstMatch(afterMatch);
    String? siteCode;
    String remainder = afterMatch.replaceFirst(RegExp(r'^,\s*'), '');
    if (siteCodeMatch != null) {
      siteCode = siteCodeMatch.group(1);
      remainder = siteCodeMatch.group(2) ?? '';
    }

    // If there's an "Alert: ... - " section, the real site name comes after the last " - ",
    // and the alert text itself (e.g. "High Tension Line & High Risk Confined Space") is useful
    // safety/context info worth keeping for the description.
    String siteSection = remainder;
    String? alertNote;
    if (siteSection.contains(' - ')) {
      final alertMatch = RegExp(r'Alert:\s*(.+)$', caseSensitive: false).firstMatch(siteSection.split(' - ').first);
      alertNote = alertMatch?.group(1)?.trim();
      siteSection = siteSection.split(' - ').last;
    }

    // Strip a trailing numeric site ID (e.g. "...STATION 10041129" -> site name without the number).
    final idMatch = RegExp(r'^(.*?)\s+\d{6,}\s*$').firstMatch(siteSection.trim());
    final siteName = (idMatch?.group(1) ?? siteSection).trim();

    return _ParsedSubject(
      workOrderNumber: woNumber,
      priority: priority,
      siteCode: siteCode,
      siteName: siteName.isEmpty ? null : siteName,
      alertNote: alertNote,
    );
  }

  static String? _findAttachmentFilename(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    if (payload['filename'] != null && (payload['filename'] as String).isNotEmpty) {
      return payload['filename'];
    }
    final parts = payload['parts'] as List?;
    if (parts != null) {
      for (final part in parts) {
        final name = _findAttachmentFilename(Map<String, dynamic>.from(part));
        if (name != null) return name;
      }
    }
    return null;
  }

  static String _decodeBase64Url(String data) {
    final normalized = data.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight((normalized.length + 3) ~/ 4 * 4, '=');
    return utf8.decode(base64.decode(padded));
  }

  // Pulls the labeled fields out of a real CBRE work order email body, e.g.:
  //   Work Order: 1713405              Priority: 2
  //   Description: Monolith PDUs completely off, check power      Work Type: SR
  //   supply and fix, MV lines in the vicinity of work coordinate
  //   with Dealer before visiting for shutdown alignment .
  //   Service: Monolith / Price sign Cosmetic repairs   Status: Approved
  //   Reported Date: 15-Jul-2026 17:45   Target Finish: 21-Jul-2026 13:16
  //   Location: PK4884 - Alert: ... - GULBERG FILLING STATION - 10050896
  //   Service Address: GULBERG FILLING STATION , 437-438 NARWALA ROAD ..., 38000 - PA, FAISALABAD
  // Note there's no separate "Site:" label - the site name is read off the front of Service
  // Address instead (falls back to the subject-line-parsed site name if that's missing too).
  // Description commonly wraps onto a second line before "Work Type:" picks back up, so it's
  // captured across newlines and collapsed back into one clean line.
  static ParsedEmailWorkOrder parseWorkOrderEmail(String body) {
    String? find(RegExp pattern) {
      final match = pattern.firstMatch(body);
      return match?.group(1)?.trim();
    }

    String? clean(String? s) {
      if (s == null) return null;
      final collapsed = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      return collapsed.isEmpty ? null : collapsed;
    }

    final workOrderNumber = find(RegExp(r'Work Order:\s*(\d+)'));
    final priorityStr = find(RegExp(r'Priority:\s*(\d+)'));
    final workType = find(RegExp(r'Work Type:\s*([A-Za-z0-9]+)'));
    final targetDate = find(RegExp(r'Target Finish:\s*(\d{1,2}-[A-Za-z]{3}-\d{4}\s+\d{1,2}:\d{2})'));
    final reportedDate = find(RegExp(r'Reported Date:\s*(\d{1,2}-[A-Za-z]{3}-\d{4}\s+\d{1,2}:\d{2})'));
    final address = clean(find(RegExp(r'Service Address:\s*(.*?)(?:Additional Details:|Telephone number:|Safety Plan|$)', dotAll: true)));
    // When the description is long enough to wrap onto more than one table row, "Work Type:
    // SR" sits interleaved partway through it (right after the first row's worth of text) -
    // e.g. "Description: Monolith PDUs completely off, check power   Work Type: SR\nsupply
    // and fix, MV lines..." - so capturing only up to the first "Work Type:" truncates the
    // description mid-sentence. Instead this captures all the way through to the next real
    // section label (Service:/Status:/Reported Date:), then strips out that interleaved
    // "Work Type: SR" fragment from wherever it landed inside the captured span.
    final descriptionRaw = find(RegExp(r'Description:\s*(.*?)\s*(?:Service:|Status:|Reported Date:)', dotAll: true));
    final description = clean(descriptionRaw?.replaceAll(RegExp(r'Work Type:\s*[A-Za-z0-9]+'), ' '));

    String? siteName;
    if (address != null && address.contains(',')) {
      final firstSegment = address.split(',').first.trim();
      if (firstSegment.isNotEmpty) siteName = firstSegment.toUpperCase();
    }

    return ParsedEmailWorkOrder(
      workOrderNumber: workOrderNumber,
      siteName: siteName,
      address: address ?? '',
      description: description ?? '',
      priority: int.tryParse(priorityStr ?? ''),
      workType: workType,
      targetDate: targetDate,
      reportedDate: reportedDate,
    );
  }

  // Matches a parsed site name against the known sites list to find its region. Falls back
  // to spotting a region/city name directly in the site name or service address text (e.g.
  // "Cantt Road, Multan, PK") when the site isn't already in the known-sites list - this is
  // what lets a brand-new site still get the right region on its very first work order.
  // Strips the client/brand codes CBRE's subject lines and addresses routinely prepend
  // (PREMIUM, WEPL, SPL, HP, NDF, CF) plus all punctuation, so "PREMIUM _ WEPL GHANTA GHAR
  // FILLING STATION" and the already-known site "GHANTA GHAR FILLING STATION" normalize to
  // the same text and match. A raw substring check missed this constantly - varying dashes
  // vs underscores vs spaces around these prefixes meant a site sitting right there in the
  // known-sites list, with its correct region already recorded, was never matched, silently
  // falling back to the 'Multan' default for sites that were actually Lahore/Faisalabad.
  static String _normalizeSiteName(String s) {
    return s
        .toUpperCase()
        .replaceAll(RegExp(r'\b(PREMIUM|WEPL|SPL|HP|NDF|CF)\b'), ' ')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .trim();
  }

  static String? detectRegion(String siteName, List<SiteEntry> knownSites, {String? address}) {
    final normalizedTarget = _normalizeSiteName(siteName);
    if (normalizedTarget.isNotEmpty) {
      for (final site in knownSites) {
        final normalizedKnown = _normalizeSiteName(site.siteName);
        if (normalizedKnown.isEmpty) continue;
        if (normalizedTarget.contains(normalizedKnown) || normalizedKnown.contains(normalizedTarget)) {
          return site.region;
        }
      }
    }
    // Site name substring check - a business/place name is much less likely to accidentally
    // contain another region's name than a full street address is (see below), so a plain
    // substring search here is still safe.
    final upperSiteName = siteName.toUpperCase();
    for (final region in const ['Multan', 'Lahore', 'Faisalabad']) {
      if (upperSiteName.contains(region.toUpperCase())) return region;
    }
    // Address check - only an EXACT comma-segment match, never a substring search over the
    // whole address text. CBRE addresses routinely name a street after a totally different
    // city than the one the site is actually in - e.g. "...SATELLITE TOWN NEAR QAINCHI MORE,
    // SARGODHA, *CMMS, 40210" is a Sargodha site on a street called "Lahore Road", and a plain
    // .contains('LAHORE') on the whole string misfired on exactly that, filing a Sargodha work
    // order under Lahore. A site outside all 3 configured regions (Sargodha, Sahiwal, etc.)
    // now correctly returns null here and falls through to the caller's own per-policy default
    // instead of being guessed into whichever region name happened to appear as a substring
    // anywhere in the address.
    if (address != null) {
      final segments = address.split(',').map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty);
      for (final region in const ['Multan', 'Lahore', 'Faisalabad']) {
        if (segments.contains(region.toUpperCase())) return region;
      }
    }
    return null;
  }
}

// Tries a few date formats CBRE's "Target Finish:" field tends to show up in (plain ISO,
// MM/dd/yyyy with an optional time, or dd-MMM-yyyy with an optional time). Returns null if
// none match, so the caller can fall back to a default deadline instead of crashing.
DateTime? _tryParseEmailDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final cleaned = raw.trim();

  final iso = DateTime.tryParse(cleaned);
  if (iso != null) return iso;

  final slashMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})\s*(AM|PM)?)?', caseSensitive: false).firstMatch(cleaned);
  if (slashMatch != null) {
    final month = int.parse(slashMatch.group(1)!);
    final day = int.parse(slashMatch.group(2)!);
    final year = int.parse(slashMatch.group(3)!);
    int hour = int.tryParse(slashMatch.group(4) ?? '0') ?? 0;
    final minute = int.tryParse(slashMatch.group(5) ?? '0') ?? 0;
    final ampm = slashMatch.group(6)?.toUpperCase();
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  const monthNames = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  final dashMatch = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})(?:\s+(\d{1,2}):(\d{2}))?', caseSensitive: false).firstMatch(cleaned);
  if (dashMatch != null) {
    final month = monthNames[dashMatch.group(2)!.toLowerCase()];
    if (month != null) {
      try {
        return DateTime(
          int.parse(dashMatch.group(3)!),
          month,
          int.parse(dashMatch.group(1)!),
          int.tryParse(dashMatch.group(4) ?? '0') ?? 0,
          int.tryParse(dashMatch.group(5) ?? '0') ?? 0,
        );
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}

// Checks Gmail for new work order emails and creates a work order for each one that isn't
// already in the system, with no review step. Reads the full email body (not just the
// subject line) so the description, address, and target-finish date come from what the
// client actually wrote, and detects the region from the real known-sites list first, then
// from the site name/address text as a fallback - only ever guessing "Lahore" as a last
// resort with nothing else to go on. Shared by the app-wide background poll
// (GmailAutoSyncManager) and the "Check Gmail Now" button, so both paths behave identically.
//
// Emails are checked in small concurrent batches rather than one at a time - each email
// needs 2 network round-trips (summary + body), and doing those fully sequentially made a
// backlog of even 20-30 emails feel frozen with no feedback. onProgress (optional) reports
// how many of the candidate emails have been checked so far, for a UI to show live progress
// instead of a spinner that looks stuck.
Future<({List<WorkOrder> created, List<WorkOrder> updated})> autoSyncGmailWorkOrders({void Function(int done, int total)? onProgress}) async {
  // Every write below needs a signed-in AES app session (separate from the Gmail OAuth
  // connection this whole feature is otherwise about) - if that session had silently expired
  // or dropped, every Firestore write would fail with a bare "permission-denied" that gives
  // no hint why. Surfacing it explicitly here, and forcing a fresh ID token up front, turns
  // a confusing rules-shaped error into an actionable one and rules out a merely-stale token.
  final appUser = FirebaseAuth.instance.currentUser;
  if (appUser == null) {
    throw Exception('You have been signed out of the app. Please log back in, then try again.');
  }
  await appUser.getIdToken(true);

  final ids = await GmailService.findWorkOrderEmailIds();
  final candidates = <(EmailSummary, ParsedEmailWorkOrder?, String?, WorkOrder?)>[];
  const batchSize = 5;
  int done = 0;
  for (int i = 0; i < ids.length; i += batchSize) {
    final batch = ids.skip(i).take(batchSize);
    // Every step for a single email is inside this try/catch - previously fetchEmailSummary
    // sat outside any try/catch, so if even one email out of the whole batch (up to 25)
    // failed for any reason (rate limit, transient network error, malformed message), that
    // single failure aborted the entire run via Future.wait - and since the background
    // auto-sync swallows errors to avoid spamming the UI, that made the whole sync look like
    // it was silently doing nothing. Now one bad email is skipped, not fatal.
    final results = await Future.wait(batch.map((id) async {
      try {
        final summary = await GmailService.fetchEmailSummary(id);
        // Gmail's own internal id (the `id` used to fetch this email) is always present and
        // unique per message, unlike the parsed work-order-number, which depends on the
        // subject line or body matching an expected format and can fail silently. Checking it
        // first means the SAME email can never mint a second work order on a later sync run
        // even when neither the subject nor the body successfully parses a WO#.
        WorkOrder? existing;
        for (final w in sampleWorkOrders) {
          if (w.gmailSourceMessageId == id) {
            existing = w;
            break;
          }
        }
        // Fallback for work orders created before gmailSourceMessageId existed, or in the rare
        // case the same WO# legitimately arrives under a different email id (e.g. resent).
        if (existing == null && summary.workOrderNumber != null) {
          for (final w in sampleWorkOrders) {
            if (w.id == summary.workOrderNumber) {
              existing = w;
              break;
            }
          }
        }
        // A work order already picked up and acted on (anything past "pending" - quoted,
        // approved, completed, etc.) never gets touched again by a later re-dispatch/reminder
        // email for the same WO# - only a still-untouched "pending" one is refreshed with
        // whatever the newer email says, so real staff progress can never be silently
        // overwritten by an automated re-parse.
        if (existing != null && existing.status != WorkOrderStatus.pending) return null;
        ParsedEmailWorkOrder? bodyParsed;
        String? debugNote;
        try {
          final body = await GmailService.fetchEmailBody(id);
          bodyParsed = GmailService.parseWorkOrderEmail(body);
          if (bodyParsed.description.trim().isEmpty) {
            // TEMPORARY DIAGNOSTIC: the label-based regex found nothing in the body text -
            // capture a sample of what the body actually looked like after HTML-stripping so
            // the real format can be seen and the regex corrected, instead of guessing blind.
            final sample = body.length > 500 ? body.substring(0, 500) : body;
            debugNote = 'DEBUG no Description match. Body sample: $sample';
          }
        } catch (e) {
          // TEMPORARY DIAGNOSTIC: body fetch/parse threw - surface why instead of silently
          // falling back, so a real failure can be told apart from "just no regex match".
          debugNote = 'DEBUG body fetch/parse failed: $e';
        }
        // Second chance at matching an existing work order once the body-parsed WO# (if any)
        // is known - the subject line doesn't always carry it, but the body often does under
        // a "Work Order:" label, and previously this case fell through to minting a fresh
        // duplicate id (_nextCustomWorkOrderId()) every single sync run.
        if (existing == null && bodyParsed?.workOrderNumber != null) {
          for (final w in sampleWorkOrders) {
            if (w.id == bodyParsed!.workOrderNumber) {
              existing = w;
              break;
            }
          }
          if (existing != null && existing.status != WorkOrderStatus.pending) return null;
        }
        return (summary, bodyParsed, debugNote, existing);
      } catch (e) {
        GmailAutoSyncManager.lastError = 'Failed to read one email ($id): $e';
        return null;
      }
    }));
    for (final r in results) {
      if (r != null) candidates.add(r);
    }
    done += batch.length;
    onProgress?.call(done, ids.length);
  }

  final created = <WorkOrder>[];
  final updated = <WorkOrder>[];
  for (final entry in candidates) {
    final email = entry.$1;
    final bodyParsed = entry.$2;
    final debugNote = entry.$3;
    final existing = entry.$4;
    final now = DateTime.now();
    // This used to always be "now" (the moment auto-sync happened to process the email)
    // instead of the real "Reported Date:" the client wrote in the email body - meaning
    // every report showed when the work order was picked up by the app, not when the job
    // was actually reported. bodyParsed.reportedDate is already correctly extracted (see
    // parseWorkOrderEmail); it just wasn't being used here. Falls back to "now" only if the
    // email genuinely has no parseable reported date. An update to an existing work order
    // keeps its original reportedDate rather than overwriting it with the reminder email's.
    final reportedDateTime = _tryParseEmailDate(bodyParsed?.reportedDate) ?? now;
    final reportedStr = existing?.reportedDate ?? _formatDateTimeDisplay(reportedDateTime);
    final reportedIso = existing?.reportedDateIso ?? reportedDateTime.toIso8601String();
    final id = existing?.id ?? email.workOrderNumber ?? bodyParsed?.workOrderNumber ?? _nextCustomWorkOrderId();
    // Prefer the subject-line-parsed site name over the address-derived guess (the first
    // comma segment of Service Address) - that guess is only right when the address happens
    // to start with the site name, which isn't reliable (e.g. "JHANG MUZAFFERGARH ROAD
    // MULTAN FAREED TOWN SAHIWAL, ..." is a street description, not the site name "PREMIUM-
    // NIAZ KHAN NIAZI FS" that the subject line correctly identified).
    final siteName = (email.siteName ?? bodyParsed?.siteName ?? email.subject).trim().toUpperCase();
    final address = bodyParsed?.address ?? '';
    final description = (bodyParsed != null && bodyParsed.description.trim().isNotEmpty)
        ? bodyParsed.description.trim()
        : (debugNote ??
            (email.alertNote != null
                ? 'Site note: ${email.alertNote}\n\n(Check the email/attachment in Gmail for the full work description)'
                : email.subject));
    final priority = email.priority ?? bodyParsed?.priority ?? 2;

    // Some sites are in cities outside the 3 configured regions (e.g. Sahiwal) - per company
    // policy those get filed under Multan rather than guessed as Lahore.
    final autoDetectedRegion = GmailService.detectRegion(siteName, sampleSites, address: address);
    final region = autoDetectedRegion ?? existing?.region ?? 'Multan';

    final targetFinish = _tryParseEmailDate(bodyParsed?.targetDate) ?? now.add(const Duration(days: 3));

    if (autoDetectedRegion == null && existing == null) {
      final newSite = SiteEntry(id: 'SITE-${_siteCounter++}', siteName: siteName, region: region);
      sampleSites.add(newSite);
      try {
        await DataService.saveSite(newSite);
      } catch (e) {
        // Not fatal to this work order - it still gets created with the guessed region below,
        // just without a persisted site record backing it yet.
        GmailAutoSyncManager.lastError = 'Failed to save new site $siteName: $e';
      }
    }

    // Rebuilt (rather than mutated) either way, since WorkOrder's core fields are immutable
    // by design - but every field a human/other screen may already have set on an existing
    // pending record (assignment, quotation, notes, photos) is carried forward untouched, so
    // "updating" one only ever refreshes what Gmail actually re-sent, never wipes anything else.
    final workOrder = WorkOrder(
      id: id,
      siteName: siteName,
      address: address,
      region: region,
      priority: priority,
      description: description,
      targetDate: _formatDateTimeDisplay(targetFinish),
      targetDateIso: targetFinish.toIso8601String(),
      reportedDate: reportedStr,
      reportedDateIso: reportedIso,
      status: existing?.status ?? WorkOrderStatus.pending,
      workType: bodyParsed?.workType ?? existing?.workType,
      quotation: existing?.quotation,
      afterPhotoUrls: existing?.afterPhotoUrls,
      rejectionNote: existing?.rejectionNote,
      rejectedByRole: existing?.rejectedByRole,
      assignedEmployeeUsername: existing?.assignedEmployeeUsername,
      employeeNotes: existing?.employeeNotes,
      employeePhotoUrls: existing?.employeePhotoUrls,
      assignedVendorUsername: existing?.assignedVendorUsername,
      completedAt: existing?.completedAt,
      startedAt: existing?.startedAt,
      completionRemarks: existing?.completionRemarks,
      gmailMessageId: email.rfcMessageId ?? existing?.gmailMessageId,
      gmailThreadId: email.threadId ?? existing?.gmailThreadId,
      gmailSourceMessageId: email.messageId,
    );

    // Save to Firestore *before* touching any in-memory list, and per-candidate rather than
    // aborting the whole run - otherwise a single failed write (permission hiccup, transient
    // network error) would both wrongly leave a "phantom" work order in sampleWorkOrders that
    // was never actually persisted, and silently skip every remaining candidate in this batch
    // since the exception would propagate straight out of this loop.
    try {
      await DataService.saveWorkOrder(workOrder);
    } catch (e) {
      GmailAutoSyncManager.lastError = 'Failed to save WO #$id: $e';
      continue;
    }
    if (existing != null) {
      final idx = sampleWorkOrders.indexWhere((w) => w.id == existing.id);
      if (idx != -1) {
        sampleWorkOrders[idx] = workOrder;
      } else {
        sampleWorkOrders.add(workOrder);
      }
      updated.add(workOrder);
    } else {
      sampleWorkOrders.add(workOrder);
      created.add(workOrder);
    }
  }
  return (created: created, updated: updated);
}

// Runs Gmail auto-sync for the whole app session, independent of which screen is open -
// started once Gmail is connected (either a session restored at app-load, or the user just
// connected from the Gmail Sync screen) and keeps polling every 10 minutes for as long as
// the app stays open in a tab. It cannot check Gmail while nobody has the app open at all;
// that would need a paid server-side scheduler instead of this in-app timer.
class GmailAutoSyncManager {
  static Timer? _timer;
  static bool _running = false;

  // Set whenever a background run fails (either the whole run, or one email inside it) -
  // read by the Gmail Sync screen so a silent background failure is never actually silent
  // to whoever opens that screen, even though nothing pops up while it happens.
  static String? lastError;
  static DateTime? lastRunAt;

  // runImmediately=false lets a caller that's about to trigger its own manual check right
  // after (e.g. GmailSyncScreen right after connecting) start the periodic timer without
  // colliding with that manual check - both would otherwise try to run at the same instant,
  // and the manual one would immediately hit the "already running" guard below and fail.
  static Future<void> ensureStarted({bool runImmediately = true}) async {
    if (_timer != null) return;
    if (!GmailService.isConnected) {
      final restored = await GmailService.tryRestoreSession();
      if (!restored) return;
    }
    if (runImmediately) _runOnce();
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _runOnce());
  }

  static Future<void> _runOnce() async {
    if (_running) return;
    _running = true;
    try {
      await autoSyncGmailWorkOrders();
      lastError = null;
    } catch (e) {
      lastError = 'Background sync failed: $e';
    }
    lastRunAt = DateTime.now();
    _running = false;
  }

  // Used by the "Check Gmail Now" button - shares the same _running guard as the background
  // timer, so a manual click and the periodic 30-minute run can never overlap. Without this,
  // both could read the same "not yet created" state for the same email before either
  // finished writing, and both would create a work order for it.
  static Future<({List<WorkOrder> created, List<WorkOrder> updated})> runManualCheck({void Function(int done, int total)? onProgress}) async {
    if (_running) {
      throw Exception('A sync is already running in the background - please wait a moment and try again.');
    }
    _running = true;
    try {
      final result = await autoSyncGmailWorkOrders(onProgress: onProgress);
      lastError = null;
      return result;
    } catch (e) {
      lastError = 'Manual check failed: $e';
      rethrow;
    } finally {
      lastRunAt = DateTime.now();
      _running = false;
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

// Permission rules based on role
