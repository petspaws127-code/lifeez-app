import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Help & FAQ — searchable expandable questions.
class HelpFaqScreen extends StatefulWidget {
  static const route = '/help';
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  final _search = TextEditingController();

  static const _faqs = [
    (
      'How do I add a task with my voice?',
      'Tap the microphone in the input bar on Home, Tasks, or the AI chat, and just speak. '
          'When you pause, Lifeez transcribes and saves it automatically.'
    ),
    (
      'What are Quick Commands?',
      'Quick Commands is the WhatsApp-style chat on the Home tab. Type or say things like '
          '"I spent \$45 at Walmart" or "Remind me to call mom at 6pm" and Lifeez files them in the right place.'
    ),
    (
      'How does the 14-day Pro trial work?',
      'Open Lifeez Pro from your Profile and start the trial — no charge for 14 days. '
          'You can cancel anytime before it ends.'
    ),
    (
      'How do I lock the app with a PIN?',
      'Go to Settings → App PIN lock and choose a 4-digit PIN. You will be asked for it each time the app opens.'
    ),
    (
      'How do referrals earn Pro days?',
      'Share your referral code from Profile → Refer & earn. For every 3 friends who join with your code, '
          'you get 30 free Pro days.'
    ),
    (
      'Can I attach receipts to expenses?',
      'Yes. When adding an expense in Money, tap the receipt icon to snap a photo or pick one from your gallery. '
          'Tap any expense to view its receipt.'
    ),
    (
      'How do I switch between light and dark mode?',
      'Open Profile → Appearance and choose System, Light, or Dark.'
    ),
    (
      'What is the Document Scanner?',
      'Open it from the More tab. Snap a photo of any document — Lifeez saves it to your Documents with a title you choose.'
    ),
    (
      'How do I delete my account and data?',
      'Profile → Delete account removes your account and everything in it permanently. This cannot be undone.'
    ),
    (
      'Is my data private?',
      'Yes. Your data is yours, never sold, and you can delete it anytime. See the Privacy Policy in your Profile.'
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final items = _faqs
        .where((f) =>
            q.isEmpty ||
            f.$1.toLowerCase().contains(q) ||
            f.$2.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AppTextField(
            controller: _search,
            label: 'Search help…',
            prefixIcon: Icons.search_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              decoration: AppTheme.card3D(),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No answers found. Try different words.',
                    style: GoogleFonts.poppins(
                        color: AppColors.muted)),
              ),
            ),
          for (final f in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: AppTheme.card3D(radius: 18),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(f.$1,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(f.$2,
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            height: 1.55,
                            color: AppColors.muted)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/support'),
              child: const Text('Still stuck? Contact Support'),
            ),
          ),
        ],
      ),
    );
  }
}
