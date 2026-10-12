import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/v2_kit.dart';
import '../widgets/add_sheet.dart';

/// V2 Today screen: MORNING / AFTERNOON / EVENING timeline groups with a
/// green dot rail. Items from today's tasks + today's reminders.
/// Tab body — MainTabs provides the Scaffold + bottom nav.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});
  static const route = '/today';

  String _dateLabel() {
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

  int _groupOf(DateTime t) {
    if (t.hour < 12) return 0; // morning
    if (t.hour < 17) return 1; // afternoon
    return 2; // evening
  }

  List<_DayItem> _items(AppState app) {
    final now = DateTime.now();
    final items = <_DayItem>[];
    for (final t in app.todayTasks) {
      items.add(_DayItem(
        id: t.id,
        kind: _Kind.task,
        title: t.title,
        time: t.dueDate,
        isDone: t.isDone,
      ));
    }
    for (final r in app.activeReminders) {
      final d = r.remindAt;
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        items.add(_DayItem(
          id: r.id,
          kind: _Kind.reminder,
          title: r.title,
          time: d,
          isDone: r.isDone,
        ));
      }
    }
    items.sort((a, b) {
      final at = a.time ?? DateTime(now.year, now.month, now.day, 23, 59);
      final bt = b.time ?? DateTime(now.year, now.month, now.day, 23, 59);
      return at.compareTo(bt);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = _items(app);
    final groups = <int, List<_DayItem>>{0: [], 1: [], 2: []};
    for (final i in items) {
      groups[_groupOf(i.time ?? DateTime.now())]!.add(i);
    }

    const groupNames = ['MORNING', 'AFTERNOON', 'EVENING'];

    return SingleChildScrollView(
      padding: v2PagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V2TitleRow(
            title: 'Today',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_dateLabel(), style: V2.sub(15)),
                const SizedBox(width: 12),
                V2AddButton(
                    onTap: () =>
                        showAddSheet(context, initialType: 'task')),
              ],
            ),
          ),
          if (items.isEmpty)
            V2Card(
              child: Row(
                children: [
                  const V2IconTile(Icons.wb_sunny_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('A clear day', style: V2.title(16)),
                        const SizedBox(height: 2),
                        Text('Nothing scheduled for today.',
                            style: V2.sub()),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            for (var g = 0; g < 3; g++)
              if (groups[g]!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: g == 2 ? 0 : 8),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Green dot rail
                        SizedBox(
                          width: 26,
                          child: Column(
                            children: [
                              Container(
                                margin:
                                    const EdgeInsets.only(top: 6),
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: V2.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin:
                                      const EdgeInsets.only(top: 4),
                                  color: V2.green.withOpacity(0.25),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Group label + cards
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 4, bottom: 8),
                                child: Text(
                                  groupNames[g],
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: V2.muted,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              for (final item in groups[g]!) ...[
                                _ItemCard(
                                  item: item,
                                  timeLabel: item.time == null
                                      ? null
                                      : _timeLabel(item.time!),
                                  onToggle: () {
                                    final a = context.read<AppState>();
                                    if (item.kind == _Kind.task) {
                                      a.toggleTask(item.id);
                                    } else {
                                      a.toggleReminder(item.id);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

enum _Kind { task, reminder }

class _DayItem {
  final String id;
  final _Kind kind;
  final String title;
  final DateTime? time;
  final bool isDone;
  _DayItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.time,
    required this.isDone,
  });
}

/// White timeline card: circular toggle icon, title, green time label.
class _ItemCard extends StatelessWidget {
  final _DayItem item;
  final String? timeLabel;
  final VoidCallback onToggle;

  const _ItemCard({
    required this.item,
    required this.timeLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isTask = item.kind == _Kind.task;
    return V2Card(
      onTap: onToggle,
      child: Row(
        children: [
          // Toggle / icon circle
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: item.isDone ? V2.green : V2.chip,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.isDone
                    ? Icons.check_rounded
                    : (isTask
                        ? Icons.check_circle_outline_rounded
                        : Icons.notifications_outlined),
                color: item.isDone ? Colors.white : V2.green,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: item.isDone ? V2.muted : V2.ink,
                decoration:
                    item.isDone ? TextDecoration.lineThrough : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timeLabel != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                timeLabel!,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: V2.green,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
