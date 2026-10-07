import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';

class _DayEvent {
  final String title;
  final String category;
  final String detail;
  _DayEvent(this.title, this.category, this.detail);
}

class CalendarScreen extends StatefulWidget {
  static const route = '/calendar';
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  Map<DateTime, List<_DayEvent>> _events(AppState app) {
    final map = <DateTime, List<_DayEvent>>{};
    void add(DateTime? d, _DayEvent e) {
      if (d == null) return;
      final key = DateTime(d.year, d.month, d.day);
      map.putIfAbsent(key, () => []).add(e);
    }

    for (final t in app.tasks) {
      add(t.dueDate,
          _DayEvent(t.title, t.category, t.isDone ? 'Done' : 'Task'));
    }
    for (final r in app.reminders) {
      if (!r.isDone) {
        add(r.remindAt,
            _DayEvent(r.title, 'reminder', 'Reminder'));
      }
    }
    for (final b in app.bills) {
      if (!b.paidThisMonth) {
        final day = b.dueDay.clamp(1, 28);
        add(DateTime(_month.year, _month.month, day),
            _DayEvent('${b.name} due', 'bills', 'Bill'));
      }
    }
    for (final d in app.documents) {
      add(d.expiryDate,
          _DayEvent('${d.name} expires', 'document', 'Document'));
    }
    for (final f in app.familyMembers) {
      if (f.birthday != null) {
        add(DateTime(_month.year, _month.month, f.birthday!.day),
            _DayEvent('${f.name}\u2019s birthday', 'family', 'Birthday'));
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final events = _events(app);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday; // Mon=1
    final selectedEvents =
        _selected == null ? <_DayEvent>[] : (events[_selected] ?? []);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => setState(() {
                        _month = DateTime(
                            _month.year, _month.month - 1);
                      }),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => setState(() {
                        _month = DateTime(
                            _month.year, _month.month + 1);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                      fontWeight:
                                          FontWeight.w600)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: daysInMonth + firstWeekday - 1,
                  itemBuilder: (_, i) {
                    if (i < firstWeekday - 1) {
                      return const SizedBox.shrink();
                    }
                    final day = i - firstWeekday + 2;
                    final date =
                        DateTime(_month.year, _month.month, day);
                    final hasEvents = events.containsKey(date);
                    final isSelected = _selected == date;
                    final isToday = date ==
                        DateTime(DateTime.now().year,
                            DateTime.now().month,
                            DateTime.now().day);
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selected = date),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.deepGreen
                              : isToday
                                  ? AppColors.greenSoft
                                  : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                            ),
                            if (hasEvents)
                              Container(
                                margin: const EdgeInsets.only(
                                    top: 2),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.goldLight
                                      : AppColors.gold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionHeader(
              title: _selected == null
                  ? 'Events'
                  : DateFormat('EEEE, MMM d')
                      .format(_selected!)),
          if (selectedEvents.isEmpty)
            const EmptyState(
                message: 'Nothing scheduled this day.',
                icon: Icons.event_outlined)
          else
            ...selectedEvents.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.card3D(radius: 18),
                child: ListTile(
                  leading:
                      CategoryIcon(category: e.category, size: 42),
                  title: Text(e.title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(e.detail,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
