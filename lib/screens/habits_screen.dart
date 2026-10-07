import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/habit.dart';

/// Habit Tracker — daily habits with check-ins, streaks and weekly progress.
class HabitsScreen extends StatelessWidget {
  static const route = '/habits';
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final habits = app.habits;
    final done = app.habitsDoneToday;

    return Scaffold(
      appBar: AppBar(title: const Text('Habit Tracker')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // Progress header
          Container(
            decoration: AppTheme.heroGradient(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Habits",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '$done/${habits.length} completed',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: habits.isEmpty
                        ? 0
                        : done / habits.length,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                            AppColors.goldLight),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  habits.isEmpty
                      ? 'Add your first habit below.'
                      : '${habits.length - done} left today',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (habits.isEmpty)
            const EmptyState(
                message:
                    'No habits yet. Start small: "Drink water", "Read 10 minutes".',
                icon: Icons.repeat_rounded),
          ...habits.map((h) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.card3D(radius: 18),
                child: ListTile(
                  leading:
                      const CategoryIcon(category: 'habit', size: 42),
                  title: Text(h.title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                  subtitle: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 14, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${h.streak} day streak • ${h.weekCount}/7 this week',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.muted),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.muted),
                        onPressed: () =>
                            _confirmDelete(context, app, h),
                      ),
                      GestureDetector(
                        onTap: () =>
                            app.toggleHabitToday(h.id),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: h.isDoneToday
                                ? AppColors.deepGreen
                                : AppColors.greenSoft,
                          ),
                          child: Icon(
                            h.isDoneToday
                                ? Icons.check_rounded
                                : Icons.circle_outlined,
                            color: h.isDoneToday
                                ? Colors.white
                                : AppColors.deepGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState app, Habit h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${h.title}"?'),
        content: const Text(
            'Its check-in history will be removed too.'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Delete',
                  style:
                      TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) await app.deleteHabit(h.id);
  }

  void _showAddSheet(BuildContext context) {
    final title = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New habit',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Keep it small and daily.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 12),
            AppTextField(
                controller: title,
                label: 'Habit (e.g. Drink water)'),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Add habit',
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                await context.read<AppState>().addHabit(Habit(
                      id: const Uuid().v4(),
                      userId: context
                              .read<AppState>()
                              .profile
                              ?.id ??
                          '',
                      title: title.text.trim(),
                    ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
