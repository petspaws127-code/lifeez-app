import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
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
      body: ListView(
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

  void _showAddSheet(BuildContext context) {
    final amount = TextEditingController();
    final note = TextEditingController();
    String category = 'Other';
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
                        spentAt: DateTime.now(),
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
}
