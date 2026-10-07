import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/brain_dump.dart';
import '../models/task_item.dart';
import 'tasks_screen.dart';
import '../services/eastern_time.dart';

/// My Day — daily briefing plus a quick brain-dump inbox.
/// Dump thoughts fast; convert any of them into a task later.
class MyDayScreen extends StatefulWidget {
  static const route = '/my-day';
  const MyDayScreen({super.key});

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  final _dump = TextEditingController();

  @override
  void dispose() {
    _dump.dispose();
    super.dispose();
  }

  Future<void> _quickDump() async {
    final text = _dump.text.trim();
    if (text.isEmpty) return;
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final focus = FocusScope.of(context);
    await app.addBrainDump(BrainDump(
      id: const Uuid().v4(),
      userId: app.profile?.id ?? '',
      text: text,
      createdAt: easternNow(),
    ));
    _dump.clear();
    focus.unfocus();
    messenger.showSnackBar(
      const SnackBar(content: Text('Thought dumped.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final open = app.openBrainDumps;
    final attention = app.todayTasks.length +
        app.unpaidBills.length +
        app.activeReminders.length;

    return Scaffold(
      appBar: AppBar(title: const Text('My Day')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // Briefing hero
          Container(
            decoration: AppTheme.heroGradient(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(easternNow()),
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  attention == 0
                      ? 'All clear. Enjoy your day.'
                      : '$attention thing${attention == 1 ? '' : 's'} need${attention == 1 ? 's' : ''} your attention',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('${app.todayTasks.length} tasks today'),
                    _chip(
                        '${app.unpaidBills.length} bills due'),
                    _chip(
                        '${app.activeReminders.length} reminders'),
                    _chip(
                        '${app.habitsDoneToday}/${app.habits.length} habits'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Brain dump input
          const SectionHeader(title: 'Brain dump'),
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dump,
                    decoration: const InputDecoration(
                      hintText:
                          'Dump a thought… (e.g. call mom)',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _quickDump(),
                  ),
                ),
                IconButton(
                  icon: Container(
                    decoration: AppTheme.tile3D(
                      const [
                        AppColors.deepGreen,
                        AppColors.greenMid
                      ],
                      radius: 12,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  ),
                  onPressed: _quickDump,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (open.isEmpty)
            const EmptyState(
                message:
                    'Inbox zero. Anything on your mind? Dump it above.',
                icon: Icons.psychology_outlined),
          ...open.map((b) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.card3D(radius: 18),
                child: ListTile(
                  leading: const CategoryIcon(
                      category: 'brain', size: 42),
                  title: Text(b.text,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5)),
                  subtitle: Text(
                    _ago(b.createdAt),
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.muted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Make it a task',
                        icon: const Icon(
                            Icons.add_task_rounded,
                            color: AppColors.deepGreen),
                        onPressed: () =>
                            _convertToTask(context, app, b),
                      ),
                      IconButton(
                        icon: const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.muted),
                        onPressed: () =>
                            app.toggleBrainDump(b.id),
                      ),
                    ],
                  ),
                ),
              )),
        ],
        ),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  String _ago(DateTime d) {
    final diff = easternNow().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MM/dd/yyyy').format(d);
  }

  Future<void> _convertToTask(
      BuildContext context, AppState app, BrainDump b) async {
    await app.addTask(TaskItem(
      id: const Uuid().v4(),
      userId: app.profile?.id ?? '',
      title: b.text,
      category: 'general',
      source: 'brain-dump',
      createdAt: easternNow(),
    ));
    await app.toggleBrainDump(b.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Moved to Tasks.'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => Navigator.pushNamed(
              context, TasksScreen.route),
        ),
      ),
    );
  }
}
