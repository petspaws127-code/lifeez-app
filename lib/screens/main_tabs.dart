import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'reminders_screen.dart';
import 'calendar_screen.dart';
import 'more_screen.dart';
import 'pin_lock_screen.dart';
import '../services/update_service.dart';
import '../widgets/ai_command_drawer.dart';

/// Bottom navigation with the 5 main tabs.
/// Shows the PIN lock screen when the app is locked.
class MainTabs extends StatefulWidget {
  static const route = '/home';
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Auto-check for updates on app start
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _checkForUpdateAuto();
    });
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

  static const _screens = [
    HomeScreen(),
    TasksScreen(),
    RemindersScreen(),
    MoreScreen(),
  ];

  void _openAiDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiCommandDrawer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.isLocked) {
      return const PinLockScreen();
    }
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: GestureDetector(
        onTap: _openAiDrawer,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1a9c63), Color(0xFF27c77e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1a9c63).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline_rounded),
              label: 'Tasks'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              label: 'Reminders'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: 'More'),
        ],
      ),
    );
  }
}
