import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/subscription.dart';

/// Subscription Audit: total cost, duplicates, and money-saving tips.
class SubscriptionAuditScreen extends StatelessWidget {
  static const route = '/subscription-audit';
  const SubscriptionAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final subs = app.subscriptions;
    final monthlyTotal =
        subs.fold(0.0, (s, x) => s + x.monthlyCost);
    final yearlyTotal = monthlyTotal * 12;

    // Duplicate detection: same normalized name appears twice.
    final byName = <String, List<Subscription>>{};
    for (final s in subs) {
      final key = s.name.trim().toLowerCase();
      byName.putIfAbsent(key, () => []).add(s);
    }
    final duplicates =
        byName.values.where((l) => l.length > 1).toList();

    // Yearly-billing tip: monthly plans costing more than an
    // equivalent yearly plan would (assume ~2 months free).
    final monthlyPlans =
        subs.where((s) => s.billingCycle == 'monthly').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Audit')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              decoration: AppTheme.heroGradient(radius: 24),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CategoryIcon(
                      category: 'subscription', size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('${subs.length} subscriptions',
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13)),
                        Text(
                            '\$${monthlyTotal.toStringAsFixed(2)}/mo',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700)),
                        Text(
                            '\$${yearlyTotal.toStringAsFixed(2)} per year',
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionHeader(title: 'Findings'),
            const SizedBox(height: 4),
            if (subs.isEmpty)
              const EmptyState(
                message:
                    'No subscriptions yet. Add them in the Subscriptions tab to audit them here.',
                icon: Icons.autorenew_rounded,
              ),
            if (duplicates.isEmpty && subs.isNotEmpty)
              _finding(
                Icons.check_circle_rounded,
                AppColors.deepGreen,
                'No duplicates found',
                'Every subscription appears only once. Nice and clean.',
              ),
            for (final group in duplicates)
              _finding(
                Icons.content_copy_rounded,
                AppColors.danger,
                'Possible duplicate: ${group.first.name}',
                '${group.length} entries for the same service costing '
                    '\$${group.fold(0.0, (s, x) => s + x.monthlyCost).toStringAsFixed(2)}/mo combined. '
                    'Remove the extra one in Subscriptions.',
                onTap: () =>
                    Navigator.pushNamed(context, '/subscriptions'),
              ),
            if (monthlyPlans.isNotEmpty)
              _finding(
                Icons.savings_outlined,
                AppColors.gold,
                'Yearly billing could save money',
                '${monthlyPlans.length} monthly plan${monthlyPlans.length == 1 ? '' : 's'}. '
                    'Many services discount ~2 months for yearly billing — '
                    'you could save up to \$${(monthlyTotal * 2).toStringAsFixed(0)}/yr.',
              ),
            if (monthlyTotal >
                (app.profile?.monthlyBudget ?? 0) * 0.2 &&
                (app.profile?.monthlyBudget ?? 0) > 0)
              _finding(
                Icons.warning_amber_rounded,
                AppColors.danger,
                'Subscriptions eat a big share of your budget',
                'They are \$${monthlyTotal.toStringAsFixed(2)}/mo — over 20% of your '
                    '\$${app.profile!.monthlyBudget.toStringAsFixed(0)} budget. '
                    'Consider pausing one you rarely use.',
              ),
            const SizedBox(height: 8),
            const SectionHeader(title: 'All subscriptions'),
            const SizedBox(height: 4),
            for (final s in subs)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: AppTheme.card3D(radius: 16),
                child: ListTile(
                  leading: const CategoryIcon(
                      category: 'subscription', size: 40),
                  title: Text(s.name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  subtitle: Text(s.billingCycle,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.muted)),
                  trailing: Text(
                    '\$${s.amount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _finding(IconData icon, Color color, String title,
      String body,
      {VoidCallback? onTap}) {
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
        trailing: onTap != null
            ? const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted)
            : null,
        onTap: onTap,
      ),
    );
  }
}
