part of '../main.dart';

// ---------------- GMAIL SYNC SCREEN ----------------
class GmailSyncScreen extends StatefulWidget {
  const GmailSyncScreen({super.key});

  @override
  State<GmailSyncScreen> createState() => _GmailSyncScreenState();
}

class _GmailSyncScreenState extends State<GmailSyncScreen> {
  bool _connected = false;
  bool _restoringSession = true;
  bool _checking = false;
  String? _statusMessage;
  List<WorkOrder> _recentlyCreated = [];
  List<WorkOrder> _recentlyUpdated = [];
  List<EmailSummary> _matchedEmails = [];
  Timer? _backgroundStatusTimer;

  @override
  void initState() {
    super.initState();
    _restoreSession();
    // The background auto-sync timer runs independently of this screen and updates
    // GmailAutoSyncManager.lastError/lastRunAt directly - this just periodically re-renders
    // so those changes actually show up here instead of only being visible after manually
    // pressing Refresh.
    _backgroundStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _backgroundStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    if (GmailService.isConnected) {
      setState(() {
        _connected = true;
        _restoringSession = false;
      });
      GmailAutoSyncManager.ensureStarted();
      return;
    }
    final restored = await GmailService.tryRestoreSession();
    if (mounted) {
      setState(() {
        _connected = restored;
        _restoringSession = false;
      });
      if (restored) GmailAutoSyncManager.ensureStarted();
    }
  }

  Future<void> _connect() async {
    setState(() => _statusMessage = null);
    try {
      final account = await GmailService.connect();
      setState(() => _connected = account != null);
      if (account != null) {
        GmailAutoSyncManager.ensureStarted(runImmediately: false);
        _refresh();
      }
    } catch (e) {
      setState(() => _statusMessage = 'Could not connect: $e');
    }
  }

  Future<void> _disconnect() async {
    GmailAutoSyncManager.stop();
    await GmailService.disconnect();
    setState(() {
      _connected = false;
      _recentlyCreated = [];
      _recentlyUpdated = [];
      _matchedEmails = [];
      _statusMessage = null;
    });
  }

  // One button does everything: runs the same auto-sync check the background timer runs
  // (so a work order created here is created exactly the same way as one created
  // automatically), and also fetches the matching emails themselves so they're visible in
  // this screen rather than only ever seeing the resulting work orders.
  Future<void> _refresh() async {
    // A stale error from an earlier background run (up to 10 minutes old) otherwise stays
    // pinned above the "Checking Gmail..." spinner for the whole duration of a brand new
    // check, making a fresh attempt look like it's failing before it's even finished.
    GmailAutoSyncManager.lastError = null;
    setState(() {
      _checking = true;
      _statusMessage = 'Checking Gmail...';
    });
    try {
      final createdOrdersFuture = GmailAutoSyncManager.runManualCheck(
        onProgress: (done, total) {
          if (mounted) setState(() => _statusMessage = 'Checking Gmail... ($done of $total emails)');
        },
      );
      final ids = await GmailService.findWorkOrderEmailIds();
      final summaries = <EmailSummary>[];
      for (final id in ids) {
        try {
          summaries.add(await GmailService.fetchEmailSummary(id));
        } catch (_) {
          // Skip any single email that fails to fetch rather than aborting the whole refresh.
        }
      }
      final result = await createdOrdersFuture;
      final createdOrders = result.created;
      final updatedOrders = result.updated;
      if (mounted) {
        setState(() {
          _recentlyCreated = [...createdOrders, ..._recentlyCreated].take(10).toList();
          _recentlyUpdated = [...updatedOrders, ..._recentlyUpdated].take(10).toList();
          _matchedEmails = summaries;
          final parts = <String>[
            if (createdOrders.isNotEmpty) '${createdOrders.length} created',
            if (updatedOrders.isNotEmpty) '${updatedOrders.length} updated',
          ];
          _statusMessage = parts.isEmpty
              ? 'No new or updated work order emails found'
              : '${parts.join(', ')} from ${summaries.length} matching email${summaries.length == 1 ? '' : 's'} (last 3 weeks)';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Check failed: $e');
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gmail Sync', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
            const SizedBox(height: 4),
            const Text(
              'Once connected, new work order emails are turned into work orders automatically - press Refresh any time to check now and see the matching emails.',
              style: TextStyle(color: AESColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_restoringSession)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AESColors.grey))
                      else
                        Icon(_connected ? Icons.check_circle : Icons.circle_outlined, color: _connected ? AESColors.primaryGreen : AESColors.grey),
                      const SizedBox(width: 10),
                      Text(
                        _restoringSession ? 'Checking connection...' : (_connected ? 'Connected - auto-sync is running' : 'Not connected'),
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _connected ? AESColors.primaryGreen : AESColors.darkGrey),
                      ),
                    ],
                  ),
                  if (_connected && GmailService.currentAccount != null) ...[
                    const SizedBox(height: 4),
                    Text(GmailService.currentAccount!.email, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                  ],
                  if (_connected && GmailAutoSyncManager.lastRunAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last background check: ${_formatDateTimeDisplay(GmailAutoSyncManager.lastRunAt!)}',
                      style: const TextStyle(fontSize: 12, color: AESColors.grey),
                    ),
                  ],
                  if (_connected && GmailAutoSyncManager.lastError != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error, size: 14, color: Color(0xFFE34948)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            GmailAutoSyncManager.lastError!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFE34948)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!_restoringSession && _connected)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      // Once connected, this is the only primary action on the whole screen -
                      // a single Refresh button, rather than a separate "Check Gmail Now" plus
                      // a connect/disconnect card competing for attention.
                      child: ElevatedButton.icon(
                        onPressed: _checking ? null : _refresh,
                        icon: _checking
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh, size: 20),
                        label: Text(_checking ? 'Checking Gmail...' : 'Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AESColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    )
                  else if (!_restoringSession)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _connect,
                        icon: const Icon(Icons.login, size: 18),
                        label: Text(tr('Connect with Google')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AESColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (_connected) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _disconnect,
                        child: Text(tr('Disconnect'), style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AESColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                child: Text(_statusMessage!, style: const TextStyle(fontSize: 13, color: AESColors.darkGreen)),
              ),
            ],
            if (_matchedEmails.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Matching Emails (${_matchedEmails.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
              const SizedBox(height: 10),
              ..._matchedEmails.map((email) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email.subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AESColors.darkGrey)),
                        const SizedBox(height: 4),
                        if (email.from != null)
                          Text(email.from!, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                        if (email.date != null)
                          Text(email.date!, style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                        if (email.snippet != null && email.snippet!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(email.snippet!, style: const TextStyle(fontSize: 12, color: AESColors.darkGrey), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  )),
            ],
            if (_recentlyCreated.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(tr('Recently Auto-Created'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
              const SizedBox(height: 10),
              ..._recentlyCreated.map((wo) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 18, color: AESColors.primaryGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WO #${wo.id} - ${wo.siteName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AESColors.darkGrey)),
                              Text(wo.region, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            if (_recentlyUpdated.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(tr('Recently Updated'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
              const SizedBox(height: 10),
              ..._recentlyUpdated.map((wo) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync, size: 18, color: AESColors.primaryGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WO #${wo.id} - ${wo.siteName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AESColors.darkGrey)),
                              Text(wo.region, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
