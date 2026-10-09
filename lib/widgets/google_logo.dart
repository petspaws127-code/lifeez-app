import 'package:flutter/material.dart';

/// Official Google "G" logo with correct 4 colors.
/// Blue #4285F4, Red #EA4335, Yellow #FBBC05, Green #34A853
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Official Google colors
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);
    
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Simplified G: draw 4 colored arcs
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.42;
    const stroke = 0.18; // relative stroke width
    
    // Blue (top-right arc)
    paint.color = blue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.2, 1.8, false,
      paint..style = PaintingStyle.stroke..strokeWidth = w * stroke,
    );
    
    // Green (bottom-right arc)
    paint.color = green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.6, 1.4, false,
      paint..style = PaintingStyle.stroke..strokeWidth = w * stroke,
    );
    
    // Yellow (bottom-left arc)
    paint.color = yellow;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.0, 1.2, false,
      paint..style = PaintingStyle.stroke..strokeWidth = w * stroke,
    );
    
    // Red (top-left arc + bar)
    paint.color = red;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.2, 1.9, false,
      paint..style = PaintingStyle.stroke..strokeWidth = w * stroke,
    );
    
    // Horizontal bar (blue)
    paint.color = blue;
    paint.style = PaintingStyle.fill;
    final barH = h * 0.14;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx + w * 0.22, center.dy),
          width: w * 0.44,
          height: barH,
        ),
        Radius.circular(barH / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
