import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/subscription.dart';

class SubscriptionsScreen extends StatelessWidget {
  static const route = '/subscriptions';
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Container(
            decoration: AppTheme.heroGradient(),
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly total',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 14)),
                Text(
                  '\$${app.subscriptionsMonthlyTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (app.subscriptions.isEmpty)
            const EmptyState(
                message:
                    'No subscriptions. Say "add subscription Netflix \$15.99".',
                icon: Icons.autorenew_outlined)
          else
            ...app.subscriptions.map(
              (s) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.card3D(radius: 18),
                child: ListTile(
                  leading: const CategoryIcon(
                      category: 'subscription', size: 44),
                  title: Text(s.name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${s.billingCycle} • renews ${s.renewalDay}',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.muted)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${s.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                        onPressed: () =>
                            app.deleteSubscription(s.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SuggestionCard(
            title: 'Subscription suggestions',
            suggestions: [
              if (app.subscriptionsMonthlyTotal > 50)
                'You spend \$${app.subscriptionsMonthlyTotal.toStringAsFixed(0)}/month on subscriptions — cancel one you barely use to save \$${(app.subscriptionsMonthlyTotal / 2).toStringAsFixed(0)}.',
              'Yearly plans are usually 15–20% cheaper than monthly for services you keep.',
              if (app.subscriptions.isEmpty)
                'Track Netflix, Spotify and more here so nothing renews by surprise.',
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final name = TextEditingController();
    final amount = TextEditingController();
    String cycle = 'monthly';
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
              Text('Add subscription',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(
                  controller: name, label: 'Name (e.g. Netflix)'),
              AppTextField(
                  controller: amount,
                  label: 'Amount (USD)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              DropdownButtonFormField<String>(
                initialValue: cycle,
                decoration:
                    const InputDecoration(labelText: 'Billing cycle'),
                items: const ['monthly', 'yearly']
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setSheet(() => cycle = v ?? 'monthly'),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Save subscription',
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final uid =
                      context.read<AppState>().profile?.id ?? '';
                  await context.read<AppState>().addSubscription(
                        Subscription(
                          id: const Uuid().v4(),
                          userId: uid,
                          name: name.text.trim(),
                          amount: double.tryParse(
                                  amount.text.trim()) ??
                              0,
                          renewalDay: DateTime.now().day,
                          billingCycle: cycle,
                        ),
                      );
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
