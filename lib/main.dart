import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/supabase_client.dart';
import 'services/auth_service.dart';
import 'services/app_state.dart';
import 'services/whatsapp_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_tabs.dart';
import 'screens/whatsapp_chat_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/money_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/more_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/shopping_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/car_screen.dart';
import 'screens/family_screen.dart';
import 'screens/report_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: paste your Supabase URL + anon key in
  // lib/services/supabase_client.dart before running.
  await SupabaseService.init();
  runApp(const AiLifeAssistantApp());
}

class AiLifeAssistantApp extends StatelessWidget {
  const AiLifeAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => WhatsAppService()),
      ],
      child: MaterialApp(
        title: 'Lifeez',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: SplashScreen.route,
        routes: {
          SplashScreen.route: (_) => const SplashScreen(),
          LoginScreen.route: (_) => const LoginScreen(),
          OnboardingScreen.route: (_) =>
              const OnboardingScreen(),
          MainTabs.route: (_) => const MainTabs(),
          WhatsAppChatScreen.route: (_) =>
              const WhatsAppChatScreen(),
          AiAssistantScreen.route: (_) =>
              const AiAssistantScreen(),
          TasksScreen.route: (_) => const TasksScreen(),
          MoneyScreen.route: (_) => const MoneyScreen(),
          CalendarScreen.route: (_) => const CalendarScreen(),
          MoreScreen.route: (_) => const MoreScreen(),
          RemindersScreen.route: (_) =>
              const RemindersScreen(),
          BillsScreen.route: (_) => const BillsScreen(),
          SubscriptionsScreen.route: (_) =>
              const SubscriptionsScreen(),
          ShoppingScreen.route: (_) =>
              const ShoppingScreen(),
          DocumentsScreen.route: (_) =>
              const DocumentsScreen(),
          CarScreen.route: (_) => const CarScreen(),
          FamilyScreen.route: (_) => const FamilyScreen(),
          ReportScreen.route: (_) => const ReportScreen(),
          SettingsScreen.route: (_) =>
              const SettingsScreen(),
        },
      ),
    );
  }
}
