part of '../main.dart';

class PhotoPickerRow extends StatelessWidget {
  final String label;
  final List<String> photos;
  final void Function(String dataUrl) onPhotoAdded;
  final void Function(int index) onRemove;
  final void Function(List<String> dataUrls)? onMultiplePhotosAdded;

  const PhotoPickerRow({
    super.key,
    required this.label,
    required this.photos,
    required this.onPhotoAdded,
    required this.onRemove,
    this.onMultiplePhotosAdded,
  });

  Future<void> _pickMultiple(BuildContext context) async {
    // Tighter compression than a single photo (800x800 @ 55%) since a bulk batch of
    // tens or hundreds of images adds up fast even split across many small Firestore docs.
    final picked = await ImagePicker().pickMultiImage(maxWidth: 800, maxHeight: 800, imageQuality: 55);
    if (picked.isEmpty) return;
    final dataUrls = <String>[];
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';
      dataUrls.add('data:$mimeType;base64,${base64Encode(bytes)}');
    }
    onMultiplePhotosAdded?.call(dataUrls);
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(tr('Add Photo'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AESColors.darkGreen)),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AESColors.primaryGreen),
                title: Text(tr('Take Photo')),
                onTap: () {
                  Navigator.pop(context);
                  pickImageFile(onPhotoAdded, useCamera: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AESColors.primaryGreen),
                title: Text(tr('Choose from Gallery')),
                onTap: () {
                  Navigator.pop(context);
                  pickImageFile(onPhotoAdded, useCamera: false);
                },
              ),
              if (onMultiplePhotosAdded != null)
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AESColors.primaryGreen),
                  title: Text(tr('Choose Multiple (tens or hundreds)')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMultiple(context);
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AESColors.darkGreen)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (int i = 0; i < photos.length; i++)
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => showFullScreenImageViewer(context, photos, initialIndex: i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_decodeDataUrl(photos[i]), width: 90, height: 90, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(3),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            GestureDetector(
              onTap: () => _showSourcePicker(context),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AESColors.lightGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AESColors.grey.withValues(alpha: 0.4), style: BorderStyle.solid),
                ),
                child: const Icon(Icons.add_a_photo_outlined, color: AESColors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LineItemRow {
  final TextEditingController descController = TextEditingController();
  final TextEditingController unitController = TextEditingController(text: 'Job');
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController();
  final TextEditingController internalCostController = TextEditingController(text: '0');
  final TextEditingController remarksController = TextEditingController();
  String cmepStatus = 'Non CMEP';

  double get amount => (double.tryParse(qtyController.text) ?? 0) * (double.tryParse(rateController.text) ?? 0);
  double get internalCost => double.tryParse(internalCostController.text) ?? 0;
}

class _PhotoGallery extends StatelessWidget {
  final String title;
  final List<String> photos;
  const _PhotoGallery({required this.title, required this.photos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < photos.length; i++)
                GestureDetector(
                  onTap: () => showFullScreenImageViewer(context, photos, initialIndex: i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_decodeDataUrl(photos[i]), width: 90, height: 90, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;

  const _DetailSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AESColors.primaryGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AESColors.grey, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AESColors.darkGrey))),
        ],
      ),
    );
  }
}

