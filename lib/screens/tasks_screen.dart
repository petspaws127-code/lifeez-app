import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_input_bar.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/smart_ai_service.dart';
import '../services/assistant_engine.dart';
import '../models/task_item.dart';
import '../services/eastern_time.dart';

class TasksScreen extends StatelessWidget {
  static const route = '/tasks';
  const TasksScreen({super.key});

  /// Chip label -> TaskItem category value (matches CategoryIcon keys).
  static const Map<String, String> _taskCategories = {
    'Personal': 'general',
    'Work': 'work',
    'Home': 'home',
    'Health': 'health',
    'Shopping': 'shopping',
    'Finance': 'money',
  };

  /// Quick titles that fill the title field with one tap.
  static const List<String> _quickTitles = [
    'Pay a bill',
    'Call back',
    'Buy groceries',
    'Doctor visit',
    'Car service',
  ];

  Future<void> _aiAdd(BuildContext context, String text) async {
    final reply =
        await AssistantEngine(context.read<AppState>()).handleText(text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(reply)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: const TabBar(
            labelColor: AppColors.deepGreen,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.gold,
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: AiInputBar(
                hint: 'AI quick add — "buy milk tomorrow 5pm"',
                onSubmit: (t) => _aiAdd(context, t),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _taskList(context, app.todayTasks, empty: 'Nothing due today.'),
                  _taskList(context, app.upcomingTasks,
                      empty: 'Nothing upcoming. Add something.'),
                  _taskList(context, app.completedTasks,
                      empty: 'No completed tasks yet.'),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddSheet(context),
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }

  Widget _taskList(BuildContext context, List<TaskItem> items,
      {required String empty}) {
    final app = context.read<AppState>();
    if (items.isEmpty) {
      return EmptyState(message: empty, icon: Icons.check_circle_outline);
    }
    return RefreshIndicator(
      onRefresh: () => app.loadAll(),
      child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final t = items[i];
        return Dismissible(
          key: ValueKey(t.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete task?'),
                content: Text('"${t.title}" will be removed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: AppColors.danger))),
                ],
              ),
            );
            return ok ?? false;
          },
          onDismissed: (_) => app.deleteTask(t.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: AppTheme.card3D(radius: 18),
            child: ListTile(
              leading: CategoryIcon(category: t.category, size: 44),
              title: Text(
                t.title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  decoration:
                      t.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: t.dueDate == null
                  ? null
                  : Text(
                      DateFormat('EEE, MMM d • h:mm a')
                          .format(t.dueDate!),
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.muted),
                    ),
              trailing: IconButton(
                icon: Icon(
                  t.isDone
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: t.isDone
                      ? AppColors.whatsappDark
                      : AppColors.deepGreen,
                ),
                onPressed: () {
                  if (!t.isDone) {
                    context.read<SmartAiService>().recordTaskCompleted(
                        DateTime.now(), t.category);
                  }
                  app.toggleTask(t.id);
                },
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final title = TextEditingController();
    DateTime? due;
    String categoryLabel = 'Personal';
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
              Text('New task',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(controller: title, label: 'What needs doing?'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickTitles
                    .map((q) => ActionChip(
                          label: Text(q,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.isDark
                                      ? const Color(0xFF000000)
                                      : AppColors.ink)),
                          backgroundColor: AppTheme.isDark
                              ? const Color(0xFFE8DCC0)
                              : AppColors.goldSoft,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          onPressed: () {
                            title.text = q;
                            title.selection =
                                TextSelection.collapsed(offset: q.length);
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Category',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _taskCategories.keys.map((label) {
                  final selected = categoryLabel == label;
                  return ChoiceChip(
                    label: Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.ink)),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: AppColors.deepGreen,
                    backgroundColor: AppColors.ivoryDeep,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    onSelected: (_) =>
                        setSheet(() => categoryLabel = label),
                  );
                }).toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(due == null
                          ? 'Pick due date'
                          : DateFormat('MMM d, h:mm a').format(due!)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: easternNow(),
                          lastDate: easternNow()
                              .add(const Duration(days: 365)),
                          initialDate: easternNow(),
                        );
                        if (d == null) return;
                        if (!ctx.mounted) return;
                        final tm = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.now());
                        setSheet(() {
                          due = DateTime(d.year, d.month, d.day,
                              tm?.hour ?? 9, tm?.minute ?? 0);
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Add task',
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  final uid =
                      context.read<AppState>().profile?.id ?? '';
                  await context.read<AppState>().addTask(TaskItem(
                        id: const Uuid().v4(),
                        userId: uid,
                        title: title.text.trim(),
                        dueDate: due,
                        category: _taskCategories[categoryLabel] ?? 'general',
                        createdAt: easternNow(),
                      ));
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
