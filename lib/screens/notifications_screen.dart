import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';

/// Notification Center — activity feed with unread badge.
/// Tapping a notification opens the related screen.
class NotificationsScreen extends StatefulWidget {
  static const route = '/notifications';
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.refreshNotifications();
      app.markNotificationsSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.notifications;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (items.isEmpty)
            const EmptyState(
                message:
                    'All caught up. Bills, tasks and reminders will show up here.',
                icon: Icons.notifications_outlined),
          ...items.map((n) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.card3D(radius: 18),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: AppTheme.tile3D(
                      const [
                        AppColors.deepGreen,
                        AppColors.greenMid
                      ],
                      radius: 14,
                    ),
                    child: Icon(n.icon,
                        color: Colors.white, size: 22),
                  ),
                  title: Text(n.title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5)),
                  subtitle: Text(n.body,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.muted)),
                  trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted),
                  onTap: n.route == null
                      ? null
                      : () => Navigator.pushNamed(
                          context, n.route!),
                ),
              )),
        ],
        ),
      ),
    );
  }
}
