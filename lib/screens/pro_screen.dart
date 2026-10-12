import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/v2_kit.dart';

/// V2 Lifeez Pro paywall — green hero, feature checklist,
/// Monthly $4.99 / Yearly $39 (Best value) cards, free-trial button.
/// Full-screen route with V2SubNav.
class ProScreen extends StatefulWidget {
  static const route = '/pro';
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  String _plan = 'yearly'; // monthly | yearly | lifetime
  bool _busy = false;

  Future<void> _startTrial() async {
    setState(() => _busy = true);
    final app = context.read<AppState>();
    await app.startProTrial();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Pro trial started — 14 days free.')),
    );
  }

  Future<void> _buy(AppState app) async {
    setState(() => _busy = true);
    await app.purchasePro(_plan);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_plan == 'lifetime'
              ? 'Welcome to Lifeez Pro — yours forever.'
              : 'Welcome to Lifeez Pro.')),
    );
  }

  Future<void> _cancel(AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Pro?', style: V2.title(18)),
        content: Text(
            'You will keep Pro until the end of the current period.',
            style: V2.body()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  Text('Keep Pro', style: V2.sub().copyWith(fontSize: 14))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      color: V2.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 14))),
        ],
      ),
    );
    if (ok == true) await app.cancelPro();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isPro = app.profile?.isPro ?? false;

    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: v2PagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Close affordance (mockup: outlined circle X, top-left).
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFD1D5DB), width: 1.5),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: V2.muted, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Green hero.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 40),
                decoration: V2.heroDeco,
                child: Column(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 34),
                    const SizedBox(height: 12),
                    Text('Lifeez Pro',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1)),
                    const SizedBox(height: 8),
                    Text('Your life, on autopilot',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              if (!isPro) ...[
                // Feature checklist.
                _check('Unlimited AI commands'),
                _check('AI Insights in Daily Briefing'),
                _check('AI Trip Planner'),
                _check('Voice replies from AI'),
                _check('Smart reminders that learn'),
                _check('Cloud sync everywhere'),
                _check('Priority support'),
                const SizedBox(height: 24),

                // Plan cards.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _planCard(
                            'monthly',
                            'Monthly',
                            '\$4.99',
                            'per month',
                            badge: null)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: _planCard('yearly', 'Yearly',
                            '\$39', 'per year',
                            badge: 'Best value')),
                  ],
                ),
                const SizedBox(height: 14),
                _planCard('lifetime', 'Lifetime', '\$99',
                    'one-time payment',
                    badge: 'Launch offer', fullWidth: true),
                const SizedBox(height: 24),

                V2PrimaryButton(
                  label: _busy
                      ? 'Please wait…'
                      : _plan == 'monthly'
                          ? 'Continue — \$4.99/month'
                          : _plan == 'yearly'
                              ? 'Continue — \$39/year'
                              : 'Continue — \$99 once',
                  onTap: _busy ? null : () => _buy(app),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _startTrial,
                    child: Text('Or start 14-day free trial',
                        style: GoogleFonts.poppins(
                            color: V2.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                ),
                Center(
                    child:
                        Text('Cancel anytime', style: V2.sub(14))),
              ] else
                _proActive(app),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  Widget _check(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: V2.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w500,
                    color: V2.ink)),
          ),
        ],
      ),
    );
  }

  Widget _planCard(
      String id, String name, String price, String per,
      {String? badge, bool fullWidth = false}) {
    final selected = _plan == id;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? V2.green : const Color(0xFFE5E7EB),
          width: selected ? 3 : 1.5,
        ),
        boxShadow: V2.softShadow,
      ),
      child: fullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: V2.ink)),
                const SizedBox(width: 12),
                Text(price,
                    style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: V2.ink,
                        height: 1.1)),
                const SizedBox(width: 12),
                Text(per, style: V2.sub(14)),
              ],
            )
          : Column(
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: V2.ink)),
                const SizedBox(height: 8),
                Text(price,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: V2.ink,
                        height: 1.1)),
                const SizedBox(height: 4),
                Text(per, style: V2.sub(14)),
              ],
            ),
    );
    return GestureDetector(
      onTap: () => setState(() => _plan = id),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (badge != null)
            Positioned(
              top: -13,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: V2.green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(badge,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Already-Pro state (V2-styled, keeps existing trial/renew/cancel logic).
  Widget _proActive(AppState app) {
    final p = app.profile;
    final trialLeft = app.trialDaysLeft;
    final renews = p?.proRenewsAt;
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const V2IconTile(Icons.workspace_premium_rounded,
                  size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Text('You are Pro',
                    style: V2.title(20)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (trialLeft != null && trialLeft > 0)
            Text(
                '$trialLeft day${trialLeft == 1 ? '' : 's'} left in your free trial.',
                style: V2.body()),
          if (renews != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                p?.proPlan == 'lifetime'
                    ? 'Lifetime access — no renewals, ever.'
                    : 'Renews ${DateFormat('MM/dd/yyyy').format(renews)} • ${p?.proPlan == 'yearly' ? '\$39/year' : '\$4.99/month'}',
                style: V2.sub(),
              ),
            ),
          const SizedBox(height: 8),
          _check('Unlimited AI commands'),
          _check('AI Insights in Daily Briefing'),
          _check('AI Trip Planner'),
          _check('Voice replies from AI'),
          _check('Smart reminders that learn'),
          _check('Cloud sync everywhere'),
          _check('Priority support'),
          if (p?.proPlan != null && p?.proPlan != 'none')
            Center(
              child: TextButton(
                onPressed: () => _cancel(app),
                child: Text('Cancel subscription',
                    style: GoogleFonts.poppins(
                        color: V2.danger, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}
