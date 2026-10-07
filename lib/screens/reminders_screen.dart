import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/reminder.dart';
import '../services/eastern_time.dart';

class RemindersScreen extends StatelessWidget {
  static const route = '/reminders';
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final active = app.activeReminders;
    final done =
        app.reminders.where((r) => r.isDone).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (active.isEmpty && done.isEmpty)
            const EmptyState(
                message:
                    'No reminders. Say "remind me to pay rent on the 1st".',
                icon: Icons.alarm_outlined),
          if (active.isNotEmpty) ...[
            const SectionHeader(title: 'Active'),
            ...active.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppTheme.card3D(radius: 18),
                  child: ListTile(
                    leading: const CategoryIcon(
                        category: 'reminder', size: 42),
                    title: Text(r.title,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      DateFormat('EEE, MMM d • h:mm a')
                          .format(r.remindAt),
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.muted),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.deepGreen),
                      onPressed: () =>
                          app.toggleReminder(r.id),
                    ),
                  ),
                )),
          ],
          if (done.isNotEmpty) ...[
            const SectionHeader(title: 'Done'),
            ...done.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppTheme.card3D(radius: 18),
                  child: ListTile(
                    leading: const CategoryIcon(
                        category: 'reminder', size: 42),
                    title: Text(r.title,
                        style: GoogleFonts.poppins(
                            decoration:
                                TextDecoration.lineThrough)),
                    trailing: IconButton(
                      icon: const Icon(Icons.undo_rounded,
                          color: AppColors.muted),
                      onPressed: () =>
                          app.toggleReminder(r.id),
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 8),
          SuggestionCard(
            title: 'Reminder suggestions',
            suggestions: [
              if (active.isNotEmpty)
                'Your next reminder is "${active.first.title}" — I will keep it on your calendar.',
              'Use "every day" for habits: "remind me to drink water every day at 9am".',
            ],
          ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final title = TextEditingController();
    DateTime when = easternNow().add(const Duration(hours: 1));
    String? repeat;
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
              Text('New reminder',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(
                  controller: title, label: 'Remind me to…'),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                    DateFormat('EEE, MMM d • h:mm a')
                        .format(when)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    firstDate: easternNow(),
                    lastDate: easternNow()
                        .add(const Duration(days: 365)),
                    initialDate: when,
                  );
                  if (d == null) return;
                  if (!ctx.mounted) return;
                  final tm = await showTimePicker(
                      context: ctx,
                      initialTime:
                          TimeOfDay.fromDateTime(when));
                  if (tm == null) return;
                  setSheet(() => when = DateTime(d.year, d.month,
                      d.day, tm.hour, tm.minute));
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: repeat,
                decoration: const InputDecoration(
                    labelText: 'Repeat (optional)'),
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('No repeat')),
                  DropdownMenuItem(
                      value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(
                      value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(
                      value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) =>
                    setSheet(() => repeat = v),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Save reminder',
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  final uid =
                      context.read<AppState>().profile?.id ?? '';
                  await context.read<AppState>().addReminder(
                        Reminder(
                          id: const Uuid().v4(),
                          userId: uid,
                          title: title.text.trim(),
                          remindAt: when,
                          repeat: repeat,
                        ),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
