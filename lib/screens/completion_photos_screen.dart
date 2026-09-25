part of '../main.dart';

// ---------------- COMPLETION PHOTOS SCREEN ----------------
class CompletionPhotosScreen extends StatefulWidget {
  final WorkOrder workOrder;
  final String currentUsername;
  const CompletionPhotosScreen({super.key, required this.workOrder, required this.currentUsername});

  @override
  State<CompletionPhotosScreen> createState() => _CompletionPhotosScreenState();
}

class _CompletionPhotosScreenState extends State<CompletionPhotosScreen> {
  List<String> _afterPhotos = [];
  bool _loadingPhotos = true;
  late DateTime _completedAt;
  late TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    final existing = widget.workOrder.completedAt != null ? DateTime.tryParse(widget.workOrder.completedAt!) : null;
    _completedAt = existing ?? DateTime.now();
    _remarksController = TextEditingController(text: widget.workOrder.completionRemarks ?? '');
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final photos = await DataService.loadWorkOrderPhotos(widget.workOrder.id, 'after');
    if (mounted) {
      setState(() {
      _afterPhotos = photos;
      _loadingPhotos = false;
    });
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  // null = target date isn't tracked for this work order (created before SLA tracking, or
  // never had a deadline set), so there's nothing to compare against.
  bool? get _wouldMeetSla {
    if (widget.workOrder.targetDateIso == null) return null;
    final target = DateTime.tryParse(widget.workOrder.targetDateIso!);
    if (target == null) return null;
    return !_completedAt.isAfter(target);
  }

  Future<void> _confirmCompletion() async {
    if (_afterPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Please add at least one after-completion photo')), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final previousStatus = widget.workOrder.status;
    final previousCompletedAt = widget.workOrder.completedAt;
    final previousRemarks = widget.workOrder.completionRemarks;
    widget.workOrder.status = WorkOrderStatus.completed;
    widget.workOrder.completedAt = _completedAt.toIso8601String();
    widget.workOrder.completionRemarks = _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim();
    try {
      await DataService.saveWorkOrder(widget.workOrder);
      await DataService.saveWorkOrderPhotos(widget.workOrder.id, 'after', _afterPhotos, widget.currentUsername);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.workOrder.status = previousStatus;
      widget.workOrder.completedAt = previousCompletedAt;
      widget.workOrder.completionRemarks = previousRemarks;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(
        backgroundColor: AESColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Text(tr('Mark as Completed')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WO #${widget.workOrder.id} · ${widget.workOrder.siteName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.darkGreen)),
              const SizedBox(height: 6),
              const Text(
                'Upload photos showing the completed work before marking this order as finished.',
                style: TextStyle(fontSize: 13, color: AESColors.grey),
              ),
              const SizedBox(height: 20),
              if (_loadingPhotos)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else
                PhotoPickerRow(
                  label: 'After Photos',
                  photos: _afterPhotos,
                  onPhotoAdded: (dataUrl) => setState(() => _afterPhotos.add(dataUrl)),
                  onRemove: (i) => setState(() => _afterPhotos.removeAt(i)),
                  onMultiplePhotosAdded: (dataUrls) => setState(() => _afterPhotos.addAll(dataUrls)),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  hintText: 'Any notes about how this work order was closed...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              Text(tr('Job Completion Time'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.darkGreen)),
              const SizedBox(height: 6),
              const Text(
                'When was the work actually finished? This is compared against the Target Finish date to track SLA.',
                style: TextStyle(fontSize: 13, color: AESColors.grey),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await _pickDateTime(context, initial: _completedAt);
                  if (picked != null) setState(() => _completedAt = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Completed at', border: OutlineInputBorder(), isDense: true),
                  child: Text(_formatDateTimeDisplay(_completedAt), style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                ),
              ),
              if (_wouldMeetSla != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _wouldMeetSla! ? AESColors.lightGreen : Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_wouldMeetSla! ? Icons.check_circle_outline : Icons.error_outline,
                          size: 16, color: _wouldMeetSla! ? AESColors.primaryGreen : Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        _wouldMeetSla! ? 'Within SLA (Target: ${widget.workOrder.targetDate})' : 'Non SLA - past target (${widget.workOrder.targetDate})',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _wouldMeetSla! ? AESColors.darkGreen : Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.workOrder.startedAt != null) ...[
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final start = DateTime.tryParse(widget.workOrder.startedAt!);
                  final duration = start == null ? null : _completedAt.difference(start);
                  if (duration == null || duration.isNegative) return const SizedBox.shrink();
                  return Text('Time on job: ${_formatDuration(duration)} (started ${_formatDateTimeDisplay(start!)})',
                      style: const TextStyle(fontSize: 12, color: AESColors.grey));
                }),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _confirmCompletion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AESColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(tr('Confirm Completion')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

