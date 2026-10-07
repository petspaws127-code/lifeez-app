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
import '../services/whatsapp_service.dart';
import '../services/eastern_time.dart';
import 'ai_assistant_screen.dart';
import 'bills_screen.dart';
import 'budget_guard_screen.dart';
import 'calendar_screen.dart';
import 'car_screen.dart';
import 'cash_flow_screen.dart';
import 'documents_screen.dart';
import 'family_screen.dart';
import 'habits_screen.dart';
import 'lent_borrowed_screen.dart';
import 'money_screen.dart';
import 'my_day_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'referrals_screen.dart';
import 'reminders_screen.dart';
import 'report_screen.dart';
import 'scanner_screen.dart';
import 'shopping_screen.dart';
import 'subscription_audit_screen.dart';
import 'subscriptions_screen.dart';
import 'tasks_screen.dart';
import 'whatsapp_chat_screen.dart';

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

              // 2. WhatsApp connect card — compact.
              const _WhatsAppHomeCard(),
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

              // 4. Features grid — 12 feature cards.
              const SectionHeader(title: 'Features'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.0,
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
                  _featureCard(context, 'Shopping', 'grocery',
                      ShoppingScreen.route),
                  _featureCard(context, 'Habits', 'habit',
                      HabitsScreen.route),
                  _featureCard(context, 'My Day', 'myday',
                      MyDayScreen.route),
                  _featureCard(context, 'Documents', 'document',
                      DocumentsScreen.route),
                  _featureCard(context, 'Subscriptions',
                      'subscription', SubscriptionsScreen.route),
                  _featureCard(context, 'Scanner', 'scan',
                      ScannerScreen.route),
                  _featureCard(context, 'Alerts', 'notification',
                      NotificationsScreen.route),
                ],
              ),
              const SizedBox(height: 16),

              // 5. Today — compact, max 3 tasks.
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
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CategoryIcon(category: category, size: 40),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet opened by the "+" FAB: the extra features.
  void _showMoreFeatures(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                'More features',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: [
                  // Closing the sheet and navigating both use the
                  // outer (home) context; the sheet route is on the
                  // same Navigator, so this pops exactly the sheet.
                  _moreFeatureTile(context,
                      label: 'AI Assistant',
                      category: 'brain',
                      route: AiAssistantScreen.route),
                  _moreFeatureTile(context,
                      label: 'WhatsApp Chat',
                      icon: Icons.chat_bubble_rounded,
                      colors: const [
                        AppColors.whatsapp,
                        AppColors.whatsappDark
                      ],
                      route: WhatsAppChatScreen.route),
                  _moreFeatureTile(context,
                      label: 'Lent & Borrowed',
                      icon: Icons.handshake_outlined,
                      route: LentBorrowedScreen.route),
                  _moreFeatureTile(context,
                      label: 'Subscription Audit',
                      category: 'subscription',
                      route: SubscriptionAuditScreen.route),
                  _moreFeatureTile(context,
                      label: 'Cash-flow Forecast',
                      icon: Icons.trending_up_rounded,
                      route: CashFlowScreen.route),
                  _moreFeatureTile(context,
                      label: 'Budget Guard',
                      icon: Icons.shield_outlined,
                      route: BudgetGuardScreen.route),
                  _moreFeatureTile(context,
                      label: 'Family',
                      category: 'family',
                      route: FamilyScreen.route),
                  _moreFeatureTile(context,
                      label: 'My Car',
                      icon: Icons.directions_car_rounded,
                      route: CarScreen.route),
                  _moreFeatureTile(context,
                      label: 'Refer & Earn',
                      category: 'share',
                      route: ReferralsScreen.route),
                  _moreFeatureTile(context,
                      label: 'Monthly Report',
                      icon: Icons.bar_chart_rounded,
                      route: ReportScreen.route),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreFeatureTile(BuildContext context,
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
        decoration: AppTheme.card3D(radius: 18),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            if (category != null)
              CategoryIcon(category: category, size: 38)
            else
              Container(
                width: 38,
                height: 38,
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 20),
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

/// Compact WhatsApp command center at the top of Home.
class _WhatsAppHomeCard extends StatelessWidget {
  const _WhatsAppHomeCard();

  @override
  Widget build(BuildContext context) {
    final wa = context.watch<WhatsAppService>();
    return Container(
      decoration: AppTheme.card3D(),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            decoration: AppTheme.tile3D(
              const [
                AppColors.whatsapp,
                AppColors.whatsappDark
              ],
              radius: 13,
            ),
            padding: const EdgeInsets.all(9),
            child: Icon(
              wa.isConnected
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
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
                  wa.isConnected
                      ? 'WhatsApp connected'
                      : 'WhatsApp',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5),
                ),
                Text(
                  wa.isConnected
                      ? (wa.phoneNumber ?? '')
                      : 'Control the app by text or voice',
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
          GradientButton(
            label: wa.isConnected ? 'Chat' : 'Connect',
            colors: const [
              AppColors.whatsapp,
              AppColors.whatsappDark
            ],
            onPressed: () => wa.isConnected
                ? Navigator.pushNamed(
                    context, WhatsAppChatScreen.route)
                : _showConnectSheet(context),
          ),
        ],
      ),
    );
  }

  void _showConnectSheet(BuildContext context) {
    final phone = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Connect WhatsApp',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Enter your WhatsApp number. A verification code will be sent via WhatsApp.',
              style: GoogleFonts.poppins(
                  color: AppColors.muted, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            AppTextField(
                controller: phone,
                label: 'WhatsApp number (e.g. +1 555 123 4567)',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Connect',
              colors: const [
                AppColors.whatsapp,
                AppColors.whatsappDark
              ],
              onPressed: () async {
                final number = phone.text.trim();
                if (number.length < 7) return;
                Navigator.pop(ctx);
                await context
                    .read<WhatsAppService>()
                    .directConnect(number);
              },
            ),
          ],
        ),
      ),
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
