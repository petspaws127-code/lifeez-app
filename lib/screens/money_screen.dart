import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/category_icon.dart';

/// Simplified Money screen - premium timeline style, no charts.
class MoneyScreen extends StatelessWidget {
  static const route = '/money';
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final budget = app.monthlyBudget;
    final spent = app.spentThisMonth;
    final left = app.leftToSpend;
    final saved = app.savingsGoal;
    final pct = app.budgetUsedPct;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        title: Text('Money', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.ivory,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A9C63).withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\$${left.toStringAsFixed(0)} left',
                  style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A9C63))),
                Text('of \$${budget.toStringAsFixed(0)} budget',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1A9C63)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card('money', 'Monthly Budget', budget),
          _card('bills', 'Spent this month', spent),
          _card('savings', 'Savings Goal', saved),
        ],
      ),
    );
  }

  Widget _card(String icon, String label, double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CategoryIcon(category: icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Text('\$${amount.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
