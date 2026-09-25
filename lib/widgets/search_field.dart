part of '../main.dart';

// ---------------- SHARED LIST SEARCH FIELD ----------------
// A consistent search box dropped into every list screen (Work Orders, Quotations, Expenses,
// Vendor Bills, Inventory, etc.) right above the existing filter dropdowns - each screen still
// owns its own matching logic (which fields count as a match differs per screen), this widget
// only standardizes the look and the clear-button behavior.
class ListSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const ListSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AESColors.lightGrey),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: AESColors.darkGrey),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 13, color: AESColors.grey),
          prefixIcon: const Icon(Icons.search, size: 20, color: AESColors.grey),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AESColors.grey),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
