import 'package:flutter/material.dart';

/// Google "G" logo - uses official image asset.
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/google_g.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
