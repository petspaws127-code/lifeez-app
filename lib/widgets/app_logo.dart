import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Brand logo: speech bubble with a checkmark, as a 3D gradient tile.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 84});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'app-logo',
      child: Container(
        width: size,
        height: size,
        decoration: AppTheme.tile3D(
          const [AppColors.deepGreen, AppColors.greenMid],
          radius: size * 0.3,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.chat_bubble_rounded,
                color: Colors.white.withValues(alpha: 0.95),
                size: size * 0.62),
            Icon(Icons.check_rounded,
                color: AppColors.goldLight, size: size * 0.34),
          ],
        ),
      ),
    );
  }
}
