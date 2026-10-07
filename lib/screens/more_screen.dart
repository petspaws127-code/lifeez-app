import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import 'whatsapp_chat_screen.dart';
import 'ai_assistant_screen.dart';
import 'reminders_screen.dart';
import 'bills_screen.dart';
import 'subscriptions_screen.dart';
import 'shopping_screen.dart';
import 'documents_screen.dart';
import 'car_screen.dart';
import 'family_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'pets_screen.dart';
import 'habits_screen.dart';
import 'my_day_screen.dart';
import 'notifications_screen.dart';
import 'scanner_screen.dart';
import 'pro_screen.dart';
import 'profile_screen.dart';
import 'referrals_screen.dart';
import 'lent_borrowed_screen.dart';
import 'subscription_audit_screen.dart';
import 'cash_flow_screen.dart';
import 'budget_guard_screen.dart';

class _MenuEntry {
  final String label;
  final String icon;
  final String route;
  const _MenuEntry(this.label, this.icon, this.route);
}

class MoreScreen extends StatelessWidget {
  static const route = '/more';
  const MoreScreen({super.key});

  static const _entries = [
    _MenuEntry('Manage with WhatsApp', 'grocery', WhatsAppChatScreen.route),
    _MenuEntry('AI Assistant', 'task', AiAssistantScreen.route),
    _MenuEntry('My Day', 'myday', MyDayScreen.route),
    _MenuEntry('Habit Tracker', 'habit', HabitsScreen.route),
    _MenuEntry('Pet Reminders', 'pet', PetsScreen.route),
    _MenuEntry('Notifications', 'notification',
        NotificationsScreen.route),
    _MenuEntry('Reminders', 'reminder', RemindersScreen.route),
    _MenuEntry('Bills', 'bills', BillsScreen.route),
    _MenuEntry('Subscriptions', 'subscription', SubscriptionsScreen.route),
    _MenuEntry('Shopping List', 'grocery', ShoppingScreen.route),
    _MenuEntry('Documents', 'document', DocumentsScreen.route),
    _MenuEntry('Document Scanner', 'scan', ScannerScreen.route),
    _MenuEntry('My Car', 'car', CarScreen.route),
    _MenuEntry('Family', 'family', FamilyScreen.route),
    _MenuEntry('Monthly Report', 'money', ReportScreen.route),
    _MenuEntry('Budget Guard', 'money', BudgetGuardScreen.route),
    _MenuEntry(
        'Subscription Audit', 'subscription', SubscriptionAuditScreen.route),
    _MenuEntry('Cash-flow Forecast', 'savings', CashFlowScreen.route),
    _MenuEntry('Lent & Borrowed', 'money', LentBorrowedScreen.route),
    _MenuEntry('Refer & Earn', 'share', ReferralsScreen.route),
    _MenuEntry('My Profile', 'family', ProfileScreen.route),
    _MenuEntry('Lifeez Pro', 'pro', ProScreen.route),
    _MenuEntry('Settings', 'general', SettingsScreen.route),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _entries.length,
        itemBuilder: (_, i) {
          final e = _entries[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: AppTheme.card3D(radius: 18),
            child: ListTile(
              leading: CategoryIcon(category: e.icon, size: 44),
              title: Text(e.label,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.muted),
              onTap: () =>
                  Navigator.pushNamed(context, e.route),
            ),
          );
        },
      ),
    );
  }
}
