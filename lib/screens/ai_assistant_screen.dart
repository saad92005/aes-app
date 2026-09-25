part of '../main.dart';

// ---------------- AI ASSISTANT SCREEN ----------------
// Calls the Groq API directly (see groqApiKey in main.dart) and, on every message, prepends
// a freshly-computed summary of the app's own live data (_buildAiSystemInstruction below) so
// the model can actually answer factual questions about this company's real
// work orders/quotations/expenses instead of only general knowledge.
//
// Supports multiple named chat sessions (New Chat + a history sidebar, each persisted under
// aiChats/{username}/sessions/{sessionId} in Firestore) and file/image attachments - an
// image is sent to a vision-capable Groq model; a PDF or Excel file has its text extracted
// client-side (syncfusion_flutter_pdf / the existing excel package) and folded into the
// message text instead, since Groq's text models can't read binary documents directly.
class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String text; // shown in the chat bubble
  final String? imageDataUrl; // shown as a thumbnail if present
  // Extracted PDF/Excel text - sent to the API on every turn (so follow-up questions about
  // the file still work) but never rendered in the bubble itself, which only shows `text`.
  final String? fileContext;
  final String? fileName;
  const _ChatMessage({required this.role, required this.text, this.imageDataUrl, this.fileContext, this.fileName});

  Map<String, dynamic> toMap() => {
        'role': role,
        'text': text,
        if (imageDataUrl != null) 'imageDataUrl': imageDataUrl,
        if (fileContext != null) 'fileContext': fileContext,
        if (fileName != null) 'fileName': fileName,
      };

  static _ChatMessage fromMap(Map<String, dynamic> m) => _ChatMessage(
        role: m['role'] ?? 'user',
        text: m['text'] ?? '',
        imageDataUrl: m['imageDataUrl'],
        fileContext: m['fileContext'],
        fileName: m['fileName'],
      );
}

