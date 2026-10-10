import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/supabase_client.dart';
import '../widgets/profile_menu.dart';
import '../widgets/add_sheet.dart';
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

  /// Display name: Google account name first, then profile name.
  /// Returns first name with first letter capitalized.
  String _displayName(AppState app) {
    String? raw;
    // 1. Google account display name (from Supabase auth metadata)
    try {
      final user = SupabaseService.client.auth.currentUser;
      raw = user?.userMetadata?['full_name'] as String?;
      raw ??= user?.userMetadata?['name'] as String?;
    } catch (_) {}
    // 2. Profile name fallback
    raw ??= app.profile?.name;
    if (raw == null || raw.trim().isEmpty) return 'there';
    // First word, first letter capitalized
    final first = raw.trim().split(RegExp(r'\s+')).first;
    return first[0].toUpperCase() + first.substring(1);
  }

  /// Time-based greeting: Good Morning / Good Afternoon / Good Evening
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = _displayName(app);

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${_greeting()} 👋',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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
        onPressed: () => showAddSheet(context),
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
