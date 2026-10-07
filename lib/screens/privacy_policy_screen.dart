import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Privacy Policy — in-app page (no external dependency).
class PrivacyPolicyScreen extends StatelessWidget {
  static const route = '/privacy';
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy Policy',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Last updated: October 2026',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 16),
                _p('Lifeez ("we", "our") helps you manage your daily life. '
                    'This policy explains what data we collect and how we use it.'),
                _h('1. Data we collect'),
                _p('• Account info you provide: name and email.\n'
                    '• Content you create: tasks, expenses, reminders, bills, notes, '
                    'photos, and other items you add to the app.\n'
                    '• Device info: app version and basic diagnostics to keep the app stable.'),
                _h('2. How we use your data'),
                _p('Your data is used only to provide the app\'s features: '
                    'showing your lists, generating reminders and briefings, and syncing '
                    'across your devices. We never sell your personal data.'),
                _h('3. Storage'),
                _p('Your data is stored securely and synced to your private account. '
                    'Deleting your account permanently removes your data from our servers.'),
                _h('4. Photos & camera'),
                _p('Photos you add (profile, pets, memories, receipts, scans) stay in '
                    'your account and are only used to display them back to you.'),
                _h('5. Your choices'),
                _p('You can export or delete your data at any time from Settings. '
                    'Contact support@lifeez.app with privacy questions.'),
                _h('6. Changes'),
                _p('If this policy changes, we will update the date above and '
                    'notify you in the app for material changes.'),
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
