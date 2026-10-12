import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/v2_kit.dart';
import '../widgets/add_sheet.dart';
import '../services/app_state.dart';
import '../services/smart_ai_service.dart';
import '../services/eastern_time.dart';
import '../models/habit.dart';

/// V2 Habits — streak cards with icon tile, green streak pill, M–S day
/// circles (tap today to toggle), and a weekly goal bar.
class HabitsScreen extends StatefulWidget {
  static const route = '/habits';
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  IconData _habitIcon(Habit h) {
    final s = '${h.icon ?? ''} ${h.title}'.toLowerCase();
    if (s.contains('read') || s.contains('book')) {
      return Icons.menu_book_rounded;
    }
    if (s.contains('water') || s.contains('drink')) {
      return Icons.water_drop_rounded;
    }
    if (s.contains('walk') || s.contains('run') || s.contains('gym')) {
      return Icons.directions_walk_rounded;
    }
    if (s.contains('meditat')) return Icons.self_improvement_rounded;
    if (s.contains('sleep')) return Icons.bedtime_rounded;
    if (s.contains('food') || s.contains('eat') || s.contains('diet')) {
      return Icons.restaurant_rounded;
    }
    if (s.contains('code') || s.contains('study') || s.contains('learn')) {
      return Icons.school_rounded;
    }
    return Icons.local_fire_department_rounded;
  }

  void _toggleToday(BuildContext context, Habit h) {
    final wasDone = h.isDoneToday;
    context.read<AppState>().toggleHabitToday(h.id);
    if (!wasDone) {
      context
          .read<SmartAiService>()
          .recordHabitStreak(h.title, h.streak + 1);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState app, Habit h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${h.title}"?'),
        content: const Text(
            'Its check-in history will be removed too.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: V2.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: V2.danger))),
        ],
      ),
    );
    if (ok == true) await app.deleteHabit(h.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final habits = app.habits;
    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: V2.green,
          onRefresh: () => app.loadAll(),
          child: ListView(
            padding: v2PagePadding,
            children: [
              V2TitleRow(
                title: 'Habits',
                trailing: V2AddButton(
                  onTap: () =>
                      showAddSheet(context, initialType: 'habit'),
                ),
              ),
              if (habits.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      const V2IconTile(
                          Icons.local_fire_department_rounded,
                          size: 72),
                      const SizedBox(height: 12),
                      Text('No habits yet',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Start small: "Drink water", "Read 10 minutes".',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: V2.muted),
                      ),
                    ],
                  ),
                )
              else
                ...habits.map((h) => _habitCard(context, app, h)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  Widget _habitCard(BuildContext context, AppState app, Habit h) {
    final week = h.weekCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: V2Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                V2IconTile(_habitIcon(h), size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: V2.chip,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: V2.green),
                            const SizedBox(width: 4),
                            Text(
                              '${h.streak}-day streak',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: V2.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: V2.muted, size: 20),
                  onPressed: () => _confirmDelete(context, app, h),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _dayCircles(context, h),
            const SizedBox(height: 14),
            Text(
              'Weekly goal $week/7',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: V2.ink),
            ),
            const SizedBox(height: 6),
            V2ProgressBar(value: week / 7),
          ],
        ),
      ),
    );
  }

  /// M–S circles for the current week (Mon=1). Done = filled green;
  /// today (not done) = green outline and tappable; future = grey outline.
  Widget _dayCircles(BuildContext context, Habit h) {
    final now = easternNow();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final key = Habit.dayKey(day);
        final done = h.checkins.contains(key);
        final isToday = key == Habit.dayKey(now);
        final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));
        final Color fill;
        final Color ring;
        final Color letter;
        if (done) {
          fill = V2.green;
          ring = V2.green;
          letter = Colors.white;
        } else if (isToday) {
          fill = Colors.transparent;
          ring = V2.green;
          letter = V2.green;
        } else {
          fill = Colors.transparent;
          ring = const Color(0xFFC9C9C4);
          letter = isFuture ? const Color(0xFFC9C9C4) : V2.muted;
        }
        final circle = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: done ? null : Border.all(color: ring, width: 1.6),
          ),
          alignment: Alignment.center,
          child: Text(
            _dayLetters[i],
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: letter),
          ),
        );
        if (!isToday) return circle;
        return InkWell(
          onTap: () => _toggleToday(context, h),
          borderRadius: BorderRadius.circular(20),
          child: circle,
        );
      }),
    );
  }
}
