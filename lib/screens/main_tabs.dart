import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/ai_command_drawer.dart';
import '../widgets/add_sheet.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'reminders_screen.dart';
import 'pin_lock_screen.dart';
import '../services/update_service.dart';

/// Bottom navigation: Home | Tasks | Reminders | + Add.
/// The AI assistant is a floating glowing button (bottom-center above nav).
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
  ];

  /// Center AI button: instantly opens the voice/text command drawer
  /// with the microphone active.
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Home
            _navSlot(index: 0, icon: Icons.home_rounded, label: 'Home'),
            // Tasks
            _navSlot(
                index: 1,
                icon: Icons.check_circle_outline_rounded,
                label: 'Tasks'),
            // AI Assistant — regular nav item, same style as others
            Expanded(
              child: InkWell(
                onTap: _openAiDrawer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: Colors.grey, size: 26),
                      const SizedBox(height: 2),
                      Text('AI',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ),
            ),
            // Reminders
            _navSlot(
                index: 2,
                icon: Icons.notifications_outlined,
                label: 'Reminders'),
            // + Add — opens the add sheet
            Expanded(
              child: InkWell(
                onTap: () => showAddSheet(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded,
                          color: Colors.grey, size: 26),
                      const SizedBox(height: 2),
                      Text('Add',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navSlot(
      {required int index,
      required IconData icon,
      required String label}) {
    final selected = _index == index;
    final color =
        selected ? const Color(0xFF1a9c63) : Colors.grey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 2),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: color,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}
