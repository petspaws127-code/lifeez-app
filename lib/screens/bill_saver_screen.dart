import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/subscription.dart';

/// Bill Saver: finds cheaper alternatives and shows potential savings.
class BillSaverScreen extends StatelessWidget {
  static const route = '/bill-saver';
  const BillSaverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final subs = app.subscriptions;

    final savings = _calculateSavings(subs);
    final totalYearlySavings =
        savings.fold(0.0, (s, x) => s + x.yearlySavings);

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Saver')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              decoration: AppTheme.heroGradient(radius: 24),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CategoryIcon(
                          category: 'money', size: 54),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Potential Savings',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '\$${totalYearlySavings.toStringAsFixed(0)}/year',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Switch to cheaper plans and save real money!',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (savings.isEmpty)
              const EmptyState(
                icon: Icons.savings_outlined,
                message: 'Add subscriptions to find cheaper alternatives.',
              )
            else
              ...savings.map((s) => _SavingsCard(saving: s)),
          ],
        ),
      ),
    );
  }

  List<_Saving> _calculateSavings(List<Subscription> subs) {
    final result = <_Saving>[];
    for (final sub in subs) {
      final cheaper = _findCheaperAlternative(sub);
      if (cheaper != null) {
        result.add(_Saving(
          subscription: sub,
          alternativeName: cheaper['name'] as String,
          alternativePrice: cheaper['price'] as double,
        ));
      }
    }
    return result;
  }

  Map<String, dynamic>? _findCheaperAlternative(
      Subscription sub) {
    final name = sub.name.toLowerCase();
    final current = sub.monthlyCost;

    if (name.contains('netflix') && current > 7) {
      return {'name': 'Netflix with Ads', 'price': 6.99};
    }
    if (name.contains('spotify') && current > 6) {
      return {'name': 'Spotify Student', 'price': 5.99};
    }
    if (name.contains('gym') && current > 30) {
      return {'name': 'Planet Fitness', 'price': 25.0};
    }
    return null;
  }
}

class _Saving {
  final Subscription subscription;
  final String alternativeName;
  final double alternativePrice;

  _Saving({
    required this.subscription,
    required this.alternativeName,
    required this.alternativePrice,
  });

  double get monthlySavings =>
      subscription.monthlyCost - alternativePrice;
  double get yearlySavings => monthlySavings * 12;
}

class _SavingsCard extends StatelessWidget {
  final _Saving saving;
  const _SavingsCard({required this.saving});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  saving.subscription.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A9C63).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Save \$${saving.yearlySavings.toStringAsFixed(0)}/yr',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A9C63),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Current: \$${saving.subscription.monthlyCost.toStringAsFixed(2)}/mo',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Text(
            'Switch to: ${saving.alternativeName} - \$${saving.alternativePrice.toStringAsFixed(2)}/mo',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF1A9C63),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
