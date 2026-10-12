import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/supabase_client.dart';
import '../widgets/v2_kit.dart';
import '../widgets/ai_input_bar.dart';
import '../widgets/add_sheet.dart';
import 'ai_assistant_screen.dart';
import 'tasks_screen.dart';
import 'reminders_screen.dart';
import 'money_screen.dart';
import 'pets_screen.dart';

/// V2 Home dashboard: greeting + streak, hero AI bar, 5 quick-add chips,
/// "Up next" (next 2 items), "Today" progress, "Money glance".
/// Tab body — MainTabs provides the Scaffold + bottom nav.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  /// Display name: Google account name first, then profile name.
  String _displayName(AppState app) {
    String? raw;
    try {
      final user = SupabaseService.client.auth.currentUser;
      raw = user?.userMetadata?['full_name'] as String?;
      raw ??= user?.userMetadata?['name'] as String?;
    } catch (_) {}
    raw ??= app.profile?.name;
    if (raw == null || raw.trim().isEmpty) return 'there';
    final first = raw.trim().split(RegExp(r'\s+')).first;
    return first[0].toUpperCase() + first.substring(1);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning,';
    if (hour >= 12 && hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  String _timeLabel(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  /// Best current habit streak — powers the streak pill.
  int _bestStreak(AppState app) {
    var best = 0;
    for (final h in app.habits) {
      if (h.streak > best) best = h.streak;
    }
    return best;
  }

  /// Next 2 items combining today's open tasks and active reminders,
  /// sorted by time ascending.
  List<_UpNext> _upNext(AppState app) {
    final now = DateTime.now();
    final items = <_UpNext>[];
    for (final t in app.todayTasks) {
      items.add(_UpNext(
        title: t.title,
        time: t.dueDate ?? now,
        isTask: true,
        icon: Icons.check_circle_outline_rounded,
      ));
    }
    for (final r in app.activeReminders) {
      final d = r.remindAt;
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        items.add(_UpNext(
          title: r.title,
          time: d,
          isTask: false,
          icon: Icons.notifications_outlined,
        ));
      }
    }
    items.sort((a, b) => a.time.compareTo(b.time));
    return items.take(2).toList();
  }

  /// (done, total) for tasks due today.
  (int, int) _todayProgress(AppState app) {
    final now = DateTime.now();
    final dueToday =
        app.tasks.where((t) => t.dueDate != null &&
            t.dueDate!.year == now.year &&
            t.dueDate!.month == now.month &&
            t.dueDate!.day == now.day).toList();
    final done = dueToday.where((t) => t.isDone).length;
    return (done, dueToday.length);
  }

  /// Today's spend total + purchase count.
  (double, int) _todaySpend(AppState app) {
    final now = DateTime.now();
    var total = 0.0;
    var count = 0;
    for (final e in app.expenses) {
      final s = e.spentAt;
      if (s.year == now.year && s.month == now.month && s.day == now.day) {
        total += e.amount;
        count++;
      }
    }
    return (total, count);
  }

  String _money(double v, AppState app) {
    final symbol = (app.profile?.currency ?? 'USD') == 'USD' ? '\$' : '';
    return '$symbol${v.toStringAsFixed(2)}';
  }

  Future<void> _submitToAssistant(BuildContext context, String text) async {
    if (!context.mounted) return;
    await Navigator.pushNamed(
      context,
      AiAssistantScreen.route,
      arguments: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = _displayName(app);
    final streak = _bestStreak(app);
    final upNext = _upNext(app);
    final (done, total) = _todayProgress(app);
    final pct = total == 0 ? 0.0 : done / total;
    final (spent, purchaseCount) = _todaySpend(app);

    return SingleChildScrollView(
      padding: v2PagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting header + streak pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: V2.ink,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _greeting(),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: V2.ink,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(_todayLabel(), style: V2.sub(15)),
                  ],
                ),
              ),
              if (streak > 0)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE3C2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day${streak == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8A5A1E),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Hero AI command bar (home mockup: sparkle + mic, green glow)
          AiInputBar(
            onSubmit: (text) => _submitToAssistant(context, text),
            hint: 'Tell it. It remembers it...',
            homeStyle: true,
          ),
          const SizedBox(height: 18),

          // 5 quick-add hint chips
          Row(
            children: [
              _HintChip(
                icon: Icons.list_outlined,
                label: 'Task',
                onTap: () =>
                    showAddSheet(context, initialType: 'task'),
              ),
              _HintChip(
                icon: Icons.notifications_outlined,
                label: 'Reminder',
                onTap: () =>
                    showAddSheet(context, initialType: 'reminder'),
              ),
              _HintChip(
                icon: Icons.check_circle_outline_rounded,
                label: 'Habit',
                onTap: () =>
                    showAddSheet(context, initialType: 'habit'),
              ),
              _HintChip(
                icon: Icons.calendar_month_outlined,
                label: 'Event',
                onTap: () =>
                    showAddSheet(context, initialType: 'event'),
              ),
              _HintChip(
                icon: Icons.alarm_outlined,
                label: 'Alarm',
                onTap: () =>
                    showAddSheet(context, initialType: 'alarm'),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Up next
          Text('Up next', style: V2.title(22)),
          const SizedBox(height: 12),
          if (upNext.isEmpty)
            V2Card(
              child: Row(
                children: [
                  const V2IconTile(Icons.self_improvement_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Nothing scheduled — enjoy the calm.',
                      style: V2.body(),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final item in upNext) ...[
              V2Card(
                onTap: () => Navigator.pushNamed(
                  context,
                  item.isTask ? TasksScreen.route : RemindersScreen.route,
                ),
                child: Row(
                  children: [
                    V2IconTile(item.icon, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: V2.title(16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _timeLabel(item.time),
                            style: V2.sub(14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: V2.muted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 14),

          // Today progress
          Text('Today', style: V2.title(22)),
          const SizedBox(height: 12),
          V2Card(
            onTap: () => Navigator.pushNamed(context, TasksScreen.route),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        total == 0
                            ? 'No tasks due today'
                            : '$done of $total done',
                        style: V2.title(16),
                      ),
                    ),
                    Text(
                      '${(pct * 100).round()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: V2.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                V2ProgressBar(value: pct, height: 10),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Money glance
          Text('Money', style: V2.title(22)),
          const SizedBox(height: 12),
          V2Card(
            onTap: () => Navigator.pushNamed(context, MoneyScreen.route),
            child: Row(
              children: [
                const V2IconTile(Icons.account_balance_wallet_outlined,
                    size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Spent today', style: V2.sub(13)),
                      const SizedBox(height: 2),
                      Text(
                        _money(spent, app),
                        style: V2.title(20),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        purchaseCount == 0
                            ? 'No purchases yet'
                            : '$purchaseCount purchase${purchaseCount == 1 ? '' : 's'}',
                        style: V2.sub(12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: V2.muted),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pets glance
          Text('Pets', style: V2.title(22)),
          const SizedBox(height: 12),
          V2Card(
            onTap: () => Navigator.pushNamed(context, PetsScreen.route),
            child: Row(
              children: [
                const V2IconTile(Icons.pets_outlined, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.pets.isEmpty
                            ? 'No pets yet'
                            : '${app.pets.length} pet${app.pets.length == 1 ? '' : 's'}',
                        style: V2.title(20),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        app.pets.isEmpty
                            ? 'Add your first pet'
                            : app.pets.map((p) => p.name).take(3).join(', '),
                        style: V2.sub(12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: V2.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpNext {
  final String title;
  final DateTime time;
  final bool isTask;
  final IconData icon;
  _UpNext({
    required this.title,
    required this.time,
    required this.isTask,
    required this.icon,
  });
}

/// White rounded-square quick-add chip (Task / Reminder / Habit / Event /
/// Alarm) matching the V2 home mockup.
class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HintChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: V2.softShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFF4B5563), size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: V2.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
