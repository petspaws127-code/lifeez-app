import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import '../services/update_service.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _checkForUpdate() async {
    try {
      final updateService = UpdateService();
      final hasUpdate = await updateService.checkForUpdate();
      if (hasUpdate && mounted) {
        final shouldUpdate = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text('Update Available', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text('A new version of Lifeez is available. Update now?', style: GoogleFonts.poppins()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Later', style: GoogleFonts.poppins(color: AppColors.muted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text('Update', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        );
        if (shouldUpdate == true) {
          await updateService.downloadAndInstall();
        }
      }
    } catch (_) {}
  }

  Future<void> _decideNext() async {
    await _checkForUpdate();
    await Future.delayed(const Duration(milliseconds: 2300));
    if (!mounted) return;
    final auth = context.read<AuthService>();
    await auth.init();
    if (!mounted) return;
    if (auth.isLoggedIn) {
      context.read<AppState>().setUser(auth.userId, auth.userName);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo - green rounded square with white L
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: Text(
                  'L',
                  style: GoogleFonts.poppins(
                    fontSize: 72,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Lifeez',
              style: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Life, made easy.',
              style: GoogleFonts.poppins(
                fontSize: 20,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
