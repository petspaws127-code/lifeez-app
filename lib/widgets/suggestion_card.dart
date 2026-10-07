import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Contextual AI suggestions card shown on feature screens.
/// Suggestions are generated from the user's real data by the caller.
class SuggestionCard extends StatelessWidget {
  final String title;
  final List<String> suggestions;
  final void Function(String suggestion)? onTap;

  const SuggestionCard({
    super.key,
    required this.title,
    required this.suggestions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: AppTheme.goldGradient(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: AppTheme.tile3D(
                  const [AppColors.deepGreen, AppColors.greenMid],
                  radius: 12,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...suggestions.map(
            (s) => GestureDetector(
              onTap: onTap == null ? null : () => onTap!(s),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 18, color: AppColors.deepGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: GoogleFonts.poppins(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
