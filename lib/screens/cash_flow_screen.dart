import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';

/// Cash-flow Forecast: 3-month projection from income, recurring
/// bills/subscriptions, and average variable spending.
class CashFlowScreen extends StatelessWidget {
  static const route = '/cash-flow';
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final income = app.profile?.monthlyIncome ?? 0;

    final billsMonthly =
        app.bills.fold(0.0, (s, b) => s + b.amount);
    final subsMonthly =
        app.subscriptions.fold(0.0, (s, x) => s + x.monthlyCost);
    final recurring = billsMonthly + subsMonthly;

    // Average variable spend: expenses over the last 3 full months.
    final now = easternNow();
    double variableTotal = 0;
    int months = 0;
    for (int i = 1; i <= 3; i++) {
      final m = DateTime(now.year, now.month - i, 1);
      final total = app.expenses
          .where((e) =>
              e.spentAt.year == m.year &&
              e.spentAt.month == m.month)
          .fold(0.0, (s, e) => s + e.amount);
      if (total > 0) {
        variableTotal += total;
        months++;
      }
    }
    final avgVariable = months > 0 ? variableTotal / months : 0.0;

    final netMonthly = income - recurring - avgVariable;

    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final projections = <({String label, double balance})>[];
    double running = 0;
    for (int i = 1; i <= 3; i++) {
      final m = DateTime(now.year, now.month + i, 1);
      running += netMonthly;
      projections.add((
        label: '${monthNames[m.month - 1]} ${m.year}',
        balance: running,
      ));
    }
    final maxAbs = projections
        .map((p) => p.balance.abs())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Cash-flow Forecast')),
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
                  Text('Monthly cash flow',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 12),
                  _line('Income', income, true),
                  _line('Bills', billsMonthly, false),
                  _line('Subscriptions', subsMonthly, false),
                  _line(
                      'Avg. other spending${months > 0 ? ' (last $months mo)' : ''}',
                      avgVariable,
                      false),
                  const Divider(height: 20),
                  _line(
                    'Projected net / month',
                    netMonthly,
                    netMonthly >= 0,
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: AppTheme.card3D(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('3-month outlook',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Cumulative balance if patterns hold.',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  for (final p in projections)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p.label,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight:
                                          FontWeight.w600)),
                              Text(
                                '${p.balance < 0 ? '−' : '+'}\$${p.balance.abs().toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.balance >= 0
                                      ? AppColors.deepGreen
                                      : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: maxAbs == 0
                                  ? 0
                                  : p.balance.abs() /
                                      maxAbs,
                              minHeight: 8,
                              backgroundColor:
                                  AppColors.greenSoft,
                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                p.balance >= 0
                                    ? AppColors.deepGreen
                                    : AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: AppTheme.card3D(radius: 18),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      income <= 0
                          ? 'Add your monthly income in Profile to make this forecast accurate.'
                          : netMonthly >= 0
                              ? 'On track — you are projected to save \$${netMonthly.toStringAsFixed(0)} each month.'
                              : 'Heads up — spending is projected to exceed income by \$${(-netMonthly).toStringAsFixed(0)}/mo. Review subscriptions and bills.',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.muted,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            if (income <= 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: 'Set monthly income',
                  icon: Icons.attach_money_rounded,
                  onPressed: () =>
                      _editIncome(context, app),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String label, double value, bool positive,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w400)),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight:
                  bold ? FontWeight.w700 : FontWeight.w600,
              color: positive
                  ? AppColors.deepGreen
                  : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  void _editIncome(BuildContext context, AppState app) {
    final ctrl = TextEditingController(
        text: (app.profile?.monthlyIncome ?? 0)
            .toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly income'),
        content: AppTextField(
            controller: ctrl,
            label: 'Income (USD)',
            keyboardType:
                const TextInputType.numberWithOptions(
                    decimal: true)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && app.profile != null) {
                await app.saveProfile(
                    app.profile!.copyWith(monthlyIncome: v));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
