import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/profile_menu.dart';
import 'notifications_screen.dart';
import 'ai_assistant_screen.dart';
import 'ai_daily_briefing_screen.dart';
import 'weekly_review_screen.dart';
import 'adhd_mode_screen.dart';
import 'trip_planner_screen.dart';
import 'pets_screen.dart';
import 'alarm_screen.dart';
import 'calendar_screen.dart';
import 'habits_screen.dart';

// Prototype 2: Timeline Feed Dashboard - LOCKED design
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = app.profile?.name ?? 'there';
    
    // Build timeline items from all activities
    final items = _buildTimeline(app);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F3), // cream
      body: SafeArea(
        child: Column(
          children: [
            // Greeting
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hi $name 👋',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, NotificationsScreen.route),
                    child: const Icon(Icons.notifications_outlined,
                        size: 22, color: Color(0xFF1a9c63)),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => ProfileMenu.show(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1a9c63),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E3E3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add New',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('What would you like to create?',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F3F3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick Add -> AI Assistant
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(ctx, AiAssistantScreen.route);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF1a9c63).withOpacity(0.06),
                    border: Border.all(
                        color: const Color(0xFF1a9c63), width: 1.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          color: Color(0xFF1a9c63), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Type or speak anything...',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: Colors.grey[600])),
                      ),
                      const Icon(Icons.mic_none,
                          color: Color(0xFF1a9c63), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _sheetSectionLabel('QUICK CREATE'),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                children: [
                  _AddOption(Icons.calendar_month_outlined, 'Calendar',
                      () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, CalendarScreen.route);
                  }),
                  _AddOption(
                      Icons.local_fire_department_outlined, 'Habits',
                      () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, HabitsScreen.route);
                  }),
                  _AddOption(Icons.alarm_outlined, 'Alarm', () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, AlarmScreen.route);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              _sheetSectionLabel('SMART FEATURES'),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 8,
                childAspectRatio: 1.05,
                children: [
                  _AddOption(
                      Icons.wb_sunny_outlined, 'Daily Briefing', () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(
                        ctx, AiDailyBriefingScreen.route);
                  }),
                  _AddOption(
                      Icons.assessment_outlined, 'Weekly Review', () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, WeeklyReviewScreen.route);
                  }),
                  _AddOption(Icons.flight_outlined, 'Trips', () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, TripPlannerScreen.route);
                  }),
                  _AddOption(Icons.timer_outlined, 'Focus Timer', () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, AdhdModeScreen.route);
                  }),
                  _AddOption(Icons.pets_outlined, 'Pets', () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, PetsScreen.route);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: const Color(0xFF9A9A9A),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
