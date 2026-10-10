import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/ai_assistant_screen.dart';
import '../screens/ai_daily_briefing_screen.dart';
import '../screens/weekly_review_screen.dart';
import '../screens/adhd_mode_screen.dart';
import '../screens/trip_planner_screen.dart';
import '../screens/pets_screen.dart';
import '../screens/alarm_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/habits_screen.dart';

/// Shared "Add New" bottom sheet — opened from the Home FAB
/// and from the ＋ Add tab in the bottom nav.
void showAddSheet(BuildContext context) {
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
                            fontSize: 18, fontWeight: FontWeight.w700)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a9c63).withOpacity(0.06),
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
                _AddOption(Icons.calendar_month_outlined, 'Calendar', () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(ctx, CalendarScreen.route);
                }),
                _AddOption(Icons.local_fire_department_outlined, 'Habits',
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
                _AddOption(Icons.wb_sunny_outlined, 'Daily Briefing', () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(ctx, AiDailyBriefingScreen.route);
                }),
                _AddOption(Icons.assessment_outlined, 'Weekly Review', () {
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
          width: 56,
          height: 56,
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
