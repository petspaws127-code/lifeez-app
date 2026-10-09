import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';

/// Weekly Review: this week's progress across tasks, habits and money.
class WeeklyReviewScreen extends StatelessWidget {
  static const route = '/weekly-review';
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final done = app.completedTasks.length;
    final open = app.openTasks.length;
    final habits = app.habitsDoneToday;
    final spent = app.spentThisMonth;

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Review')),
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
                  Text(
                    'This week',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your progress report',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    done >= open
                        ? 'Great week! You finished more than you left open.'
                        : 'Keep going - $open tasks are still waiting for you.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _StatCard(
                  icon: 'task',
                  label: 'Tasks done',
                  value: '$done',
                ),
                _StatCard(
                  icon: 'habit',
                  label: 'Habits today',
                  value: '$habits',
                ),
                _StatCard(
                  icon: 'money',
                  label: 'Spent (month)',
                  value: '\$${spent.toStringAsFixed(0)}',
                ),
                _StatCard(
                  icon: 'reminder',
                  label: 'Open tasks',
                  value: '$open',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Focus for next week'),
            const EmptyState(
              icon: Icons.flag_outlined,
              message: 'Pick one big goal for next week and add it as a task.',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CategoryIcon(category: icon, size: 40),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A9C63),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
