import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';

/// Lifeez Pro — 14-day free trial, then $4.99/month or $39/year.
/// Mock purchase flow (test mode, no real charge).
class ProScreen extends StatefulWidget {
  static const route = '/pro';
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  String _plan = 'monthly'; // monthly | yearly
  bool _busy = false;

  static const _prices = {
    'monthly': 4.99,
    'yearly': 39.0,
  };

  Future<void> _startTrial() async {
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    await app.startProTrial();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Pro trial started — 14 days free.')),
    );
  }

  Future<void> _buy() async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm purchase'),
        content: Text(
          _plan == 'monthly'
              ? 'Lifeez Pro Monthly — \$4.99 every 30 days.\n\nTest mode: no real charge.'
              : 'Lifeez Pro Yearly — \$39 every 360 days (save 35%).\n\nTest mode: no real charge.',
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Subscribe')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await app.purchasePro(_plan);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Welcome to Lifeez Pro!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isPro = app.profile?.isPro ?? false;
    final trialLeft = app.trialDaysLeft;
    final renews = app.profile?.proRenewsAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Lifeez Pro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: AppTheme.goldGradient(),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CategoryIcon(
                        category: 'pro', size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isPro
                            ? 'You are Pro'
                            : 'Upgrade to Pro',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isPro) ...[
                  if (trialLeft != null && trialLeft > 0)
                    Text(
                      '$trialLeft day${trialLeft == 1 ? '' : 's'} left in your free trial.',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  if (renews != null)
                    Text(
                      'Renews ${DateFormat('MM/dd/yyyy').format(renews)} • ${app.profile?.proPlan == 'yearly' ? '\$39/year' : '\$4.99/month'}',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5),
                    ),
                ] else
                  Text(
                    'Unlimited AI, priority reminders, and every premium feature.',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!isPro) ...[
            const SectionHeader(title: 'Choose a plan'),
            _planCard(
              'monthly',
              'Monthly',
              '\$4.99',
              'per 30 days',
              'Flexible — cancel anytime.',
            ),
            const SizedBox(height: 10),
            _planCard(
              'yearly',
              'Yearly',
              '\$39',
              'per 360 days',
              'Best value — save 35%.',
              badge: 'BEST VALUE',
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: _busy
                  ? 'Please wait…'
                  : 'Start 14-day free trial',
              icon: Icons.bolt_rounded,
              onPressed:
                  _busy ? null : () => _startTrial(),
              colors: const [
                AppColors.gold,
                Color(0xFF926F0E)
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18)),
                ),
                onPressed: _busy ? null : _buy,
                child: Text(
                  'Subscribe now — \$${_prices[_plan]!.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepGreen),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Test mode: no real charge will be made.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.muted),
            ),
          ] else ...[
            const SectionHeader(title: 'Pro perks'),
            _perk('Unlimited AI commands & advice'),
            _perk('Smart reminders that nag until done'),
            _perk('Full pet tools & vaccination tracking'),
            _perk('Priority support'),
            const SizedBox(height: 16),
            if (app.profile?.proPlan != null &&
                app.profile?.proPlan != 'none')
              TextButton(
                onPressed: () => _cancel(context, app),
                child: Text('Cancel subscription',
                    style: GoogleFonts.poppins(
                        color: AppColors.danger,
                        fontSize: 14)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _planCard(String id, String name, String price,
      String per, String note,
      {String? badge}) {
    final selected = _plan == id;
    return GestureDetector(
      onTap: () => setState(() => _plan = id),
      child: Container(
        decoration: AppTheme.card3D(radius: 20),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: AppColors.deepGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.goldSoft,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Text(badge,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w800,
                                  color:
                                      AppColors.deepGreen)),
                        ),
                      ],
                    ],
                  ),
                  Text(note,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen)),
                Text(per,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _perk(String label) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppTheme.card3D(radius: 16),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.deepGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Future<void> _cancel(
      BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Pro?'),
        content: const Text(
            'You will keep Pro until the end of the current period.'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Keep Pro')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Cancel',
                  style:
                      TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) await app.cancelPro();
  }
}
