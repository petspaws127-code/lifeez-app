import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Terms of Service — in-app page.
class TermsScreen extends StatelessWidget {
  static const route = '/terms';
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terms of Service',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Last updated: October 2026',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 16),
                _p('By using Lifeez you agree to these terms.'),
                _h('1. The service'),
                _p('Lifeez is a personal life-management app: tasks, money tracking, '
                    'reminders, habits, pets, documents, and related tools. '
                    'Features may change over time as we improve the app.'),
                _h('2. Your account'),
                _p('You are responsible for keeping your sign-in and app PIN private. '
                    'You must provide accurate account information.'),
                _h('3. Subscriptions'),
                _p('Lifeez Pro is billed monthly (\$4.99) or yearly (\$39) after any '
                    'free trial ends. Trials last 14 days. You can cancel anytime; '
                    'access continues until the end of the current billing period. '
                    'Refunds follow the app store\'s policy.'),
                _h('4. Acceptable use'),
                _p('Do not misuse the service, attempt to disrupt it, or use it for '
                    'anything unlawful. We may suspend accounts that violate these terms.'),
                _h('5. Data'),
                _p('You own your data. Deleting your account permanently removes it. '
                    'See the Privacy Policy for details.'),
                _h('6. Disclaimer'),
                _p('Lifeez provides organizational tools, not professional financial, '
                    'medical, or legal advice. Insights and forecasts are estimates.'),
                _h('7. Liability'),
                _p('To the maximum extent allowed by law, Lifeez is provided "as is" '
                    'without warranties, and our liability is limited to the amount you '
                    'paid for the service in the last 12 months.'),
                _h('8. Contact'),
                _p('Questions about these terms: support@lifeez.app.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t,
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700)),
      );

  Widget _p(String t) => Text(t,
      style: GoogleFonts.poppins(
          fontSize: 13.5, height: 1.55, color: AppColors.ink));
}
