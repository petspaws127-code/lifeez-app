import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/v2_kit.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';

class _CalEvent {
  final String title;
  final String detail;
  final IconData icon;
  final DateTime sortKey;
  _CalEvent(this.title, this.detail, this.icon, this.sortKey);
}

/// V2 Calendar — dynamic month grid with green event dots, selected-day
/// highlight, and "Selected day" agenda cards below.
class CalendarScreen extends StatefulWidget {
  static const route = '/calendar';
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = easternNow();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// All event days in the currently displayed month -> list of events.
  Map<DateTime, List<_CalEvent>> _events(AppState app) {
    final map = <DateTime, List<_CalEvent>>{};
    void add(DateTime? d, _CalEvent e) {
      if (d == null) return;
      if (d.year != _month.year || d.month != _month.month) return;
      final key = _dayKey(d);
      map.putIfAbsent(key, () => []).add(e);
    }

    for (final t in app.tasks) {
      final d = t.dueDate;
      if (d == null) continue;
      add(
        d,
        _CalEvent(
          t.title,
          'Task${t.isDone ? ' • Done' : ''}${_timeSuffix(d)}',
          Icons.check_circle_outline_rounded,
          d,
        ),
      );
    }
    for (final r in app.activeReminders) {
      final d = r.remindAt;
      add(
        d,
        _CalEvent(
          r.title,
          'Reminder${r.petId != null ? ' • Pet' : ''}${_timeSuffix(d)}',
          Icons.notifications_none_rounded,
          d,
        ),
      );
    }
    for (final a in app.alarms) {
      if (!a.enabled) continue;
      if (a.repeatDays.isEmpty) {
        final next = a.nextFire();
        if (next.year == _month.year && next.month == _month.month) {
          add(
            next,
            _CalEvent(
              a.label,
              'Alarm • ${a.timeLabel}',
              Icons.alarm_rounded,
              next,
            ),
          );
        }
      } else {
        final daysInMonth =
            DateTime(_month.year, _month.month + 1, 0).day;
        for (var day = 1; day <= daysInMonth; day++) {
          final d = DateTime(_month.year, _month.month, day);
          if (a.repeatDays.contains(d.weekday)) {
            final fire =
                DateTime(d.year, d.month, d.day, a.hour, a.minute);
            add(
              fire,
              _CalEvent(
                a.label,
                'Alarm • ${a.timeLabel}',
                Icons.alarm_rounded,
                fire,
              ),
            );
          }
        }
      }
    }
    for (final list in map.values) {
      list.sort((x, y) => x.sortKey.compareTo(y.sortKey));
    }
    return map;
  }

  String _timeSuffix(DateTime d) {
    if (d.hour == 0 && d.minute == 0) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return ' • $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final daysInMonth =
          DateTime(_month.year, _month.month + 1, 0).day;
      final day = _selected.day.clamp(1, daysInMonth);
      _selected = DateTime(_month.year, _month.month, day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final events = _events(app);
    final selectedEvents = events[_dayKey(_selected)] ?? const <_CalEvent>[];

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
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lifeez',
                        style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: V2.ink)),
                    Text('life-management',
                        style: GoogleFonts.poppins(
                            fontSize: 11.5, color: V2.muted)),
                  ],
                ),
              ),
              // Mockup has no + button on this screen.
              const V2TitleRow(title: 'Calendar'),
              V2Card(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded,
                              color: V2.muted),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_month),
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded,
                              color: V2.muted),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                          .map((d) => Expanded(
                                child: Center(child: _weekdayLetter(d)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    _monthGrid(events),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Mockup: "Selected day" in normal case (not uppercase).
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Selected day', style: V2.title(20)),
              ),
              if (selectedEvents.isEmpty)
                V2Card(
                  child: Row(
                    children: [
                      const V2IconTile(
                          Icons.event_available_rounded,
                          size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nothing scheduled on ${DateFormat('MMM d').format(_selected)}.',
                          style: GoogleFonts.poppins(
                              fontSize: 13.5, color: V2.muted),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...selectedEvents.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: V2Card(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            V2IconTile(e.icon,
                                size: 48,
                                bg: V2.green,
                                fg: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    e.detail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        color: V2.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  Widget _weekdayLetter(String d) => Text(
        d,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w500, color: V2.muted),
      );

  /// Sunday-first month grid. Days with events get a green dot;
  /// the selected day gets a filled green circle.
  Widget _monthGrid(Map<DateTime, List<_CalEvent>> events) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Sunday-first offset: DateTime.weekday Mon=1..Sun=7.
    final offset = DateTime(_month.year, _month.month, 1).weekday % 7;
    final today = _dayKey(easternNow());
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.95,
      ),
      itemCount: daysInMonth + offset,
      itemBuilder: (_, i) {
        if (i < offset) return const SizedBox.shrink();
        final day = i - offset + 1;
        final date = DateTime(_month.year, _month.month, day);
        final key = _dayKey(date);
        final hasEvents = events.containsKey(key);
        final isSelected = key == _dayKey(_selected);
        final isToday = key == today;
        return GestureDetector(
          onTap: () => setState(() => _selected = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? V2.green
                        : isToday
                            ? V2.chip
                            : Colors.transparent,
                  ),
                  child: Text(
                    '$day',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? V2.green
                              : V2.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        hasEvents ? V2.green : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
