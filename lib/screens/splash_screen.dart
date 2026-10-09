import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import '../services/whatsapp_service.dart';
import 'welcome_screen.dart';
import 'main_tabs.dart';
import '../services/update_service.dart';

class SplashScreen extends StatefulWidget {
  static const route = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _decideNext();
  }

  Future<void> _decideNext() async {
    // Check for updates FIRST (await it!)
    await _checkForUpdate();
    await Future.delayed(const Duration(milliseconds: 2300));
    if (!mounted) return;
    final auth = context.read<AuthService>();
    if (!auth.isSignedIn) {
      Navigator.pushReplacementNamed(context, WelcomeScreen.route);
      return;
    }
    final app = context.read<AppState>();
    final whatsapp = context.read<WhatsAppService>();
    await app.loadAll();
    await whatsapp.restore();
    if (!mounted) return;
    // Onboarding removed - go directly to MainTabs
    // Income/budget setup via popup (Task 5)
    Navigator.pushReplacementNamed(context, MainTabs.route);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: FadeTransition(
                  opacity: _fade,
                  child: const AppLogo(size: 110),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fade,
                child: Text(
                  'Lifeez',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _fade,
                child: Text(
                  'Life, made easy.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _checkForUpdate() async {
    try {
      final updateService = UpdateService();
      final info = await updateService.checkForUpdate();
      if (info != null && mounted) {
        // Wait for splash to finish, then show dialog
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('Update Available: v${info.versionName}'),
            content: Text(info.notes.isNotEmpty ? info.notes : 'A new version is available!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx2) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Downloading...'),
                        ],
                      ),
                    ),
                  );
                  try {
                    await updateService.downloadAndInstall(info, (p) {});
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

}
