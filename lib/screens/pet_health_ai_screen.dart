import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';

/// Pet Health AI: photo insights, vet records and health tips.
class PetHealthAiScreen extends StatelessWidget {
  static const route = '/pet-health-ai';
  const PetHealthAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final petReminders = app.allPetReminders.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Pets')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              decoration: AppTheme.heroGradient(radius: 24),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CategoryIcon(category: 'pet', size: 54),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'AI health insights for your pet',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upload a photo and get instant wellness tips '
                    'based on visible signs.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A9C63),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Photo analysis coming soon in Pro!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        'Analyze pet photo',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Health summary'),
            _HealthRow(
              icon: 'health',
              label: 'Pet reminders set',
              value: '$petReminders',
            ),
            _HealthRow(
              icon: 'reminder',
              label: 'Vaccinations tracked',
              value: 'In Pets',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A9C63).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CategoryIcon(category: 'brain', size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: yearly vet checkups catch problems early '
                      'and save money long-term.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _HealthRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CategoryIcon(category: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A9C63),
            ),
          ),
        ],
      ),
    );
  }
}
