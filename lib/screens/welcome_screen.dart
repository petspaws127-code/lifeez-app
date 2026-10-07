import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/ui_kit.dart';
import 'login_screen.dart';

/// Welcome/Info screen — shown once after splash for users who
/// have not signed in yet. (Signed-in users skip this.)
class WelcomeScreen extends StatelessWidget {
  static const route = '/welcome';
  const WelcomeScreen({super.key});

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
                icon: Icons.bolt_rounded,
                title: 'Quick Commands',
                desc: 'Type or speak — Lifeez understands and saves it.',
              ),
              _feature(
                icon: Icons.pets_rounded,
                title: 'Pets',
                desc: 'Reminders, vaccinations, and memories for your pets.',
              ),
              _feature(
                icon: Icons.check_circle_rounded,
                title: 'Habits',
                desc: 'Build streaks and track daily habits.',
              ),
              _feature(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Budget & Savings',
                desc: 'Track spending and grow your savings.',
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.greenMid.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.deepGreen, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
