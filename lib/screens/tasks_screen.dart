import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/v2_kit.dart';
import '../widgets/add_sheet.dart';
import '../services/app_state.dart';
import '../services/smart_ai_service.dart';
import '../services/eastern_time.dart';
import '../models/task_item.dart';

/// V2 Tasks — filter chips (All/Today/Upcoming/Done), checkbox rows,
/// priority dots, due labels. Completed rows are faded + strikethrough.
class TasksScreen extends StatefulWidget {
  static const route = '/tasks';
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _filter = 0; // 0 All · 1 Today · 2 Upcoming · 3 Done

  static const _filters = ['All', 'Today', 'Upcoming', 'Done'];

  List<TaskItem> _visible(AppState app) {
    switch (_filter) {
      case 1:
        return app.todayTasks;
      case 2:
        return app.upcomingTasks;
      case 3:
        return app.completedTasks;
      default:
        return app.openTasks;
    }
  }

  String _dueLabel(TaskItem t) {
    final d = t.dueDate;
    if (d == null) return 'No due date';
    if (t.isDone) return 'Due ${_shortDay(d)} • Completed';
    return _shortDay(d);
  }

  String _shortDay(DateTime d) {
    final today = easternToday();
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(DateTime(today.year, today.month, today.day));
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (diff.inDays == 0) return 'Due today';
    if (diff.inDays == 1) return 'Due tomorrow';
    if (diff.inDays == -1) return 'Due yesterday';
    return '${months[d.month]} ${d.day}';
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return V2.danger;
      case 'low':
        return V2.muted;
      default:
        return V2.amber;
    }
  }

  void _toggle(BuildContext context, TaskItem t) {
    if (!t.isDone) {
      context
          .read<SmartAiService>()
          .recordTaskCompleted(DateTime.now(), t.category);
    }
    context.read<AppState>().toggleTask(t.id);
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState app, TaskItem t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete task?'),
        content: Text('"${t.title}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: V2.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: V2.danger))),
        ],
      ),
    );
    if (ok == true) await app.deleteTask(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = _visible(app);
    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: v2PagePadding,
          children: [
            V2TitleRow(
              title: 'Tasks',
              trailing: V2AddButton(
                onTap: () =>
                    showAddSheet(context, initialType: 'task'),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  _filters.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: V2Pill(
                      label: _filters[i],
                      selected: _filter == i,
                      onTap: () => setState(() => _filter = i),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    const V2IconTile(
                        Icons.check_circle_outline_rounded,
                        size: 72),
                    const SizedBox(height: 12),
                    Text('All clear',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      _filter == 3
                          ? 'No completed tasks yet.'
                          : 'Nothing here. Tap + to add one.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: V2.muted),
                    ),
                  ],
                ),
              )
            else
              ...items.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 22),
                        decoration: BoxDecoration(
                          color: V2.danger,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white),
                      ),
                      confirmDismiss: (_) =>
                          _confirmDelete(context, app, t).then((_) => false),
                      child: _taskRow(context, t),
                    ),
                  )),
          ],
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  Widget _taskRow(BuildContext context, TaskItem t) {
    final done = t.isDone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF1F1EC) : V2.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: V2.softShadow,
      ),
      child: Row(
        children: [
            InkWell(
              onTap: () => _toggle(context, t),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? V2.green : Colors.transparent,
                  border: done
                      ? null
                      : Border.all(color: const Color(0xFFB9B9B2), width: 2),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: done ? V2.muted : V2.ink,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                      decorationColor: V2.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dueLabel(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, color: V2.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFFD8D8D2)
                    : _priorityColor(t.priority),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      );
  }
}
