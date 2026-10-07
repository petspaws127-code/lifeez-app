import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';

/// Referral program: share a code, earn 30 Pro days per 3 real referrals.
class ReferralsScreen extends StatefulWidget {
  static const route = '/referrals';
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  @override
  void initState() {
    super.initState();
    // Make sure a code exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().ensureReferralCode();
    });
  }

  Future<void> _share(String code) async {
    final text = Uri.encodeComponent(
        'Join me on Lifeez — Life, made easy! Use my referral code $code when you sign up.');
    final wa = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(wa)) {
      await launchUrl(wa, mode: LaunchMode.externalApplication);
      return;
    }
    final sms = Uri.parse('sms:?body=$text');
    if (await canLaunchUrl(sms)) {
      await launchUrl(sms);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open a sharing app.')),
      );
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final code = p?.referralCode ?? '';
    final count = p?.referralCount ?? 0;
    final earned = p?.proDaysEarned ?? 0;
    final toNext = 3 - (count % 3 == 0 && count > 0 ? 3 : count % 3);
    final progress = (count % 3) / 3;

    return Scaffold(
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: AppTheme.goldGradient(radius: 24),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CategoryIcon(category: 'pro', size: 54),
                const SizedBox(height: 10),
                Text('Give Pro, get Pro',
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5c4a12))),
                const SizedBox(height: 6),
                Text(
                  'Share your code. For every 3 friends who join, you earn 30 free Pro days.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: const Color(0xFF7a6420),
                      height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your referral code',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          code.isEmpty ? '…' : code,
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: AppColors.deepGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed:
                          code.isEmpty ? null : () => _copy(code),
                      icon: const Icon(Icons.copy_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.deepGreen,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Copy code',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Invite friends',
                    icon: Icons.share_rounded,
                    onPressed:
                        code.isEmpty ? null : () => _share(code),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Your progress',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    Text('$count referral${count == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: AppColors.greenSoft,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                            AppColors.gold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  count % 3 == 0
                      ? (count == 0
                          ? 'Invite 3 friends to earn 30 Pro days.'
                          : 'Reward unlocked! Invite 3 more for another 30 Pro days.')
                      : '$toNext more friend${toNext == 1 ? '' : 's'} to earn 30 Pro days.',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          color: AppColors.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$earned Pro days earned so far',
                          style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color:
                                  const Color(0xFF7a6420)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.card3D(radius: 18),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How it works',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _step('1', 'Share your code with friends.'),
                _step('2', 'They join Lifeez with your code.'),
                _step('3',
                    'Every 3 joins = 30 free Pro days for you.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String n, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.deepGreen,
                shape: BoxShape.circle,
              ),
              child: Text(n,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t,
                  style: GoogleFonts.poppins(fontSize: 13.5)),
            ),
          ],
        ),
      );
}
