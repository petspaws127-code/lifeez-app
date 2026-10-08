import 'package:flutter/material.dart';

/// Official Google "G" logo with brand colors.
/// Drawn with CustomPainter - no asset needed.
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Google brand colors
    const blue = Color(0xFF4285F4);
    const green = Color(0xFF34A853);
    const yellow = Color(0xFFFBBC05);
    const red = Color(0xFFEA4335);

    final strokeWidth = w * 0.18;
    final radius = w / 2 - strokeWidth / 2;
    final center = Offset(w / 2, h / 2);

    // Helper to draw arc segment
    void drawArc(Color color, double startAngle, double sweepAngle) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Draw the 4 colored segments of the G
    // Blue: top-right arc
    drawArc(blue, -1.55, 1.85);
    // Green: bottom-right arc
    drawArc(green, 0.3, 1.25);
    // Yellow: bottom-left arc
    drawArc(yellow, 1.55, 1.1);
    // Red: top-left arc + horizontal bar
    drawArc(red, 2.65, 1.95);

    // Horizontal bar of the G (blue)
    final barPaint = Paint()
      ..color = blue
      ..style = PaintingStyle.fill;
    final barHeight = strokeWidth;
    final barWidth = radius + strokeWidth * 0.5;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - barHeight / 2,
        barWidth,
        barHeight,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
