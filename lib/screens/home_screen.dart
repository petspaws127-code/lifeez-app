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
import '../services/whatsapp_service.dart';
import 'whatsapp_chat_screen.dart';
import 'tasks_screen.dart';
import 'money_screen.dart';
import 'reminders_screen.dart';
import 'bills_screen.dart';
import 'shopping_screen.dart';

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
                  Container(
                    decoration: AppTheme.tile3D(
                      const [AppColors.deepGreen, AppColors.greenMid],
                      radius: 16,
                    ),
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Text(
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
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_daypart()},',
                        style: GoogleFonts.poppins(
                            color: AppColors.muted, fontSize: 13),
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
                ],
              ),
              const SizedBox(height: 14),

              // WhatsApp connect card — FIRST, per WhatsApp-first design.
              const _WhatsAppHomeCard(),
              const SizedBox(height: 14),

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
    final h = DateTime.now().hour;
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
