part of '../main.dart';

// ---------------- FULL-SCREEN IMAGE PREVIEW ----------------
// Shared by every photo thumbnail in the app (work order photos, expense/bill receipts).
// Pinch-to-zoom via InteractiveViewer; swipeable if there's more than one photo.
void showFullScreenImageViewer(BuildContext context, List<String> dataUrls, {int initialIndex = 0}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) => _FullScreenImageViewer(
        dataUrls: dataUrls,
        initialIndex: initialIndex,
      ),
    ),
  );
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> dataUrls;
  final int initialIndex;
  const _FullScreenImageViewer({required this.dataUrls, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _pageController = PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.dataUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.memory(_decodeDataUrl(widget.dataUrls[index]), fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.dataUrls.length > 1)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.dataUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
