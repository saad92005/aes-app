part of '../main.dart';

// ---------------- SITE DETAILS SCREEN ----------------
// Filled in by the assigned employee after visiting the site, before Back Office creates the
// quotation. The description and photos captured here are pulled straight into the quotation
// form so nothing has to be retyped or rephotographed.
class SiteDetailsScreen extends StatefulWidget {
  final WorkOrder workOrder;
  final String currentUsername;
  const SiteDetailsScreen({super.key, required this.workOrder, required this.currentUsername});

  @override
  State<SiteDetailsScreen> createState() => _SiteDetailsScreenState();
}

class _SiteDetailsScreenState extends State<SiteDetailsScreen> {
  late TextEditingController _notesController;
  List<String> _photos = [];
  bool _loadingPhotos = true;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.workOrder.employeeNotes ?? '');
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final photos = await DataService.loadWorkOrderPhotos(widget.workOrder.id, 'employee');
    if (mounted) {
      setState(() {
      _photos = photos;
      _loadingPhotos = false;
    });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Opens a date/time picker rather than just stamping "now" - the employee or vendor may
  // be logging this after the fact, so they need to enter the time work actually started.
  Future<void> _startJob() async {
    final picked = await _pickDateTime(context, initial: DateTime.now());
    if (picked == null) return;
    final previous = widget.workOrder.startedAt;
    setState(() => widget.workOrder.startedAt = picked.toIso8601String());
    try {
      await DataService.saveWorkOrder(widget.workOrder);
    } catch (e) {
      setState(() => widget.workOrder.startedAt = previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Same idea for the finish time - separate from "Mark as Completed", which still requires
  // after-photos and only unlocks once the work order is approved. This just records the
  // real time the job ended, entered by the person who did the work.
  Future<void> _endJob() async {
    final picked = await _pickDateTime(context, initial: DateTime.now());
    if (picked == null) return;
    final previous = widget.workOrder.completedAt;
    setState(() => widget.workOrder.completedAt = picked.toIso8601String());
    try {
      await DataService.saveWorkOrder(widget.workOrder);
    } catch (e) {
      setState(() => widget.workOrder.completedAt = previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Please describe what you found on site')), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final previousNotes = widget.workOrder.employeeNotes;
    widget.workOrder.employeeNotes = _notesController.text.trim();
    try {
      await DataService.saveWorkOrder(widget.workOrder);
      await DataService.saveWorkOrderPhotos(widget.workOrder.id, 'employee', _photos, widget.currentUsername);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.workOrder.employeeNotes = previousNotes;
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
        title: Text(tr('Site Details')),
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
                'Describe what you found on site and add photos - Back Office will use these to build the quotation.',
                style: TextStyle(fontSize: 13, color: AESColors.grey),
              ),
              const SizedBox(height: 16),
              if (widget.workOrder.startedAt == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _startJob,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: Text(tr('Start Job (log arrival time)')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AESColors.primaryGreen,
                      side: const BorderSide(color: AESColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AESColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AESColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text('Started at ${_formatDateTimeDisplay(DateTime.parse(widget.workOrder.startedAt!))}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AESColors.darkGreen)),
                    ],
                  ),
                ),
              if (widget.workOrder.startedAt != null && widget.workOrder.completedAt == null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _endJob,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: Text(tr('End Job (log finish time)')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ] else if (widget.workOrder.completedAt != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.deepOrange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Text('Ended at ${_formatDateTimeDisplay(DateTime.parse(widget.workOrder.completedAt!))}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepOrange)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description of the work',
                  hintText: 'Describe what you found on site, any additional info for Back Office...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              if (_loadingPhotos)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else
                PhotoPickerRow(
                  label: 'Site Photos',
                  photos: _photos,
                  onPhotoAdded: (dataUrl) => setState(() => _photos.add(dataUrl)),
                  onRemove: (i) => setState(() => _photos.removeAt(i)),
                  onMultiplePhotosAdded: (dataUrls) => setState(() => _photos.addAll(dataUrls)),
                ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AESColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(tr('Save Site Details')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

