import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_input_bar.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/assistant_engine.dart';
import '../services/update_service.dart';
import '../services/whatsapp_service.dart';
import 'whatsapp_chat_screen.dart';
import 'tasks_screen.dart';
import 'money_screen.dart';
import 'reminders_screen.dart';
import 'bills_screen.dart';
import 'shopping_screen.dart';
import 'notifications_screen.dart';
import 'my_day_screen.dart';
import 'habits_screen.dart';
import 'pets_screen.dart';
import 'profile_screen.dart';
import '../services/eastern_time.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleAi(BuildContext context, String text) async {
    final engine = AssistantEngine(context.read<AppState>());
    final reply = await engine.handleText(text);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lifeez'),
        content: Text(reply),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = app.profile?.name ?? 'there';
    final firstName = name.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => app.loadAll(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Greeting
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
              const SizedBox(height: 14),

              // WhatsApp connect card — FIRST, per WhatsApp-first design.
              const _WhatsAppHomeCard(),
              const SizedBox(height: 14),

              // Auto-carousel: tips & promos.
              const _HomeCarousel(),
              const SizedBox(height: 14),

              // Triggers the Go Pro popup (throttled, auto-dismissing).
              const _GoProPopupHost(),

              // Hero: left to spend
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
              const SizedBox(height: 14),

              // At a glance
              Row(
                children: [
                  _glanceTile(context, 'Open tasks',
                      '${app.openTasks.length}', 'task'),
                  const SizedBox(width: 10),
                  _glanceTile(context, 'Bills due',
                      '${app.unpaidBills.length}', 'bills'),
                  const SizedBox(width: 10),
                  _glanceTile(context, 'Reminders',
                      '${app.activeReminders.length}', 'reminder'),
                  const SizedBox(width: 10),
                  _glanceTile(context, 'To buy',
                      '${app.shoppingToBuy.length}', 'grocery'),
                ],
              ),
              const SizedBox(height: 14),

              // My Day preview
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                    context, MyDayScreen.route),
                child: Container(
                  decoration: AppTheme.card3D(),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CategoryIcon(
                          category: 'myday', size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('My Day',
                                style: GoogleFonts.poppins(
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 15.5)),
                            Text(
                              app.openBrainDumps.isEmpty
                                  ? 'Briefing + brain-dump inbox'
                                  : '${app.openBrainDumps.length} thought${app.openBrainDumps.length == 1 ? '' : 's'} in your inbox',
                              style: GoogleFonts.poppins(
                                  color: AppColors.muted,
                                  fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Habits + Pets row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(
                          context, HabitsScreen.route),
                      child: Container(
                        decoration:
                            AppTheme.card3D(radius: 18),
                        padding:
                            const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const CategoryIcon(
                                category: 'habit',
                                size: 40),
                            const SizedBox(height: 8),
                            Text(
                                '${app.habitsDoneToday}/${app.habits.length}',
                                style:
                                    GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight:
                                            FontWeight.w800)),
                            Text('Habits today',
                                style:
                                    GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color:
                                            AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(
                          context, PetsScreen.route),
                      child: Container(
                        decoration:
                            AppTheme.card3D(radius: 18),
                        padding:
                            const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const CategoryIcon(
                                category: 'pet',
                                size: 40),
                            const SizedBox(height: 8),
                            Text(
                                '${app.allPetReminders.length}',
                                style:
                                    GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight:
                                            FontWeight.w800)),
                            Text('Pet reminders',
                                style:
                                    GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color:
                                            AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // AI input
              AiInputBar(
                  onSubmit: (t) => _handleAi(context, t)),
              const SizedBox(height: 14),

              // Quick actions
              const SectionHeader(title: 'Quick actions'),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceAround,
                children: [
                  _quickAction(context, 'Task', 'task',
                      TasksScreen.route),
                  _quickAction(context, 'Expense', 'money',
                      MoneyScreen.route),
                  _quickAction(context, 'Reminder', 'reminder',
                      RemindersScreen.route),
                  _quickAction(context, 'Bill', 'bills',
                      BillsScreen.route),
                  _quickAction(context, 'Shopping', 'grocery',
                      ShoppingScreen.route),
                ],
              ),
              const SizedBox(height: 8),

              // Today
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

              // Coming up
              const SectionHeader(title: 'Coming up'),
              if (app.unpaidBills.isEmpty)
                const EmptyState(
                    message: 'No upcoming bills. You are all clear.',
                    icon: Icons.receipt_long_outlined)
              else
                ...app.unpaidBills.take(3).map(
                      (b) => Container(
                        margin:
                            const EdgeInsets.only(bottom: 10),
                        decoration: AppTheme.card3D(radius: 18),
                        child: ListTile(
                          leading: const CategoryIcon(
                              category: 'bills', size: 42),
                          title: Text(b.name,
                              style: GoogleFonts.poppins(
                                  fontWeight:
                                      FontWeight.w600)),
                          subtitle: Text('Due on the ${b.dueDay}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: AppColors.muted)),
                          trailing: Text(
                            '\$${b.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepGreen),
                          ),
                        ),
                      ),
                    ),

              const SizedBox(height: 6),
              SuggestionCard(
                title: 'AI tip',
                suggestions: [_aiTip(app)],
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

  Widget _glanceTile(
      BuildContext context, String label, String value, String icon) {
    return Expanded(
      child: Container(
        decoration: AppTheme.card3D(radius: 18),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            CategoryIcon(category: icon, size: 36),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10.5, color: AppColors.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, String label,
      String icon, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        children: [
          CategoryIcon(category: icon, size: 52),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 12)),
        ],
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

  String _aiTip(AppState app) {
    if (app.budgetUsedPct > 0.85) {
      return 'You have used ${(app.budgetUsedPct * 100).round()}% of your budget — consider slowing down discretionary spending.';
    }
    final top = app.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (top.isNotEmpty) {
      return 'Your biggest spending category this month is ${top.first.key} at \$${top.first.value.toStringAsFixed(0)}.';
    }
    if (app.unpaidBills.isNotEmpty) {
      return '${app.unpaidBills.first.name} is due on the ${app.unpaidBills.first.dueDay} — mark it paid from the Bills screen.';
    }
    return 'Tell me things like "I spent \$45 at Walmart" and I will track everything for you.';
  }
}

/// WhatsApp command center at the top of Home.
class _WhatsAppHomeCard extends StatelessWidget {
  const _WhatsAppHomeCard();

  @override
  Widget build(BuildContext context) {
    final wa = context.watch<WhatsAppService>();
    return Container(
      decoration: AppTheme.card3D(),
      padding: const EdgeInsets.all(16),
      child: wa.isConnected
          ? Row(
              children: [
                Container(
                  decoration: AppTheme.tile3D(
                    const [
                      AppColors.whatsapp,
                      AppColors.whatsappDark
                    ],
                    radius: 14,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.whatsapp,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'WhatsApp connected',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5),
                          ),
                        ],
                      ),
                      Text(
                        wa.phoneNumber ?? '',
                        style: GoogleFonts.poppins(
                            color: AppColors.muted,
                            fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                GradientButton(
                  label: 'Open chat',
                  colors: const [
                    AppColors.whatsapp,
                    AppColors.whatsappDark
                  ],
                  onPressed: () => Navigator.pushNamed(
                      context, WhatsAppChatScreen.route),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: AppTheme.tile3D(
                        const [
                          AppColors.whatsapp,
                          AppColors.whatsappDark
                        ],
                        radius: 14,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white,
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Manage everything through WhatsApp',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect your number, then send text or voice notes and the app updates itself.',
                  style: GoogleFonts.poppins(
                      color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Direct Connect WhatsApp',
                    icon: Icons.bolt_rounded,
                    colors: const [
                      AppColors.whatsapp,
                      AppColors.whatsappDark
                    ],
                    onPressed: () =>
                        _showConnectSheet(context),
                  ),
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

/// Auto-advancing carousel of tips and promos on Home.
class _HomeCarousel extends StatefulWidget {
  const _HomeCarousel();

  @override
  State<_HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<_HomeCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final app = context.read<AppState>();
      final count = _cards
          .where((c) =>
              c.route != '/pro' || !(app.profile?.isPro ?? false))
          .length;
      if (count == 0) return;
      final next = (_page + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<({String title, String body, String cta, String route, List<Color> colors, IconData icon})>
      get _cards => [
            (
              title: 'Go Pro — 14 days free',
              body: 'Unlock AI insights, unlimited history, and priority features.',
              cta: 'Start trial',
              route: '/pro',
              colors: const [Color(0xFF8a6d1c), AppColors.gold],
              icon: Icons.workspace_premium_rounded,
            ),
            (
              title: 'Savings ring',
              body: 'Watch your savings grow and hit your monthly goal.',
              cta: 'View savings',
              route: '/money',
              colors: const [AppColors.deepGreen, AppColors.greenMid],
              icon: Icons.savings_outlined,
            ),
            (
              title: 'Refer & earn Pro days',
              body: 'Every 3 friends who join = 30 free Pro days for you.',
              cta: 'Invite friends',
              route: '/referrals',
              colors: const [Color(0xFF22C55E), Color(0xFF15803D)],
              icon: Icons.group_add_outlined,
            ),
            (
              title: 'Budget Guard',
              body: 'Get warned before spending runs past your budget.',
              cta: 'Check status',
              route: '/budget-guard',
              colors: const [Color(0xFF146B4F), Color(0xFF0C3B2E)],
              icon: Icons.shield_outlined,
            ),
          ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Hide the Pro card for Pro users.
    final cards = _cards
        .where((c) => c.route != '/pro' || !(app.profile?.isPro ?? false))
        .toList();
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final c = cards[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: c.colors,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x300C3B2E),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(c.icon, color: Colors.white, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(c.title,
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(c.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, c.route),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: c.colors.first,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(c.cta,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < cards.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _page == i
                      ? AppColors.deepGreen
                      : AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
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
