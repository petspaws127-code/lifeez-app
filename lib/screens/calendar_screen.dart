import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../models/reminder.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';

class _DayEvent {
  final String title;
  final String category;
  final String detail;
  _DayEvent(this.title, this.category, this.detail);
}

class _EventPreset {
  final String label;
  final IconData icon;
  final TimeOfDay defaultTime;
  const _EventPreset(this.label, this.icon, this.defaultTime);
}

const List<_EventPreset> _quickPresets = [
  _EventPreset('Birthday', Icons.cake_rounded, TimeOfDay(hour: 9, minute: 0)),
  _EventPreset('Anniversary', Icons.favorite_rounded, TimeOfDay(hour: 9, minute: 0)),
  _EventPreset('Meeting', Icons.groups_rounded, TimeOfDay(hour: 10, minute: 0)),
  _EventPreset('Doctor Appointment', Icons.medical_services_rounded,
      TimeOfDay(hour: 14, minute: 0)),
  _EventPreset('Bill Due', Icons.receipt_long_rounded, TimeOfDay(hour: 9, minute: 0)),
  _EventPreset('Holiday', Icons.beach_access_rounded, TimeOfDay(hour: 9, minute: 0)),
];

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
    final now = easternNow();
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

  void _showQuickEventSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick event',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Pick a preset to add it as a reminder.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
              ),
              itemCount: _quickPresets.length,
              itemBuilder: (_, i) {
                final p = _quickPresets[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPresetDetailSheet(context, p);
                  },
                  child: Container(
                    decoration: AppTheme.card3D(radius: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(p.icon,
                              color: AppColors.deepGreen),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
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
    );
  }

  void _showPresetDetailSheet(
      BuildContext context, _EventPreset preset) {
    final title = TextEditingController(text: preset.label);
    final now = easternNow();
    DateTime date =
        DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
    TimeOfDay time = preset.defaultTime;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
              Text(preset.label,
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(
                  controller: title, label: 'Event title'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon:
                          const Icon(Icons.calendar_month_outlined),
                      label: Text(DateFormat('MMM d, yyyy').format(date)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(
                              now.year, now.month, now.day),
                          lastDate: easternNow().add(
                              const Duration(days: 730)),
                        );
                        if (d == null) return;
                        setSheet(() => date = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(time.format(ctx)),
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: ctx, initialTime: time);
                        if (t == null) return;
                        setSheet(() => time = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Save',
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final remindAt = DateTime(date.year, date.month,
                      date.day, time.hour, time.minute);
                  final uid =
                      context.read<AppState>().profile?.id ?? '';
                  await context.read<AppState>().addReminder(
                        Reminder(
                          id: const Uuid().v4(),
                          userId: uid,
                          title: title.text.trim(),
                          remindAt: remindAt,
                        ),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  setState(() {
                    _selected =
                        DateTime(date.year, date.month, date.day);
                    _month = DateTime(date.year, date.month);
                  });
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(
                            'Reminder set for ${DateFormat('MMM d, h:mm a').format(remindAt)}')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add event',
        onPressed: () => _showQuickEventSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
                        DateTime(easternNow().year,
                            easternNow().month,
                            easternNow().day);
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
      ),
    );
  }
}
