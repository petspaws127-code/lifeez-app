import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/ui_kit.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_tabs.dart';

/// Welcome/Info screen — shown once after splash for users who
/// have not signed in yet. (Signed-in users skip this.)
class WelcomeScreen extends StatefulWidget {
  static const route = '/welcome';
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    // If already signed in, skip directly to Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      if (auth.isSignedIn) {
        Navigator.pushReplacementNamed(context, MainTabs.route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const AppLogo(size: 96),
              const SizedBox(height: 20),
              Text(
                'Lifeez',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Life, made easy.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell it. It remembers it.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 32),
              _feature(
                icon: Icons.check_circle_rounded,
                title: 'Tasks',
                desc: 'Stay on top of everything with simple to-do lists.',
                highlight: true,
              ),
              _feature(
                icon: Icons.alarm_rounded,
                title: 'Reminders',
                desc: 'Never miss a thing — including pet care reminders.',
                highlight: true,
              ),
              _feature(
                icon: Icons.event_rounded,
                title: 'Events',
                desc: 'Birthdays, appointments, and bills on one calendar.',
                highlight: true,
              ),
              _feature(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Budget & Savings',
                desc: 'Track spending and grow your savings.',
              ),
              _feature(
                icon: Icons.repeat_rounded,
                title: 'Habits',
                desc: 'Build streaks one day at a time.',
              ),
              _feature(
                icon: Icons.bolt_rounded,
                title: 'Quick Commands',
                desc: 'Type or speak — Lifeez understands and saves it.',
              ),
              const SizedBox(height: 32),
              GradientButton(
                label: 'Get Started',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  LoginScreen.route,
                ),
                colors: const [AppColors.deepGreen, AppColors.greenMid],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feature({
    required IconData icon,
    required String title,
    required String desc,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: highlight ? 52 : 44,
            height: highlight ? 52 : 44,
            decoration: BoxDecoration(
              color: highlight
                  ? AppColors.greenSoft
                  : AppColors.greenMid.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(highlight ? 16 : 14),
            ),
            child: Icon(
              icon,
              color: AppColors.deepGreen,
              size: highlight ? 28 : 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: highlight ? 17 : 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
