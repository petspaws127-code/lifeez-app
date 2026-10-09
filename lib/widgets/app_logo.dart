import 'package:flutter/material.dart';

/// Brand logo: the Lifeez "L" mark (green rounded square, white L).
/// Uses the supplied artwork; falls back gracefully if missing.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = dark ? 'assets/lifeez_logo_dark.png' : 'assets/lifeez_logo.png';
    return Hero(
      tag: 'app-logo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF1A9C63),
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Text(
              'L',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
