import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import 'notifications_screen.dart';
import 'tasks_screen.dart';
import 'reminders_screen.dart';
import 'bills_screen.dart';
import 'calendar_screen.dart';
import 'subscriptions_screen.dart';
import 'habits_screen.dart';

// Prototype 2: Timeline Feed Dashboard - LOCKED design
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = app.profile?.name ?? 'there';
    final budgetLeft = app.leftToSpend;
    
    // Build timeline items from all activities
    final items = _buildTimeline(app);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F3), // cream
      body: SafeArea(
        child: Column(
          children: [
            // Thin budget bar (1 line)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1a9c63).withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, 
                    size: 16, color: Color(0xFF1a9c63)),
                  const SizedBox(width: 8),
                  Text(
                    '\$${budgetLeft.toStringAsFixed(0)} left this month',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1a9c63),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context, NotificationsScreen.route),
                    child: const Icon(Icons.notifications_outlined,
                      size: 20, color: Color(0xFF1a9c63)),
                  ),
                ],
              ),
            ),
            // Greeting
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Hi $name 👋',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // Timeline feed
            Expanded(
              child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timeline,
                          size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No activities yet',
                          style: GoogleFonts.poppins(
                            fontSize: 16, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to get started',
                          style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => _TimelineItem(
                      item: items[i],
                      isLast: i == items.length - 1,
                    ),
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        backgroundColor: const Color(0xFF1a9c63),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  List<_TimelineEntry> _buildTimeline(AppState app) {
    final items = <_TimelineEntry>[];
    
    // Tasks
    for (final t in app.openTasks.take(5)) {
      items.add(_TimelineEntry(
        type: 'task',
        title: t.title,
        subtitle: t.dueDate != null 
          ? 'Due ${_fmtDate(t.dueDate!)}' : 'No due date',
        icon: Icons.check_circle_outline,
        time: t.dueDate ?? DateTime.now(),
      ));
    }
    
    // Reminders
    for (final r in app.activeReminders.take(5)) {
      items.add(_TimelineEntry(
        type: 'reminder',
        title: r.title,
        subtitle: 'Reminder',
        icon: Icons.notifications_outlined,
        time: r.remindAt ?? DateTime.now(),
      ));
    }
    
    // Bills
    for (final b in app.unpaidBills.take(5)) {
      items.add(_TimelineEntry(
        type: 'bill',
        title: b.name,
        subtitle: '\$${b.amount.toStringAsFixed(2)} due',
        icon: Icons.receipt_outlined,
        time: DateTime.now(),
      ));
    }
    
    // Sort by time, newest first
    items.sort((a, b) => b.time.compareTo(a.time));
    return items.take(20).toList();
  }

  String _fmtDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('What do you want to add?',
              style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _AddOption(Icons.check_circle_outline, 'Tasks',
                  () => Navigator.pushNamed(ctx, TasksScreen.route)),
                _AddOption(Icons.notifications_outlined, 'Reminders',
                  () => Navigator.pushNamed(ctx, RemindersScreen.route)),
                _AddOption(Icons.receipt_outlined, 'Bills',
                  () => Navigator.pushNamed(ctx, BillsScreen.route)),
                _AddOption(Icons.calendar_month_outlined, 'Calendar',
                  () => Navigator.pushNamed(ctx, CalendarScreen.route)),
                _AddOption(Icons.subscriptions_outlined, 'Subscriptions',
                  () => Navigator.pushNamed(ctx, SubscriptionsScreen.route)),
                _AddOption(Icons.local_fire_department_outlined, 'Habits',
                  () => Navigator.pushNamed(ctx, HabitsScreen.route)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _AddOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1a9c63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF1a9c63), size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final DateTime time;
  _TimelineEntry({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.time,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TimelineEntry item;
  final bool isLast;
  const _TimelineItem({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot and line
        Column(
          children: [
            Container(
              width: 12, height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF1a9c63),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 60,
                color: const Color(0xFF1a9c63).withOpacity(0.2)),
          ],
        ),
        const SizedBox(width: 12),
        // Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Icon(item.icon, 
                  color: const Color(0xFF1a9c63), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(item.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
