import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/v2_kit.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../models/app_notification.dart';

/// V2 Notification Center: TODAY / EARLIER groups, unread green dots,
/// Snooze / Done actions, tap-to-open routes. Presentation rewritten
/// to the V2 mockup; feed still comes from AppState.refreshNotifications().
class NotificationsScreen extends StatefulWidget {
  static const route = '/notifications';
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Notifications dismissed this session via Snooze/Done.
  final Set<String> _dismissed = {};

  /// Ids that were unread when last (re)built — snapshot taken
  /// before markNotificationsSeen() so the green dots stay visible.
  Set<String> _unreadIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.refreshNotifications();
      _snapshotUnread(app);
      app.markNotificationsSeen();
    });
  }

  void _snapshotUnread(AppState app) {
    final seen = app.notificationsSeenAt;
    setState(() {
      _unreadIds = {
        for (final n in app.notifications)
          if (seen == null || n.createdAt.isAfter(seen)) n.id,
      };
    });
  }

  List<AppNotification> _visible(AppState app) =>
      app.notifications.where((n) => !_dismissed.contains(n.id)).toList();

  bool _isToday(DateTime d) {
    final now = easternNow();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _ago(DateTime d) {
    final diff = easternNow().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${d.month}/${d.day}/${d.year}';
  }

  void _dismiss(String id) => setState(() => _dismissed.add(id));

  /// Done: complete the underlying task/reminder when the notification
  /// maps to one, then remove it from the feed.
  Future<void> _done(AppNotification n) async {
    final app = context.read<AppState>();
    try {
      if (n.id.startsWith('task-') || n.id.startsWith('nag-')) {
        final taskId = n.id.substring(n.id.indexOf('-') + 1);
        if (app.tasks.any((t) => t.id == taskId && !t.isDone)) {
          await app.toggleTask(taskId);
        }
      } else if (n.id.startsWith('rem-')) {
        final remId = n.id.substring(n.id.indexOf('-') + 1);
        if (app.reminders.any((r) => r.id == remId && !r.isDone)) {
          await app.toggleReminder(remId);
        }
      }
    } catch (_) {
      // Fall through to plain dismiss — the feed item is still removed.
    }
    _dismiss(n.id);
  }

  void _snooze(AppNotification n) {
    _dismiss(n.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Snoozed for now.')),
    );
  }

  void _open(AppNotification n) {
    if (n.route != null) {
      Navigator.pushNamed(context, n.route!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = _visible(app);
    final today = items.where((n) => _isToday(n.createdAt)).toList();
    final earlier = items.where((n) => !_isToday(n.createdAt)).toList();

    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: V2.green,
          onRefresh: () async {
            final app = context.read<AppState>();
            await app.loadAll();
            if (mounted) _snapshotUnread(app);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: v2PagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const V2TitleRow(title: 'Notifications'),
                if (items.isEmpty)
                  V2Card(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const V2IconTile(
                            Icons.notifications_outlined,
                            size: 64),
                        const SizedBox(height: 14),
                        Text('All caught up',
                            style: V2.title(17)),
                        const SizedBox(height: 6),
                        Text(
                          'Bills, tasks and reminders will show up here.',
                          textAlign: TextAlign.center,
                          style: V2.sub(13.5),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                if (today.isNotEmpty) ...[
                  const V2SectionLabel('Today'),
                  ...today.map((n) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: _card(n),
                      )),
                ],
                if (earlier.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const V2SectionLabel('Earlier'),
                  ...earlier.map((n) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: _card(n),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  Widget _card(AppNotification n) {
    final unread = _unreadIds.contains(n.id);
    return V2Card(
      onTap: n.route == null ? null : () => _open(n),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: V2.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(n.icon,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.only(right: 16, top: 2),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(n.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  height: 1.25)),
                          const SizedBox(height: 3),
                          Text(n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: V2.muted,
                                  height: 1.35)),
                          const SizedBox(height: 4),
                          Text(_ago(n.createdAt),
                              style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: V2.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => _snooze(n),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: V2.green, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                      ),
                      child: Text('Snooze',
                          style: GoogleFonts.poppins(
                              color: V2.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => _done(n),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: V2.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24),
                      ),
                      child: Text('Done',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (unread)
            const Positioned(
              top: 2,
              right: 2,
              child: SizedBox(
                width: 12,
                height: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: V2.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
