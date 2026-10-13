import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/v2_kit.dart';
import 'home_screen.dart';
import 'today_screen.dart';
import 'upcoming_screen.dart';
import 'profile_screen.dart';
import 'pin_lock_screen.dart';
import '../services/update_service.dart';

/// V2 bottom navigation: Home | Today | center AI | Upcoming | Profile.
/// The center AI button opens the full-screen AI assistant (/assistant).
/// Shows the PIN lock screen when the app is locked.
class MainTabs extends StatefulWidget {
  static const route = '/home';
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> with WidgetsBindingObserver {
  int _index = 0;
  bool _argsHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-check for updates on app start
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _checkForUpdateAuto();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // v2GoTab() pushes '/home' with an int tab argument
    // (0=Home, 1=Today, 2=Upcoming, 3=Profile). Honor it once per navigation.
    if (!_argsHandled) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int && args >= 0 && args <= 3) {
        _index = args;
      }
      _argsHandled = true;
    }
  }

  Future<void> _checkForUpdateAuto() async {
    try {
      final updateService = UpdateService();
      final info = await updateService.checkForUpdate();
      if (info != null && mounted) {
        _showUpdateDialog(info, updateService);
      }
    } catch (_) {}
  }

  void _showUpdateDialog(UpdateInfo info, UpdateService updateService) {
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
              // Download and install
              bool started = false;
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
                started = await updateService.downloadAndInstall(info, (p) {});
              } catch (_) {}
              if (mounted) Navigator.pop(context);
              if (!started && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download failed. Try again.')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-lock when app goes to background (if PIN is set)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final app = context.read<AppState>();
      app.lockApp();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.isLocked) {
      return const PinLockScreen();
    }
    // Built per-frame (not const) so parallel teams can evolve the
    // Today/Upcoming screens without touching this file.
    final screens = <Widget>[
      const HomeScreen(),
      const TodayScreen(),
      const UpcomingScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      // SafeArea (top only): keeps tab content below the status bar.
      // Bottom is handled by V2BottomNav's own SafeArea.
      body: SafeArea(
        top: true,
        bottom: false,
        child: IndexedStack(index: _index, children: screens),
      ),
      bottomNavigationBar: V2BottomNav(
        activeIndex: _index,
        onTab: (i) => setState(() => _index = i),
        onAi: () => Navigator.pushNamed(context, '/assistant'),
      ),
    );
  }
}