class AiAssistantScreen extends StatefulWidget {
  final AppUser currentUser;
  const AiAssistantScreen({super.key, required this.currentUser});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  List<_ChatMessage> _messages = [];
  String? _currentSessionId;
  String _currentSessionTitle = 'New Chat';
  List<Map<String, dynamic>> _sessions = [];
  bool _loadingSessions = true;
  bool _sending = false;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // Pending attachment, picked but not yet sent.
  String? _pendingImageDataUrl;
  String? _pendingFileContext;
  String? _pendingFileName;
  bool _pickingFile = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _initSpeech();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await DataService.loadAiChatSessions(widget.currentUser.username);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loadingSessions = false;
      });
      if (sessions.isNotEmpty) {
        _openSession(sessions.first);
      } else {
        _startNewChat();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSessions = false);
      _startNewChat();
    }
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = 'SESSION-${DateTime.now().microsecondsSinceEpoch}';
      _currentSessionTitle = 'New Chat';
      _messages = [];
    });
  }

  void _openSession(Map<String, dynamic> session) {
    setState(() {
      _currentSessionId = session['id'];
      _currentSessionTitle = session['title'] ?? 'Chat';
      final rawMessages = (session['messages'] as List? ?? []);
      _messages = rawMessages.map((m) => _ChatMessage.fromMap(Map<String, dynamic>.from(m))).toList();
    });
    _scrollToBottom();
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await DataService.deleteAiChatSession(widget.currentUser.username, sessionId);
      if (!mounted) return;
      setState(() => _sessions.removeWhere((s) => s['id'] == sessionId));
      if (_currentSessionId == sessionId) _startNewChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete chat: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // Best-effort - a failed save shouldn't interrupt the conversation the user is actively
  // having, it just means this exchange won't be there next time they open the sidebar.
  Future<void> _persistCurrentSession() async {
    if (_currentSessionId == null || _messages.isEmpty) return;
    // Auto-titles from the first user message, same idea as most chat apps - only computed
    // once, the first time this session is actually saved.
    if (_currentSessionTitle == 'New Chat') {
      final firstUserText = _messages.firstWhere((m) => m.role == 'user', orElse: () => const _ChatMessage(role: 'user', text: '')).text;
      if (firstUserText.isNotEmpty) {
        _currentSessionTitle = firstUserText.length > 40 ? '${firstUserText.substring(0, 40)}...' : firstUserText;
      }
    }
    final sessionId = _currentSessionId!;
    try {
      await DataService.saveAiChatSession(
        widget.currentUser.username,
        sessionId,
        title: _currentSessionTitle,
        messages: _messages.map((m) => m.toMap()).toList(),
      );
      if (!mounted) return;
      setState(() {
        final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
        final summary = {'id': sessionId, 'title': _currentSessionTitle, 'updatedAt': DateTime.now().toIso8601String()};
        if (idx != -1) {
          _sessions[idx] = summary;
        } else {
          _sessions.insert(0, summary);
        }
      });
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
              _send();
            }
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input isn\'t available on this browser/device'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
        _send();
      }
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _inputController.text = result.recognizedWords;
          _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
        });
      },
      listenOptions: SpeechListenOptions(cancelOnError: true, partialResults: true),
    );
  }

  // Caps how much extracted document text gets sent (and re-sent on every later turn) - a
  // huge PDF/Excel could otherwise blow past the model's context window or make every
  // follow-up message in this chat expensive.
  static const int _maxFileContextChars = 12000;

  Future<void> _pickAndAttachFile() async {
    setState(() => _pickingFile = true);
    try {
      final file = await openFile(acceptedTypeGroups: const [
        XTypeGroup(label: 'attachments', extensions: ['png', 'jpg', 'jpeg', 'pdf', 'xlsx', 'xls']),
      ]);
      if (file == null) {
        setState(() => _pickingFile = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';

      if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        setState(() {
          _pendingImageDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
          _pendingFileContext = null;
          _pendingFileName = file.name;
        });
      } else if (ext == 'xlsx' || ext == 'xls') {
        final workbook = xls.Excel.decodeBytes(bytes);
        final buffer = StringBuffer();
        for (final tableName in workbook.tables.keys) {
          buffer.writeln('Sheet: $tableName');
          for (final row in workbook.tables[tableName]!.rows) {
            buffer.writeln(row.map((c) => c?.value?.toString() ?? '').join(' | '));
          }
        }
        var text = buffer.toString();
        if (text.length > _maxFileContextChars) text = '${text.substring(0, _maxFileContextChars)}\n...(truncated)';
        setState(() {
          _pendingImageDataUrl = null;
          _pendingFileContext = text;
          _pendingFileName = file.name;
        });
      } else if (ext == 'pdf') {
        final document = sf.PdfDocument(inputBytes: bytes);
        var text = sf.PdfTextExtractor(document).extractText();
        document.dispose();
        if (text.length > _maxFileContextChars) text = '${text.substring(0, _maxFileContextChars)}\n...(truncated)';
        setState(() {
          _pendingImageDataUrl = null;
          _pendingFileContext = text;
          _pendingFileName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not read file: $e'), backgroundColor: Colors.redAccent));
      }
    }
    if (mounted) setState(() => _pickingFile = false);
  }

  void _clearAttachment() {
    setState(() {
      _pendingImageDataUrl = null;
      _pendingFileContext = null;
      _pendingFileName = null;
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    final hasAttachment = _pendingImageDataUrl != null || _pendingFileContext != null;
    if (text.isEmpty && !hasAttachment) return;
    if (_sending) return;

    _currentSessionId ??= 'SESSION-${DateTime.now().microsecondsSinceEpoch}';

    setState(() {
      _messages.add(_ChatMessage(
        role: 'user',
        text: text.isEmpty ? '(sent ${_pendingFileName ?? 'a file'})' : text,
        imageDataUrl: _pendingImageDataUrl,
        fileContext: _pendingFileContext,
        fileName: _pendingFileName,
      ));
      _inputController.clear();
      _pendingImageDataUrl = null;
      _pendingFileContext = null;
      _pendingFileName = null;
      _sending = true;
    });
    _scrollToBottom();

    try {
      final systemInstruction = await _buildAiSystemInstruction();
      // Once this session has ever included an image, keep using the vision model for the
      // whole conversation - a plain text model would error on an image_url content part
      // still sitting earlier in the resent history.
      final needsVision = _messages.any((m) => m.imageDataUrl != null);
      final modelToUse = needsVision ? groqVisionModel : groqModel;

      String contentFor(_ChatMessage m) => m.fileContext != null ? '${m.text}\n\n[Attached file "${m.fileName}" content:]\n${m.fileContext}' : m.text;

      final messages = [
        {'role': 'system', 'content': systemInstruction},
        for (final m in _messages)
          if (m.imageDataUrl != null)
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': contentFor(m)},
                {
                  'type': 'image_url',
                  'image_url': {'url': m.imageDataUrl},
                },
              ],
            }
          else
            {'role': m.role == 'user' ? 'user' : 'assistant', 'content': contentFor(m)},
      ];

      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $groqApiKey'},
            body: jsonEncode({'model': modelToUse, 'messages': messages}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        final reply = choices != null && choices.isNotEmpty ? (choices.first['message']?['content'] as String?)?.trim() : null;
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            text: (reply == null || reply.isEmpty) ? "Sorry, I couldn't generate a response." : reply,
          ));
        });
      } else {
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', text: 'Request failed (${response.statusCode}). Please try again.'));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: 'Could not reach the assistant: $e'));
      });
    }
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
    await _persistCurrentSession();
  }

  @override
  Widget build(BuildContext context) {
    if (groqApiKey.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.smart_toy_outlined, color: AESColors.primaryGreen, size: 32),
                const SizedBox(height: 12),
                Text(tr('AI Assistant not set up yet'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
                const SizedBox(height: 8),
                const Text(
                  'Set groqApiKey in lib/main.dart to a GroqCloud API key to turn this on.',
                  style: TextStyle(fontSize: 13, color: AESColors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // A permanent 240px sessions rail works fine on desktop/tablet, but on a ~390px
        // phone it would leave the chat area almost no room at all - so below this
        // breakpoint the sidebar becomes a History bottom sheet reached from the header
        // instead, and the chat area gets the full width.
        final isWide = constraints.maxWidth > 700;
        if (isWide) {
          return Row(
            children: [
              _buildSessionsSidebar(),
              const VerticalDivider(width: 1),
              Expanded(child: _buildChatArea(isWide: true)),
            ],
          );
        }
        return _buildChatArea(isWide: false);
      },
    );
  }

  // Shared between the permanent desktop sidebar and the mobile History bottom sheet so
  // both stay in sync - closeOnSelect dismisses the sheet after picking/starting a chat
  // since it's a temporary overlay there, not a fixture of the layout like the sidebar.
  Widget _buildSessionsListContent({ScrollController? controller, bool closeOnSelect = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: closeOnSelect ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _startNewChat();
                if (closeOnSelect) Navigator.pop(context);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr('New Chat')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AESColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        if (closeOnSelect)
          Flexible(child: _buildSessionsListView(controller: controller, closeOnSelect: closeOnSelect))
        else
          Expanded(child: _buildSessionsListView(controller: controller, closeOnSelect: closeOnSelect)),
      ],
    );
  }

  Widget _buildSessionsListView({ScrollController? controller, bool closeOnSelect = false}) {
    if (_loadingSessions) {
      return const Center(child: CircularProgressIndicator(color: AESColors.primaryGreen, strokeWidth: 2));
    }
    if (_sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(tr('No past chats yet'), style: const TextStyle(fontSize: 12, color: AESColors.grey)),
      );
    }
    return ListView.builder(
      controller: controller,
      shrinkWrap: closeOnSelect,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _sessions.length,
      itemBuilder: (context, i) {
        final session = _sessions[i];
        final selected = session['id'] == _currentSessionId;
        return Material(
          color: selected ? AESColors.lightGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              _openSession(session);
              if (closeOnSelect) Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (session['title'] as String?)?.isNotEmpty == true ? session['title'] : 'Chat',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: selected ? AESColors.darkGreen : AESColors.darkGrey,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _deleteSession(session['id']),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 15, color: AESColors.grey),
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

  Widget _buildSessionsSidebar() {
    return SizedBox(width: 240, child: _buildSessionsListContent());
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => SafeArea(
            child: _buildSessionsListContent(controller: scrollController, closeOnSelect: true),
          ),
        );
      },
    );
  }

  Widget _buildChatArea({required bool isWide}) {
    final horizontalPadding = isWide ? 24.0 : 16.0;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 12),
          child: Row(
            children: [
              if (!isWide)
                IconButton(
                  onPressed: _startNewChat,
                  icon: const Icon(Icons.add_comment_outlined, color: AESColors.primaryGreen),
                  tooltip: 'New Chat',
                  visualDensity: VisualDensity.compact,
                ),
              Expanded(
                child: Text(
                  _currentSessionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isWide ? 24 : 19, fontWeight: FontWeight.bold, color: AESColors.darkGreen),
                ),
              ),
              if (!isWide)
                IconButton(
                  onPressed: _openHistorySheet,
                  icon: const Icon(Icons.history, color: AESColors.primaryGreen),
                  tooltip: 'Past chats',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Ask about market rates for a service, ask it to draft an email, or attach an image/PDF/Excel file to ask about it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AESColors.grey, fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    final isUser = m.role == 'user';
                    return LayoutBuilder(
                      builder: (context, rowConstraints) {
                        // Sized off this row's own available width (not the whole device
                        // width) so bubbles fit correctly whether the desktop sidebar is
                        // present or not, and never blow past a sensible cap on wide screens.
                        final bubbleMaxWidth = min(rowConstraints.maxWidth * 0.82, 480.0);
                        final imageWidth = min(180.0, bubbleMaxWidth - 28);
                        return FadeSlideIn(
                          index: 0,
                          duration: const Duration(milliseconds: 260),
                          child: Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                            decoration: BoxDecoration(
                              color: isUser ? AESColors.primaryGreen : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isUser ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (m.imageDataUrl != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(_decodeDataUrl(m.imageDataUrl!), width: imageWidth, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (m.fileContext != null && m.imageDataUrl == null) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.description_outlined, size: 14, color: isUser ? Colors.white70 : AESColors.grey),
                                      const SizedBox(width: 4),
                                      Text(m.fileName ?? 'file', style: TextStyle(fontSize: 11, color: isUser ? Colors.white70 : AESColors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(m.text, style: TextStyle(color: isUser ? Colors.white : AESColors.darkGrey, fontSize: 14)),
                              ],
                            ),
                          ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        if (_sending)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (_pendingFileName != null)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(_pendingImageDataUrl != null ? Icons.image_outlined : Icons.description_outlined, size: 18),
                label: Text(_pendingFileName!, style: const TextStyle(fontSize: 12)),
                onDeleted: _clearAttachment,
                backgroundColor: AESColors.lightGreen,
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 20),
          child: Row(
            children: [
              PressableScale(
                onTap: _pickingFile ? null : _pickAndAttachFile,
                child: IconButton.filled(
                  onPressed: _pickingFile ? null : _pickAndAttachFile,
                  icon: _pickingFile
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AESColors.primaryGreen))
                      : const Icon(Icons.attach_file),
                  tooltip: 'Attach image, PDF, or Excel file',
                  style: IconButton.styleFrom(backgroundColor: AESColors.lightGreen, foregroundColor: AESColors.primaryGreen),
                ),
              ),
              SizedBox(width: isWide ? 10 : 6),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText: _isListening ? 'Listening...' : 'Ask a question...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              SizedBox(width: isWide ? 10 : 6),
              PressableScale(
                onTap: _toggleListening,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: _isListening ? 1.15 : 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: IconButton.filled(
                    onPressed: _toggleListening,
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    tooltip: _speechAvailable ? 'Voice input' : 'Voice input not available',
                    style: IconButton.styleFrom(
                      backgroundColor: _isListening ? Colors.redAccent : AESColors.lightGreen,
                      foregroundColor: _isListening ? Colors.white : AESColors.primaryGreen,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isWide ? 10 : 6),
              PressableScale(
                onTap: _sending ? null : _send,
                child: IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Builds the system prompt handed to Groq on every message: general instructions plus a
// freshly-computed snapshot of the app's own live data (recomputed on every send, never
// cached, so it can't go stale mid-conversation). This is what lets a question like "how
// many quotations are sent and how many are left" or "how many work orders are assigned to
// xyz" get answered from the company's real numbers instead of only general knowledge -
// there's no live database function-calling here, just a compact, regenerated-every-time
// text summary handed in as context, which is enough for the counting/lookup questions this
// was actually asked for.
Future<String> _buildAiSystemInstruction() async {
  final buffer = StringBuffer()
    ..writeln('You are the AI Assistant inside the AES (Al Areesh Engineering Solutions) internal company app.')
    ..writeln('Answer questions about the company\'s own data using ONLY the live snapshot below - never guess a number.')
    ..writeln('If something isn\'t covered by the snapshot, say so plainly instead of inventing a figure.')
    ..writeln('You can also answer general questions (market rates, drafting text, etc.) using your own knowledge, and can analyze any image/PDF/Excel file attached to a message.')
    ..writeln()
    ..writeln('=== LIVE DATA SNAPSHOT (as of ${_formatDateTimeDisplay(DateTime.now())}) ===');

  final withQuotation = sampleWorkOrders.where((w) => w.quotation != null).toList();
  final sent = withQuotation.where((w) => w.quotation!.sentAt != null).length;
  buffer
    ..writeln()
    ..writeln('QUOTATIONS')
    ..writeln('- Work orders with a quotation drafted: ${withQuotation.length}')
    ..writeln('- Sent to client: $sent')
    ..writeln('- Drafted but not yet sent: ${withQuotation.length - sent}');

  buffer
    ..writeln()
    ..writeln('WORK ORDERS')
    ..writeln('- Total: ${sampleWorkOrders.length}');
  for (final status in WorkOrderStatus.values) {
    buffer.writeln('- ${status.label}: ${sampleWorkOrders.where((w) => w.status == status).length}');
  }
  for (final region in const ['Multan', 'Lahore', 'Faisalabad']) {
    buffer.writeln('- Region $region: ${sampleWorkOrders.where((w) => w.region == region).length}');
  }

  buffer
    ..writeln()
    ..writeln('WORK ORDERS ASSIGNED PER EMPLOYEE');
  try {
    final employees = await AuthService.listEmployees();
    for (final e in employees) {
      final username = e['username'] as String? ?? '';
      if (username.isEmpty) continue;
      final count = sampleWorkOrders.where((w) => w.assignedEmployeeUsername == username || w.assignedVendorUsername == username).length;
      buffer.writeln('- $username (${e['role']}, ${e['region']}): $count');
    }
  } catch (_) {
    buffer.writeln('- (employee list unavailable right now)');
  }

  final pendingExpenses = sampleExpenses.where((e) => e.status == ExpenseStatus.pending).toList();
  final managerApprovedExpenses = sampleExpenses.where((e) => e.status == ExpenseStatus.managerApproved).toList();
  final approvedExpenses = sampleExpenses.where((e) => e.status == ExpenseStatus.approved).toList();
  final rejectedExpenses = sampleExpenses.where((e) => e.status == ExpenseStatus.rejected).toList();
  buffer
    ..writeln()
    ..writeln('EXPENSES (two-stage approval: manager first, then Finance)')
    ..writeln('- Pending manager review: ${pendingExpenses.length} (Rs ${pendingExpenses.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(0)})')
    ..writeln('- Manager approved, awaiting Finance: ${managerApprovedExpenses.length} (Rs ${managerApprovedExpenses.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(0)})')
    ..writeln('- Fully approved: ${approvedExpenses.length} (Rs ${approvedExpenses.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(0)})')
    ..writeln('- Rejected: ${rejectedExpenses.length} (Rs ${rejectedExpenses.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(0)})');

  buffer
    ..writeln()
    ..writeln('LEAVE')
    ..writeln('- Pending requests: ${sampleLeaves.where((l) => l.status == LeaveStatus.pending).length}');

  final today = _todayDateString();
  final todayAttendance = sampleAttendance.where((a) => a.date == today).toList();
  buffer
    ..writeln()
    ..writeln('ATTENDANCE TODAY')
    ..writeln('- Checked in: ${todayAttendance.length}')
    ..writeln('- Late: ${todayAttendance.where((a) => a.isLate).length}');

  buffer
    ..writeln()
    ..writeln('REGIONAL PROFIT & LOSS (revenue from invoices, minus vendor bills, minus approved expenses)');
  for (final region in const ['Multan', 'Lahore', 'Faisalabad']) {
    final revenue = sampleInvoices.where((i) => i.region == region).fold(0.0, (s, i) => s + i.totalAmount);
    final bills = sampleVendorBills.where((b) => b.region == region).fold(0.0, (s, b) => s + b.amount);
    final expenses = sampleExpenses
        .where((e) => e.region == region && e.status == ExpenseStatus.approved)
        .fold(0.0, (s, e) => s + e.amount);
    final profit = revenue - bills - expenses;
    buffer.writeln('- $region: Revenue Rs ${revenue.toStringAsFixed(0)}, Costs Rs ${(bills + expenses).toStringAsFixed(0)}, Profit Rs ${profit.toStringAsFixed(0)}');
  }

  return buffer.toString();
}
