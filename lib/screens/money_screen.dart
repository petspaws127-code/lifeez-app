import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/category_icon.dart';

/// Simplified Money screen - timeline style, no charts.
class MoneyScreen extends StatelessWidget {
  static const route = '/money';
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final budget = app.monthlyBudget;
    final spent = app.totalSpent;
    final left = app.leftToSpend;
    final saved = app.savingsGoal;

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
          // Budget bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A9C63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\$${left.toStringAsFixed(0)} left this month',
                  style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A9C63))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1A9C63)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Timeline cards
          _moneyCard('money', 'Monthly Budget', '\$${budget.toStringAsFixed(0)}'),
          _moneyCard('bills', 'Spent this month', '\$${spent.toStringAsFixed(0)}'),
          _moneyCard('savings', 'Savings Goal', '\$${saved.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _moneyCard(String icon, String label, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CategoryIcon(category: icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          Text(amount, style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
