import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';

/// Budget Guard: watches spending against the monthly budget and
/// flags categories that spike above their usual average.
class BudgetGuardScreen extends StatelessWidget {
  static const route = '/budget-guard';
  const BudgetGuardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final budget = app.profile?.monthlyBudget ?? 0;
    final spent = app.spentThisMonth;
    final pct = budget > 0 ? spent / budget : 0.0;

    final status = budget <= 0
        ? const _GuardStatus('Set a budget',
            'Add your monthly budget to activate Budget Guard.', AppColors.muted, 0)
        : pct >= 1
            ? _GuardStatus(
                'Over budget',
                'You have spent \$${(spent - budget).toStringAsFixed(2)} more than your budget.',
                AppColors.danger,
                1)
            : pct >= 0.9
                ? _GuardStatus(
                    'Danger zone',
                    'You have used ${(pct * 100).toStringAsFixed(0)}% of your budget.',
                    AppColors.danger,
                    pct)
                : pct >= 0.7
                    ? _GuardStatus(
                        'Watch it',
                        'You have used ${(pct * 100).toStringAsFixed(0)}% of your budget.',
                        const Color(0xFFB45309),
                        pct)
                    : _GuardStatus(
                        'On track',
                        'You have used ${(pct * 100).toStringAsFixed(0)}% of your budget.',
                        AppColors.deepGreen,
                        pct);

    // Category spike detection vs 3-month average.
    final now = easternNow();
    final thisMonth = <String, double>{};
    for (final e in app.expenses.where((e) =>
        e.spentAt.year == now.year &&
        e.spentAt.month == now.month)) {
      thisMonth[e.category] =
          (thisMonth[e.category] ?? 0) + e.amount;
    }
    final spikes = <({String cat, double nowAmt, double avg})>[];
    for (final entry in thisMonth.entries) {
      double total = 0;
      for (int i = 1; i <= 3; i++) {
        final m = DateTime(now.year, now.month - i, 1);
        total += app.expenses
            .where((e) =>
                e.category == entry.key &&
                e.spentAt.year == m.year &&
                e.spentAt.month == m.month)
            .fold(0.0, (s, e) => s + e.amount);
      }
      final avg = total / 3;
      if (avg > 0 && entry.value > avg * 1.5) {
        spikes.add((cat: entry.key, nowAmt: entry.value, avg: avg));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Budget Guard')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              decoration: AppTheme.card3D(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: AppTheme.tile3D(
                          [status.color, status.color],
                          radius: 14,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(status.title,
                                style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: status.color)),
                            Text(status.body,
                                style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Spent',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.muted)),
                      Text(
                        '\$${spent.toStringAsFixed(2)} of \$${budget.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 12,
                      backgroundColor: AppColors.greenSoft,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(
                              status.color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionHeader(title: 'Spending alerts'),
            const SizedBox(height: 4),
            if (spikes.isEmpty)
              _alert(
                Icons.check_circle_rounded,
                AppColors.deepGreen,
                'No unusual spikes',
                'No category is spending far above its usual average this month.',
              ),
            for (final s in spikes)
              _alert(
                Icons.trending_up_rounded,
                const Color(0xFFB45309),
                '${s.cat} is spiking',
                '\$${s.nowAmt.toStringAsFixed(0)} this month vs \$${s.avg.toStringAsFixed(0)} average — '
                    '${((s.nowAmt / s.avg - 1) * 100).toStringAsFixed(0)}% above normal.',
              ),
            if (budget > 0 && pct >= 0.9)
              _alert(
                Icons.warning_amber_rounded,
                AppColors.danger,
                'Slow down for the rest of the month',
                'You have \$${(budget - spent).clamp(0, double.infinity).toStringAsFixed(2)} left. '
                    'Consider pausing non-essential spending.',
              ),
            if (budget <= 0) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: 'Set monthly budget',
                  icon: Icons.savings_outlined,
                  onPressed: () =>
                      Navigator.pushNamed(context, '/money'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alert(
      IconData icon, Color color, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.card3D(radius: 18),
      child: ListTile(
        leading: Container(
          decoration: AppTheme.tile3D([color, color], radius: 14),
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(body,
            style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.muted,
                height: 1.5)),
      ),
    );
  }
}

class _GuardStatus {
  final String title;
  final String body;
  final Color color;
  final double pct;
  const _GuardStatus(this.title, this.body, this.color, this.pct);
}
