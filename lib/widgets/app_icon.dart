import 'package:flutter/material.dart';

/// Standardized app icon style - matches + sheet design
/// Light green #1a9c63, minimal line icons
class AppIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color = const Color(0xFF1a9c63),
  });

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
  }
}

/// Icon in a light green circle - for feature grids
class AppIconCircle extends StatelessWidget {
  final IconData icon;
  final double circleSize;
  final double iconSize;
  
  const AppIconCircle(
    this.icon, {
    super.key,
    this.circleSize = 56,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        color: const Color(0xFF1a9c63).withOpacity(0.1),
        borderRadius: BorderRadius.circular(circleSize / 3),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF1a9c63),
        size: iconSize,
      ),
    );
  }
}
