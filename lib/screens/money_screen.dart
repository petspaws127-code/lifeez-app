import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/command_parser.dart';
import '../models/expense.dart';
import '../models/savings_entry.dart';
import '../services/eastern_time.dart';

class MoneyScreen extends StatelessWidget {
  static const route = '/money';
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final totals = app.categoryTotals;
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Money')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // Income & budget
          Row(
            children: [
              Expanded(
                  child: _statCard(
                      'Income',
                      '\$${(app.profile?.monthlyIncome ?? 0).toStringAsFixed(0)}',
                      'money')),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard(
                      'Budget',
                      '\$${(app.profile?.monthlyBudget ?? 0).toStringAsFixed(0)}',
                      'bills')),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard(
                      'Spent',
                      '\$${app.spentThisMonth.toStringAsFixed(0)}',
                      'shopping')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.heroGradient(),
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Left to spend',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 14)),
                Text(
                  '\$${app.leftToSpend.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Savings — ring, saved this month, goal
          const SectionHeader(title: 'Savings'),
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child:
                                CircularProgressIndicator(
                              value: app.savingsGoalPct,
                              strokeWidth: 12,
                              backgroundColor:
                                  AppColors.greenSoft,
                              valueColor:
                                  const AlwaysStoppedAnimation<
                                      Color>(
                                      AppColors.deepGreen),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(app.savingsGoalPct * 100).round()}%',
                                style:
                                    GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        color: AppColors
                                            .deepGreen),
                              ),
                              Text('of goal',
                                  style:
                                      GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors
                                              .muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Saved this month',
                              style: GoogleFonts.poppins(
                                  color: AppColors.muted,
                                  fontSize: 13)),
                          Text(
                            '\$${app.savedThisMonth.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight:
                                    FontWeight.w800,
                                color:
                                    AppColors.deepGreen),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Goal: \$${(app.profile?.savingsGoal ?? 0).toStringAsFixed(0)}/month',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: AppColors.muted),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style:
                                      OutlinedButton.styleFrom(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        vertical: 10),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  14),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showSavingsSheet(
                                          context),
                                  child: const Text(
                                      'Add savings'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  style:
                                      OutlinedButton.styleFrom(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        vertical: 10),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  14),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showGoalSheet(
                                          context, app),
                                  child:
                                      const Text('Set goal'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (app.savingsGoalPct >= 1)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 12),
                    child: Text(
                      'Goal reached! Amazing discipline.',
                      style: GoogleFonts.poppins(
                          color: AppColors.deepGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5),
                    ),
                  )
                else if ((app.profile?.savingsGoal ??
                        0) >
                    0)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 12),
                    child: Text(
                      _savingsNudge(app),
                      style: GoogleFonts.poppins(
                          color: AppColors.muted,
                          fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category breakdown
          const SectionHeader(title: 'Where your money goes'),
          if (sorted.isEmpty)
            const EmptyState(
                message: 'No spending logged yet this month.',
                icon: Icons.pie_chart_outline)
          else
            Container(
              decoration: AppTheme.card3D(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 190,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 42,
                        sections: sorted
                            .take(6)
                            .map((e) => PieChartSectionData(
                                  value: e.value,
                                  title:
                                      '\$${e.value.toStringAsFixed(0)}',
                                  color: iconFor(e.key.toLowerCase())
                                      .colors
                                      .first,
                                  radius: 52,
                                  titleStyle: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sorted.take(6).map((e) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            CategoryIcon(
                                category: e.key.toLowerCase(),
                                size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(e.key,
                                    style: GoogleFonts.poppins(
                                        fontWeight:
                                            FontWeight.w600))),
                            Text(
                                '\$${e.value.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Expenses
          const SectionHeader(title: 'Recent expenses'),
          if (app.expenses.isEmpty)
            const EmptyState(
                message:
                    'No expenses yet. Say "I spent \$45 at Walmart".',
                icon: Icons.receipt_outlined)
          else
            ...app.expenses.reversed.take(15).map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: AppTheme.card3D(radius: 18),
                    child: ListTile(
                      leading: CategoryIcon(
                          category: e.category.toLowerCase(),
                          size: 42),
                      title: Text(
                          e.note.isEmpty ? e.category : e.note,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${e.category} • ${DateFormat('MMM d').format(e.spentAt)}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.muted),
                      ),
                      trailing: Text(
                        '-\$${e.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700),
                      ),
                      onTap: () =>
                          _showExpenseDetail(context, e),
                    ),
                  ),
                ),
          const SizedBox(height: 8),
          SuggestionCard(
            title: 'Money suggestions',
            suggestions: _moneySuggestions(app),
          ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _statCard(String label, String value, String icon) {
    return Container(
      decoration: AppTheme.card3D(radius: 18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryIcon(category: icon, size: 34),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  List<String> _moneySuggestions(AppState app) {
    final out = <String>[];
    if (app.budgetUsedPct > 0.8) {
      out.add(
          'You are at ${(app.budgetUsedPct * 100).round()}% of budget — pause non-essential shopping this week.');
    }
    final top = app.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (top.isNotEmpty) {
      out.add(
          '${top.first.key} is your top spend (\$${top.first.value.toStringAsFixed(0)}). Set a weekly cap for it.');
    }
    if (app.subscriptionsMonthlyTotal > 0) {
      out.add(
          'Subscriptions cost \$${app.subscriptionsMonthlyTotal.toStringAsFixed(2)}/month — review the Subscriptions screen for ones you forgot.');
    }
    if (out.isEmpty) {
      out.add(
          'Log spending with "I spent \$45 at Walmart" and I will keep the budget bar honest.');
    }
    return out;
  }

  String _savingsNudge(AppState app) {
    final left =
        (app.profile?.savingsGoal ?? 0) - app.savedThisMonth;
    if (left <= 0) return 'Goal reached! Amazing discipline.';
    final day = easternNow().day;
    final daysLeft = 30 - day;
    if (daysLeft <= 0) {
      return 'Month is almost over — \$${left.toStringAsFixed(0)} to go.';
    }
    final perDay = left / daysLeft;
    return 'Save about \$${perDay.toStringAsFixed(0)}/day to hit your goal.';
  }

  void _showSavingsSheet(BuildContext context) {
    final amount = TextEditingController();
    final note = TextEditingController();
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
            Text('Add savings',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppTextField(
                controller: amount,
                label: 'Amount (USD)',
                keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true)),
            AppTextField(
                controller: note,
                label: 'Note (optional)'),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Save',
              onPressed: () async {
                final amt =
                    double.tryParse(amount.text.trim());
                if (amt == null || amt <= 0) return;
                final app = context.read<AppState>();
                await app.addSavingsEntry(SavingsEntry(
                  id: const Uuid().v4(),
                  userId: app.profile?.id ?? '',
                  amount: amt,
                  note: note.text.trim().isEmpty
                      ? null
                      : note.text.trim(),
                  savedAt: easternNow(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalSheet(BuildContext context, AppState app) {
    final goal = TextEditingController(
        text: (app.profile?.savingsGoal ?? 0) > 0
            ? (app.profile!.savingsGoal)
                .toStringAsFixed(0)
            : '');
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
            Text('Monthly savings goal',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppTextField(
                controller: goal,
                label: 'Goal amount (USD)',
                keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true)),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Set goal',
              onPressed: () async {
                final g =
                    double.tryParse(goal.text.trim()) ??
                        0;
                await context
                    .read<AppState>()
                    .setSavingsGoal(g);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final amount = TextEditingController();
    final note = TextEditingController();
    String category = 'Other';
    String? receiptPath;
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
              Text('Add expense',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(
                  controller: amount,
                  label: 'Amount (USD)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              AppTextField(controller: note, label: 'Note (e.g. Walmart)'),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration:
                    const InputDecoration(labelText: 'Category'),
                items: const [
                  'Food',
                  'Grocery',
                  'Transport',
                  'Shopping',
                  'Bills',
                  'Health',
                  'Other'
                ]
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setSheet(() => category = v ?? 'Other'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final src = await showModalBottomSheet<ImageSource>(
                    context: ctx,
                    builder: (c2) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(
                                Icons.photo_camera_rounded),
                            title: const Text('Take photo'),
                            onTap: () => Navigator.pop(
                                c2, ImageSource.camera),
                          ),
                          ListTile(
                            leading: const Icon(
                                Icons.photo_library_rounded),
                            title:
                                const Text('Choose from gallery'),
                            onTap: () => Navigator.pop(
                                c2, ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (src == null) return;
                  final img = await picker.pickImage(
                      source: src,
                      maxWidth: 1024,
                      imageQuality: 80);
                  if (img != null) {
                    setSheet(() => receiptPath = img.path);
                  }
                },
                icon: const Icon(Icons.receipt_long_rounded,
                    size: 18),
                label: Text(receiptPath == null
                    ? 'Attach receipt (optional)'
                    : 'Receipt attached ✓'),
              ),
              if (receiptPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(receiptPath!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Save expense',
                onPressed: () async {
                  final amt = double.tryParse(amount.text.trim());
                  if (amt == null) return;
                  final uid =
                      context.read<AppState>().profile?.id ?? '';
                  final cat = note.text.trim().isEmpty
                      ? category
                      : CommandParser.detectExpenseCategory(
                          '${note.text} $category');
                  await context.read<AppState>().addExpense(Expense(
                        id: const Uuid().v4(),
                        userId: uid,
                        amount: amt,
                        category: cat,
                        note: note.text.trim(),
                        spentAt: easternNow(),
                        receiptPath: receiptPath,
                      ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Expense detail: shows info + receipt photo, with delete.
  void _showExpenseDetail(BuildContext context, Expense e) {
    final app = context.read<AppState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '-\$${e.amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${e.category} • ${DateFormat('MM/dd/yyyy').format(e.spentAt)}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.muted)),
              if (e.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(e.note,
                    style: GoogleFonts.poppins(fontSize: 14)),
              ],
              const SizedBox(height: 12),
              if ((e.receiptPath ?? '').isNotEmpty)
                GestureDetector(
                  onTap: () => showDialog(
                    context: ctx,
                    builder: (_) => Dialog(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                            File(e.receiptPath!)),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(e.receiptPath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Text('No receipt attached.',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.muted)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _attachReceiptToExpense(context, e);
            },
            child: Text((e.receiptPath ?? '').isEmpty
                ? 'Add receipt'
                : 'Replace receipt'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await app.deleteExpense(e.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _attachReceiptToExpense(
      BuildContext context, Expense e) async {
    final picker = ImagePicker();
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c2) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_camera_rounded),
              title: const Text('Take photo'),
              onTap: () =>
                  Navigator.pop(c2, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.pop(c2, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null || !context.mounted) return;
    final img = await picker.pickImage(
        source: src, maxWidth: 1024, imageQuality: 80);
    if (img == null || !context.mounted) return;
    await context.read<AppState>().updateExpense(
          Expense(
            id: e.id,
            userId: e.userId,
            amount: e.amount,
            category: e.category,
            note: e.note,
            spentAt: e.spentAt,
            source: e.source,
            receiptPath: img.path,
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt attached.')),
      );
    }
  }
}
