import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/task_item.dart';
import '../models/reminder.dart';
import '../models/habit.dart';
import '../models/alarm.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../services/supabase_client.dart';
import 'v2_kit.dart';

/// Shared V2 "Add new" bottom sheet (matches the approved mockup):
/// 5 type pills (Task / Reminder / Habit / Event / Alarm), input,
/// Date & time row, Repeat row, green Save button.
///
/// [initialType] preselects the type pill: 'task' | 'reminder' | 'habit' |
/// 'event' | 'alarm'. Defaults to 'task'.
void showAddSheet(BuildContext context, {String initialType = 'task'}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _AddSheet(initialType: initialType),
  );
}

class _AddSheet extends StatefulWidget {
  final String initialType;
  const _AddSheet({required this.initialType});

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _TypeDef {
  final String key;
  final String label;
  final IconData icon;
  const _TypeDef(this.key, this.label, this.icon);
}

class _AddSheetState extends State<_AddSheet> {
  static const _types = [
    _TypeDef('task', 'Task', Icons.list_rounded),
    _TypeDef('reminder', 'Reminder', Icons.notifications_outlined),
    _TypeDef('habit', 'Habit', Icons.repeat_rounded),
    _TypeDef('event', 'Event', Icons.calendar_month_outlined),
    _TypeDef('alarm', 'Alarm', Icons.alarm_outlined),
  ];
  static const _repeats = ['Never', 'Daily', 'Weekly', 'Monthly'];

  late String _type;
  final _titleCtrl = TextEditingController();
  late DateTime _dateTime;
  String _repeat = 'Never';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = _types.any((t) => t.key == widget.initialType)
        ? widget.initialType
        : 'task';
    // Default: today at 5:00 PM (matches the mockup). If that's already
    // past, use tomorrow at the same time so reminders/alarms schedule.
    final now = easternNow();
    var dt = DateTime(now.year, now.month, now.day, 17, 0);
    if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
    _dateTime = dt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String get _typeLabel =>
      _types.firstWhere((t) => t.key == _type).label;

  /// "Today, 5:00 PM" / "Tomorrow, 9:00 AM" / "Oct 15, 5:00 PM".
  String _dateLabel() {
    final now = easternNow();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(_dateTime.year, _dateTime.month, _dateTime.day);
    final String dayStr;
    if (day == today) {
      dayStr = 'Today';
    } else if (day == today.add(const Duration(days: 1))) {
      dayStr = 'Tomorrow';
    } else {
      dayStr = DateFormat('MMM d').format(_dateTime);
    }
    return '$dayStr, ${DateFormat('h:mm a').format(_dateTime)}';
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: V2.green),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: V2.green),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickRepeat() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Repeat', style: V2.title()),
        contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _repeats
              .map(
                (r) => ListTile(
                  title: Text(r, style: V2.body()),
                  trailing: _repeat == r
                      ? const Icon(Icons.check_rounded, color: V2.green)
                      : null,
                  onTap: () => Navigator.pop(ctx, r),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) setState(() => _repeat = picked);
  }

  List<int> _alarmRepeatDays() {
    switch (_repeat) {
      case 'Daily':
        return [1, 2, 3, 4, 5, 6, 7];
      case 'Weekly':
        return [_dateTime.weekday];
      default:
        return []; // Never / Monthly -> once
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final app = context.read<AppState>();
      final uid = SupabaseService.currentUserId ?? 'local';
      final repeatValue =
          _repeat == 'Never' ? null : _repeat.toLowerCase();
      final id = const Uuid().v4();
      switch (_type) {
        case 'task':
          await app.addTask(TaskItem(
            id: id,
            userId: uid,
            title: title,
            dueDate: _dateTime,
            repeat: repeatValue,
            createdAt: easternNow(),
          ));
          break;
        case 'event':
          await app.addTask(TaskItem(
            id: id,
            userId: uid,
            title: title,
            category: 'event',
            dueDate: _dateTime,
            repeat: repeatValue,
            createdAt: easternNow(),
          ));
          break;
        case 'reminder':
          await app.addReminder(Reminder(
            id: id,
            userId: uid,
            title: title,
            remindAt: _dateTime,
            repeat: repeatValue,
          ));
          break;
        case 'habit':
          await app.addHabit(Habit(
            id: id,
            userId: uid,
            title: title,
          ));
          break;
        case 'alarm':
          await app.addAlarm(Alarm(
            label: title,
            hour: _dateTime.hour,
            minute: _dateTime.minute,
            repeatDays: _alarmRepeatDays(),
          ));
          break;
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_typeLabel added.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Title + close
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add new',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: V2.ink,
                      height: 1.15,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F1F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 20, color: Color(0xFF8A8A8A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Type pills
            Row(
              children: [
                for (final t in _types)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: t == _types.last ? 0 : 8,
                      ),
                      child: _typePill(t),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Title input
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: TextField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                style: GoogleFonts.poppins(
                    fontSize: 15, color: V2.ink),
                decoration: InputDecoration(
                  hintText: 'What do you want to add?',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 15, color: const Color(0xFF9A9A9A)),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.edit_outlined,
                        color: Color(0xFF9A9A9A), size: 22),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Date & time row
            _optionRow(
              icon: Icons.calendar_month_outlined,
              title: 'Date & time',
              subtitle: _dateLabel(),
              onTap: _pickDateTime,
            ),
            // Repeat row
            _optionRow(
              icon: Icons.repeat_rounded,
              title: 'Repeat',
              subtitle: _repeat,
              onTap: _pickRepeat,
            ),
            const SizedBox(height: 12),
            // Save
            V2PrimaryButton(
              label: _saving ? 'Saving…' : 'Save',
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _typePill(_TypeDef t) {
    final selected = _type == t.key;
    return GestureDetector(
      onTap: () => setState(() => _type = t.key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? V2.green : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              t.icon,
              color: selected ? Colors.white : const Color(0xFF2B2B2B),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              t.label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF2B2B2B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: V2.chip,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: V2.ink, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: V2.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: V2.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF9A9A9A), size: 28),
          ],
        ),
      ),
    );
  }
}
