import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/update_service.dart';
import '../services/eastern_time.dart';
import 'ai_assistant_screen.dart';
import 'bills_screen.dart';
import 'calendar_screen.dart';
import 'habits_screen.dart';
import 'money_screen.dart';
import 'notifications_screen.dart';
import 'pets_screen.dart';
import 'profile_screen.dart';
import 'reminders_screen.dart';
import 'subscriptions_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = app.profile?.name ?? 'there';
    final firstName = name.split(' ').first;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMoreFeatures(context),
        backgroundColor: AppColors.deepGreen,
        child: const Icon(Icons.add_rounded,
            color: Colors.white, size: 30),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => app.loadAll(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // 1. Greeting header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, ProfileScreen.route),
                    child: Container(
                      decoration: AppTheme.tile3D(
                        const [
                          AppColors.deepGreen,
                          AppColors.greenMid
                        ],
                        radius: 16,
                      ),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: (app.profile?.photoPath ?? '')
                              .isNotEmpty
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(16),
                              child: Image.file(
                                File(app.profile!.photoPath!),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good ${_daypart()},',
                          style: GoogleFonts.poppins(
                              color: AppColors.muted,
                              fontSize: 13),
                        ),
                        Text(
                          firstName,
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification bell with unread badge
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, NotificationsScreen.route),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: AppTheme.card3D(
                              radius: 14),
                          child: const Icon(
                              Icons
                                  .notifications_outlined,
                              color: AppColors.deepGreen),
                        ),
                        if (app.unreadCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding:
                                  const EdgeInsets.all(5),
                              decoration:
                                  const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${app.unreadCount}',
                                style:
                                    GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Quick Commands — AI command center.
              const _QuickCommandsCard(),
              const SizedBox(height: 12),

              // Triggers the Go Pro popup (throttled, auto-dismissing).
              const _GoProPopupHost(),

              // 3. Hero: left to spend this month
              Container(
                decoration: AppTheme.heroGradient(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Left to spend this month',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${app.leftToSpend.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: app.budgetUsedPct,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.goldLight),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        _heroStat('Spent',
                            '\$${app.spentThisMonth.toStringAsFixed(0)}'),
                        _heroStat('Bills',
                            '${app.unpaidBills.length} due'),
                        _heroStat('Subscriptions',
                            '\$${app.subscriptionsMonthlyTotal.toStringAsFixed(0)}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Features grid — 7 main feature cards (FINAL).
              const SectionHeader(title: 'Features'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  _featureCard(context, 'Tasks', 'task',
                      TasksScreen.route),
                  _featureCard(context, 'Reminders', 'reminder',
                      RemindersScreen.route),
                  _featureCard(context, 'Events', 'event',
                      CalendarScreen.route),
                  _featureCard(context, 'Bills', 'bills',
                      BillsScreen.route),
                  _featureCard(context, 'Budget', 'money',
                      MoneyScreen.route),
                  _featureCard(context, 'Pets', 'pet',
                      PetsScreen.route),
                ],
              ),
              const SizedBox(height: 16),

              // 5. Activity — live feed of what's happening.
              const SectionHeader(title: 'Activity'),
              const SizedBox(height: 8),
              _ActivityFeed(app: app),
              const SizedBox(height: 16),

              // 6. Today — compact, max 3 tasks.
              SectionHeader(
                title: 'Today',
                actionLabel: 'See all',
                onAction: () => Navigator.pushNamed(
                    context, TasksScreen.route),
              ),
              if (app.todayTasks.isEmpty)
                const EmptyState(
                    message:
                        'Nothing due today. Add a task or just tell me.',
                    icon: Icons.wb_sunny_outlined)
              else
                ...app.todayTasks.take(3).map(
                      (t) => _taskRow(context, t.title,
                          t.category, t.id),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _daypart() {
    final h = easternNow().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  Widget _heroStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.white60, fontSize: 11.5)),
          Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      );

  Widget _featureCard(BuildContext context, String label,
      String category, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: AppTheme.card3D(radius: 18),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CategoryIcon(category: category, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet opened by the "+" FAB: extra features (FINAL: 2).
  void _showMoreFeatures(BuildContext context) {
    // FINAL: Only Subscriptions and Habits in Plus.
    // Home has: AI, Tasks, Reminders, Events, Bills, Budget, Pets.
    final features = <Map<String, dynamic>>[
      {'label': 'Subscriptions', 'category': 'subscription', 'route': SubscriptionsScreen.route},
      {'label': 'Habits', 'category': 'habit', 'route': HabitsScreen.route},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'More features',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                      16, 4, 16, 24),
                  itemCount: features.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final f = features[i];
                    return _moreFeatureRow(
                      context,
                      label: f['label'] as String,
                      route: f['route'] as String,
                      category: f['category'] as String?,
                      icon: f['icon'] as IconData?,
                      colors: f['colors'] as List<Color>?,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreFeatureRow(BuildContext context,
      {required String label,
      required String route,
      String? category,
      IconData? icon,
      List<Color>? colors}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
      child: Container(
        decoration: AppTheme.card3D(radius: 16),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (category != null)
              CategoryIcon(category: category, size: 40)
            else
              Container(
                width: 40,
                height: 40,
                decoration: AppTheme.tile3D(
                  colors ??
                      const [
                        AppColors.deepGreen,
                        AppColors.greenMid
                      ],
                  radius: 14,
                ),
                child: Icon(icon,
                    color: Colors.white, size: 20),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  Widget _taskRow(
      BuildContext context, String title, String category, String id) {
    final app = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.card3D(radius: 18),
      child: ListTile(
        leading: CategoryIcon(category: category, size: 42),
        title: Text(title,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline,
              color: AppColors.deepGreen),
          onPressed: () => app.toggleTask(id),
        ),
      ),
    );
  }
}

/// Quick Commands — AI command center at the top of Home.
/// Type or speak; Lifeez understands and saves it.
class _QuickCommandsCard extends StatelessWidget {
  const _QuickCommandsCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AiAssistantScreen.route),
      child: Container(
        decoration: AppTheme.card3D(),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              decoration: AppTheme.tile3D(
                const [
                  AppColors.deepGreen,
                  AppColors.greenMid
                ],
                radius: 13,
              ),
              padding: const EdgeInsets.all(9),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Quick Commands',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5),
                  ),
                  Text(
                    'Type or speak — Lifeez understands',
                    style: GoogleFonts.poppins(
                        color: AppColors.muted,
                        fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// Live activity feed on Home — shows what's due, upcoming,
/// and recently done across tasks, reminders, bills, and events.
class _ActivityFeed extends StatelessWidget {
  final AppState app;
  const _ActivityFeed({required this.app});

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[];

    // Due tasks
    for (final t in app.todayTasks.take(2)) {
      items.add({
        'icon': Icons.check_circle_outline_rounded,
        'color': AppColors.deepGreen,
        'text': 'Due today: ${t.title}',
        'route': TasksScreen.route,
      });
    }
    // Upcoming reminders
    for (final r in app.activeReminders.take(2)) {
      items.add({
        'icon': Icons.notifications_outlined,
        'color': AppColors.gold,
        'text': 'Reminder: ${r.title}',
        'route': RemindersScreen.route,
      });
    }
    // Unpaid bills
    for (final b in app.unpaidBills.take(2)) {
      items.add({
        'icon': Icons.receipt_long_outlined,
        'color': Colors.orange,
        'text': 'Bill due: ${b.name} — \$${b.amount.toStringAsFixed(0)}',
        'route': BillsScreen.route,
      });
    }

    if (items.isEmpty) {
      return Container(
        decoration: AppTheme.card3D(radius: 16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined,
                color: AppColors.muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All clear! Nothing needs your attention.',
                style: GoogleFonts.poppins(
                    color: AppColors.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items.take(5).map((item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: AppTheme.card3D(radius: 14),
        child: ListTile(
          dense: true,
          leading: Icon(item['icon'] as IconData,
              color: item['color'] as Color, size: 22),
          title: Text(
            item['text'] as String,
            style: GoogleFonts.poppins(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded,
              size: 18, color: Colors.grey),
          onTap: () => Navigator.pushNamed(
              context, item['route'] as String),
        ),
      )).toList(),
    );
  }
}

/// Shows the Go Pro popup once per Home visit, throttled to
/// 5 shows/day, auto-dismissed after 6 seconds.
class _GoProPopupHost extends StatefulWidget {
  const _GoProPopupHost();

  @override
  State<_GoProPopupHost> createState() => _GoProPopupHostState();
}

class _GoProPopupHostState extends State<_GoProPopupHost> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _maybeShow);
    // Check for app updates shortly after launch (once per 12h).
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      UpdateService.promptIfAvailable(context, UpdateService());
    });
  }

  Future<void> _maybeShow() async {
    if (!mounted || _shown) return;
    _shown = true;
    final app = context.read<AppState>();
    final allowed = await app.consumeGoProPopupSlot();
    if (!allowed || !mounted) return;
    Timer? dismissTimer;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        dismissTimer = Timer(const Duration(seconds: 6), () {
          if (ctx.mounted) Navigator.pop(ctx);
        });
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: AppTheme.goldGradient(radius: 24),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFF5c4a12), size: 48),
                const SizedBox(height: 10),
                Text('Unlock Lifeez Pro',
                    style: GoogleFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5c4a12))),
                const SizedBox(height: 6),
                Text(
                  'AI insights, unlimited history, and priority features.\nStart with 14 days free.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: const Color(0xFF7a6420),
                      height: 1.5),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                    ),
                    onPressed: () {
                      dismissTimer?.cancel();
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/pro');
                    },
                    child: const Text('Start free trial'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    dismissTimer?.cancel();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Maybe later',
                      style:
                          TextStyle(color: Color(0xFF7a6420))),
                ),
              ],
            ),
          ),
        );
      },
    );
    dismissTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink();
}
