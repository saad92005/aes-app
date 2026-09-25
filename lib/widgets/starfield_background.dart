part of '../main.dart';

// ---------------- STARFIELD BACKGROUND ----------------
class _StarfieldPainter extends CustomPainter {
  final List<Offset> stars;
  _StarfieldPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (final s in stars) {
      final dx = s.dx * size.width;
      final dy = s.dy * size.height;
      canvas.drawCircle(Offset(dx, dy), 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<Offset> _generateStars(int count) {
  final rnd = Random(42);
  return List.generate(count, (_) => Offset(rnd.nextDouble(), rnd.nextDouble()));
}

