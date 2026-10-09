import 'package:flutter/material.dart';

/// Apple logo - white silhouette asset for dark button.
class AppleLogo extends StatelessWidget {
  final double size;
  const AppleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/apple_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
