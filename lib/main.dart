import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/supabase_client.dart';
import 'services/auth_service.dart';
import 'services/app_state.dart';
import 'services/whatsapp_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_tabs.dart';
import 'screens/whatsapp_chat_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/more_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/alarm_screen.dart';
import 'screens/shopping_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/car_screen.dart';
import 'screens/family_screen.dart';
import 'screens/report_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/pets_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/my_day_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/pro_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/referrals_screen.dart';
import 'screens/lent_borrowed_screen.dart';
import 'screens/subscription_audit_screen.dart';
import 'screens/cash_flow_screen.dart';
import 'screens/budget_guard_screen.dart';
import 'screens/ai_daily_briefing_screen.dart';
import 'screens/weekly_review_screen.dart';
import 'screens/travel_weather_screen.dart';
import 'screens/adhd_mode_screen.dart';
import 'screens/trip_planner_screen.dart';
import 'screens/pet_health_ai_screen.dart';
import 'screens/location_reminders_screen.dart';
import 'services/smart_ai_service.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/help_faq_screen.dart';
import 'screens/contact_support_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: paste your Supabase URL + anon key in
  // lib/services/supabase_client.dart before running.
  await SupabaseService.init();
  await NotificationService.instance.init();
  runApp(const AiLifeAssistantApp());
}

class AiLifeAssistantApp extends StatelessWidget {
  const AiLifeAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthService()
              ..restoreAdminSession()
              ..startDeepLinkListener()),
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => WhatsAppService()),
        ChangeNotifierProvider(
            create: (_) => SmartAiService()..load()),
      ],
      child: Consumer<AppState>(
        builder: (context, app, _) {
          final mode = app.themeMode;
          final systemDark =
              SchedulerBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark;
          final dark =
              mode == ThemeMode.dark || (mode == ThemeMode.system && systemDark);
          AppTheme.setDark(dark);
          return MaterialApp(
            title: 'Lifeez',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
        initialRoute: SplashScreen.route,
        routes: {
          SplashScreen.route: (_) => const SplashScreen(),
          WelcomeScreen.route: (_) => const WelcomeScreen(),
          LoginScreen.route: (_) => const LoginScreen(),
          OnboardingScreen.route: (_) =>
              const OnboardingScreen(),
          MainTabs.route: (_) => const MainTabs(),
          WhatsAppChatScreen.route: (_) =>
              const WhatsAppChatScreen(),
          AiAssistantScreen.route: (_) =>
              const AiAssistantScreen(),
          TasksScreen.route: (_) => const TasksScreen(),
          CalendarScreen.route: (_) => const CalendarScreen(),
          MoreScreen.route: (_) => const MoreScreen(),
          RemindersScreen.route: (_) =>
              const RemindersScreen(),
          AlarmScreen.route: (_) => const AlarmScreen(),
          ShoppingScreen.route: (_) =>
              const ShoppingScreen(),
          DocumentsScreen.route: (_) =>
              const DocumentsScreen(),
          CarScreen.route: (_) => const CarScreen(),
          FamilyScreen.route: (_) => const FamilyScreen(),
          ReportScreen.route: (_) => const ReportScreen(),
          SettingsScreen.route: (_) =>
              const SettingsScreen(),
          PetsScreen.route: (_) => const PetsScreen(),
          HabitsScreen.route: (_) => const HabitsScreen(),
          MyDayScreen.route: (_) => const MyDayScreen(),
          NotificationsScreen.route: (_) =>
              const NotificationsScreen(),
          PinLockScreen.route: (_) => const PinLockScreen(),
          ScannerScreen.route: (_) => const ScannerScreen(),
          ProScreen.route: (_) => const ProScreen(),
          ProfileScreen.route: (_) => const ProfileScreen(),
          ReferralsScreen.route: (_) => const ReferralsScreen(),
          LentBorrowedScreen.route: (_) =>
              const LentBorrowedScreen(),
          SubscriptionAuditScreen.route: (_) =>
              const SubscriptionAuditScreen(),
          AiDailyBriefingScreen.route: (_) =>
              const AiDailyBriefingScreen(),
          WeeklyReviewScreen.route: (_) => const WeeklyReviewScreen(),
          TravelWeatherScreen.route: (_) =>
              const TravelWeatherScreen(),
          AdhdModeScreen.route: (_) => const AdhdModeScreen(),
          TripPlannerScreen.route: (_) => const TripPlannerScreen(),
          PetHealthAiScreen.route: (_) => const PetHealthAiScreen(),
          LocationRemindersScreen.route: (_) =>
              const LocationRemindersScreen(),
          CashFlowScreen.route: (_) => const CashFlowScreen(),
          BudgetGuardScreen.route: (_) =>
              const BudgetGuardScreen(),
          PrivacyPolicyScreen.route: (_) =>
              const PrivacyPolicyScreen(),
          TermsScreen.route: (_) => const TermsScreen(),
          HelpFaqScreen.route: (_) => const HelpFaqScreen(),
          ContactSupportScreen.route: (_) =>
              const ContactSupportScreen(),
        },
      );
        },
      ),
    );
  }
}
