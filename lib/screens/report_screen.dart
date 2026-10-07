import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';

/// Monthly AI report with insights generated from the user's real data.
class ReportScreen extends StatelessWidget {
  static const route = '/report';
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final month = DateFormat('MMMM yyyy').format(DateTime.now());
    final income = app.profile?.monthlyIncome ?? 0;
    final budget = app.profile?.monthlyBudget ?? 0;
    final spent = app.spentThisMonth;
    final saved = income - spent;
    final doneTasks = app.completedTasks.length;
    final paidBills =
        app.bills.where((b) => b.paidThisMonth).length;
    final top = app.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: AppTheme.heroGradient(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(month,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 13.5)),
                const SizedBox(height: 4),
                Text('Your month in review',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _mStat('Spent',
                        '\$${spent.toStringAsFixed(0)}'),
                    _mStat('Saved',
                        '\$${saved.toStringAsFixed(0)}'),
                    _mStat('Tasks done', '$doneTasks'),
                    _mStat('Bills paid', '$paidBills'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SectionHeader(title: 'Top categories'),
          if (top.isEmpty)
            const EmptyState(
                message: 'Log some spending to see insights.',
                icon: Icons.insights_outlined)
          else
            ...top.take(5).map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppTheme.card3D(radius: 18),
                  child: ListTile(
                    leading: CategoryIcon(
                        category: e.key.toLowerCase(),
                        size: 42),
                    title: Text(e.key,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    trailing: Text(
                        '\$${e.value.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700)),
                  ),
                )),
          const SizedBox(height: 6),
          const SectionHeader(title: 'AI insights'),
          Container(
            decoration: AppTheme.goldGradient(),
            padding: const EdgeInsets.all(18),
            child: Text(
              _insights(app, income, budget, spent, top),
              style: GoogleFonts.poppins(
                  fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mStat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.white60, fontSize: 11.5)),
          ],
        ),
      );

  String _insights(AppState app, double income, double budget,
      double spent, List<MapEntry<String, double>> top) {
    final buf = StringBuffer();
    if (budget > 0) {
      final pct = (spent / budget * 100).round();
      buf.writeln(
          '• You spent \$${spent.toStringAsFixed(0)} of your \$${budget.toStringAsFixed(0)} budget ($pct%).');
      if (pct > 90) {
        buf.writeln(
            '• You are close to the limit — the last week of the month should be essentials only.');
      } else if (pct < 60) {
        buf.writeln(
            '• Great pacing — you are well under budget with room to save.');
      }
    }
    if (income > 0) {
      buf.writeln(
          '• Savings rate: ${((income - spent) / income * 100).round()}% of income.');
    }
    if (top.isNotEmpty) {
      buf.writeln(
          '• Biggest category: ${top.first.key} at \$${top.first.value.toStringAsFixed(0)}.');
      if (top.length > 1) {
        buf.writeln(
            '• Runner-up: ${top[1].key} at \$${top[1].value.toStringAsFixed(0)}.');
      }
    }
    if (app.unpaidBills.isNotEmpty) {
      buf.writeln(
          '• ${app.unpaidBills.length} bill(s) still unpaid — clear them before month end.');
    }
    if (buf.isEmpty) {
      return 'Use the app for a few days — log spending, add tasks — and I will write your first real report here.';
    }
    buf.writeln(
        '\nKeep telling me things as they happen and next month\u2019s report gets even sharper.');
    return buf.toString();
  }
}
