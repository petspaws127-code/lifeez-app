import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/v2_kit.dart';
import '../widgets/add_sheet.dart';

/// V2 Upcoming screen: day groups (Tomorrow, then dates) with green count
/// badges. Items from future tasks + future reminders.
/// Tab body — MainTabs provides the Scaffold + bottom nav.
class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({super.key});
  static const route = '/upcoming';

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(day.year, day.month, day.day);
    if (d == tomorrow) return 'Tomorrow';
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  String _timeLabel(DateTime? t) {
    if (t == null) return 'All day';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  /// Future-dated items grouped by day, days sorted ascending.
  List<_DayGroup> _groups(AppState app) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDay = <DateTime, List<_FutureItem>>{};

    void add(DateTime when, _FutureItem item) {
      final day = DateTime(when.year, when.month, when.day);
      if (day.isAfter(today)) {
        byDay.putIfAbsent(day, () => []).add(item);
      }
    }

    for (final t in app.upcomingTasks) {
      add(
        t.dueDate ?? DateTime.now().add(const Duration(days: 30)),
        _FutureItem(
          id: t.id,
          kind: _Kind.task,
          title: t.title,
          time: t.dueDate,
          icon: _iconForTask(t.category),
        ),
      );
    }
    for (final r in app.activeReminders) {
      add(
        r.remindAt,
        _FutureItem(
          id: r.id,
          kind: _Kind.reminder,
          title: r.title,
          time: r.remindAt,
          icon: Icons.notifications_outlined,
        ),
      );
    }

    final days = byDay.keys.toList()..sort();
    return days.map((d) {
      final items = byDay[d]!;
      items.sort((a, b) {
        final at = a.time ?? DateTime(d.year, d.month, d.day, 23, 59);
        final bt = b.time ?? DateTime(d.year, d.month, d.day, 23, 59);
        return at.compareTo(bt);
      });
      return _DayGroup(day: d, items: items);
    }).toList();
  }

  IconData _iconForTask(String category) {
    switch (category) {
      case 'grocery':
        return Icons.shopping_cart_outlined;
      case 'health':
        return Icons.favorite_outline_rounded;
      case 'bills':
        return Icons.receipt_long_outlined;
      case 'work':
        return Icons.work_outline_rounded;
      case 'home':
        return Icons.home_outlined;
      case 'event':
        return Icons.event_outlined;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final groups = _groups(app);

    return SingleChildScrollView(
      padding: v2PagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V2TitleRow(
            title: 'Upcoming',
            trailing: V2AddButton(
              onTap: () =>
                  showAddSheet(context, initialType: 'task'),
            ),
          ),
          if (groups.isEmpty)
            V2Card(
              child: Row(
                children: [
                  const V2IconTile(Icons.event_available_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nothing coming up', style: V2.title(16)),
                        const SizedBox(height: 2),
                        Text('Plan something with the + button.',
                            style: V2.sub()),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            for (final g in groups) ...[
              // Day header + green count badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dayLabel(g.day),
                      style: V2.title(19),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: V2.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${g.items.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final item in g.items) ...[
                V2Card(
                  onTap: () {
                    final a = context.read<AppState>();
                    if (item.kind == _Kind.task) {
                      a.toggleTask(item.id);
                    } else {
                      a.toggleReminder(item.id);
                    }
                  },
                  child: Row(
                    children: [
                      V2IconTile(item.icon, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: V2.title(16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _timeLabel(item.time),
                                    style: V2.sub(13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.time != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: V2.muted,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

enum _Kind { task, reminder }

class _DayGroup {
  final DateTime day;
  final List<_FutureItem> items;
  _DayGroup({required this.day, required this.items});
}

class _FutureItem {
  final String id;
  final _Kind kind;
  final String title;
  final DateTime? time;
  final IconData icon;
  _FutureItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.time,
    required this.icon,
  });
}
