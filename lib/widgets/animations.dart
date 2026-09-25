part of '../main.dart';

// ---------------- SHARED ANIMATION PRIMITIVES ----------------
// A small, reusable animation vocabulary applied consistently across the app - screen
// transitions, tap feedback, and entrance animations - rather than one-off bespoke
// animations per screen, so the whole app feels like a single consistent piece of software.

// Every Navigator.push/pushReplacement in the app (work order details, add employee, quotation
// forms, etc.) goes through MaterialPageRoute, which reads its transition from the app's
// PageTransitionsTheme - so wiring this once in AlAreshApp's ThemeData animates every screen
// change app-wide with zero changes at each call site.
class _PremiumPageTransitionsBuilder extends PageTransitionsBuilder {
  const _PremiumPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outgoingCurved = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic, reverseCurve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.03, 0)).animate(outgoingCurved),
          child: child,
        ),
      ),
    );
  }
}

final PageTransitionsTheme premiumPageTransitionsTheme = PageTransitionsTheme(
  builders: {for (final platform in TargetPlatform.values) platform: const _PremiumPageTransitionsBuilder()},
);

// Wrap any tappable widget (cards, sidebar tiles, buttons) in this for a subtle press-down
// "squish" - the single most reliable ingredient of a UI reading as premium/responsive rather
// than static. Purely visual: taps still reach [onTap] exactly as a bare GestureDetector would.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const PressableScale({super.key, required this.child, this.onTap, this.scaleDown = 0.96});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// One-shot fade + slide-up entrance, played once as soon as the widget first appears. Pass an
// increasing [index] across a list of these (e.g. dashboard stat cards, module rows) to get a
// staggered cascade instead of everything popping in at once.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 380),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.baseDelay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// Standard cross-fade + slight-scale used for swapping whole screens of content in place
// (e.g. Dashboard's sidebar-driven body, without a real Navigator route change).
Widget animatedContentSwitcher({required Widget child, required Object contentKey}) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    // AnimatedSwitcher's default layoutBuilder stacks children with Alignment.center, which
    // vertically centers any screen shorter than the available height instead of pinning it
    // to the top - every list screen with few/no rows was rendering in the middle of the page
    // with a large empty gap above it. Pin to the top instead.
    layoutBuilder: (currentChild, previousChildren) => Stack(
      alignment: Alignment.topCenter,
      children: [...previousChildren, if (currentChild != null) currentChild],
    ),
    transitionBuilder: (widgetChild, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1.0).animate(animation),
        child: widgetChild,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(contentKey), child: child),
  );
}
