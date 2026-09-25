part of '../main.dart';

// ---------------- SHARED LINE-ITEM EDITOR (expenses & vendor bills) ----------------
// One draft row: a category (from the shared preset list, or free text via "+ Add new
// item"), a description, and an amount. Used by both the expense-claim and vendor-bill
// submission sheets so multi-item claims/bills share one implementation.
class LineItemDraft {
  final String? id;
  String category;
  bool useCustomCategory;
  final TextEditingController customCategoryController;
  final TextEditingController descController;
  final TextEditingController amountController;

  LineItemDraft({this.id, String category = '', String description = '', String amount = ''})
      : category = category.isNotEmpty && expenseCategories.contains(category) ? category : expenseCategories.first,
        useCustomCategory = category.isNotEmpty && !expenseCategories.contains(category),
        customCategoryController = TextEditingController(text: category.isNotEmpty && !expenseCategories.contains(category) ? category : ''),
        descController = TextEditingController(text: description),
        amountController = TextEditingController(text: amount);

  double get amountValue => double.tryParse(amountController.text.trim()) ?? 0;
  String get resolvedCategory => useCustomCategory ? (customCategoryController.text.trim().isEmpty ? 'Other' : customCategoryController.text.trim()) : category;
}

const String _addNewCategorySentinel = '__add_new_item__';

class LineItemEditorRow extends StatelessWidget {
  final LineItemDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const LineItemEditorRow({super.key, required this.draft, required this.onChanged, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AESColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AESColors.lightGrey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: draft.useCustomCategory
                    ? TextField(
                        controller: draft.customCategoryController,
                        decoration: const InputDecoration(labelText: 'Custom category', border: OutlineInputBorder(), isDense: true),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: draft.category,
                        decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                        items: [
                          ...expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                          DropdownMenuItem(value: _addNewCategorySentinel, child: Text(tr('+ Add new item'))),
                        ],
                        onChanged: (v) {
                          if (v == _addNewCategorySentinel) {
                            draft.useCustomCategory = true;
                          } else {
                            draft.category = v ?? draft.category;
                          }
                          onChanged();
                        },
                      ),
              ),
              if (draft.useCustomCategory)
                IconButton(
                  icon: const Icon(Icons.list, size: 20, color: AESColors.grey),
                  tooltip: 'Choose from list instead',
                  onPressed: () {
                    draft.useCustomCategory = false;
                    onChanged();
                  },
                ),
              if (onRemove != null)
                IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.redAccent), onPressed: onRemove),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.descController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (PKR)', border: OutlineInputBorder(), isDense: true),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

// Small thumbnail that resolves an expense/vendor-bill's receipt photos from the
// PhotoRepo subcollection (plus a legacy embedded photo if this is an old pre-multi-item
// document), shows a count badge if there's more than one, and opens the full-screen
// viewer on tap. Used by both the "my expenses"/"my bills" cards and the
// approval/review cards.
class ReceiptPhotosThumb extends StatelessWidget {
  final String parentCollection;
  final String parentId;
  final String? legacyUrl;
  const ReceiptPhotosThumb({super.key, required this.parentCollection, required this.parentId, this.legacyUrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: PhotoRepo.loadDataUrls(parentCollection, parentId),
      builder: (context, snapshot) {
        final photos = <String>[
          if (legacyUrl != null) legacyUrl!,
          ...(snapshot.data ?? const []),
        ];
        if (photos.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => showFullScreenImageViewer(context, photos),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_decodeDataUrl(photos.first), width: 56, height: 56, fit: BoxFit.cover),
                ),
                if (photos.length > 1)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Text('${photos.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
