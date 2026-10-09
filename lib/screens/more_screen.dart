import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import 'profile_screen.dart';
import 'pro_screen.dart';
import 'help_faq_screen.dart';
import 'contact_support_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'settings_screen.dart';
import 'bill_saver_screen.dart';
import 'ai_daily_briefing_screen.dart';
import 'weekly_review_screen.dart';
import 'travel_weather_screen.dart';
import 'adhd_mode_screen.dart';
import 'trip_planner_screen.dart';
import 'pet_health_ai_screen.dart';
import 'location_reminders_screen.dart';

class _MenuEntry {
  final String label;
  final String icon;
  final String route;
  const _MenuEntry(this.label, this.icon, this.route);
}

class _MenuSection {
  final String title;
  final List<_MenuEntry> entries;
  const _MenuSection(this.title, this.entries);
}

class MoreScreen extends StatelessWidget {
  static const route = '/more';
  const MoreScreen({super.key});

  static const _sections = [
    _MenuSection('Account', [
      _MenuEntry('My Profile', 'family', ProfileScreen.route),
      _MenuEntry('Lifeez Pro', 'pro', ProScreen.route),
    ]),
    _MenuSection('Money', [
      _MenuEntry('Bill Saver', 'money', BillSaverScreen.route),
    ]),
    _MenuSection('Smart', [
      _MenuEntry('AI Daily Briefing', 'general', AiDailyBriefingScreen.route),
      _MenuEntry('Weekly Review', 'general', WeeklyReviewScreen.route),
      _MenuEntry('ADHD Mode', 'general', AdhdModeScreen.route),
    ]),
    _MenuSection('Travel', [
      _MenuEntry('Travel Weather', 'general', TravelWeatherScreen.route),
      _MenuEntry('Trip Planner', 'general', TripPlannerScreen.route),
    ]),
    _MenuSection('Pets', [
      _MenuEntry('Pet Health AI', 'pet', PetHealthAiScreen.route),
    ]),
    _MenuSection('Reminders', [
      _MenuEntry('Location Reminders', 'general', LocationRemindersScreen.route),
    ]),
    _MenuSection('Support', [
      _MenuEntry('Help & FAQ', 'general', HelpFaqScreen.route),
      _MenuEntry('Contact Support', 'general', ContactSupportScreen.route),
    ]),
    _MenuSection('Legal', [
      _MenuEntry('Privacy Policy', 'document', PrivacyPolicyScreen.route),
      _MenuEntry('Terms of Service', 'document', TermsScreen.route),
    ]),
    _MenuSection('App', [
      _MenuEntry('Settings', 'general', SettingsScreen.route),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (final section in _sections) ...[
            SectionHeader(title: section.title),
            for (final e in section.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.card3D(radius: 18),
                child: ListTile(
                  leading: CategoryIcon(category: e.icon, size: 44),
                  title: Text(e.label,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
                  onTap: () => Navigator.pushNamed(context, e.route),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
