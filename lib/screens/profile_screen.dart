import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/update_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Profile section: user info, photo, edit profile, Pro status,
/// appearance + notification preferences, referrals, legal & support.
class ProfileScreen extends StatefulWidget {
  static const route = '/profile';
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();

  Future<void> _changePhoto() async {
    final app = context.read<AppState>();
    final hasPhoto = (app.profile?.photoPath ?? '').isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.deepGreen),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.deepGreen),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                title: const Text('Remove photo',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      await app.saveProfile(app.profile!.copyWith(clearPhoto: true));
      return;
    }
    final img = await _picker.pickImage(
        source: choice == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 80);
    if (img == null || !mounted) return;
    await app.saveProfile(app.profile!.copyWith(photoPath: img.path));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    }
  }

  void _editProfile() {
    final app = context.read<AppState>();
    final p = app.profile;
    if (p == null) return;
    final nameCtrl = TextEditingController(text: p.name);
    final emailCtrl = TextEditingController(text: p.email);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: nameCtrl, label: 'Name'),
            const SizedBox(height: 10),
            AppTextField(
              controller: emailCtrl,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await app.saveProfile(p.copyWith(
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile saved.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareApp() async {
    final app = context.read<AppState>();
    await app.ensureReferralCode();
    final code = app.profile?.referralCode ?? '';
    final text = Uri.encodeComponent(
        'Try Lifeez — Life, made easy. Use my referral code $code when you join!');
    // WhatsApp-first sharing (no extra dependency needed).
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
            content:
                Text('Could not open a sharing app.')),
      );
    }
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.lifeez.app');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open the store page.')),
      );
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content:
            const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final auth = context.read<AuthService>();
    final app = context.read<AppState>();
    await auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, LoginScreen.route, (_) => false);
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This permanently deletes your account and all your data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final auth = context.read<AuthService>();
    final app = context.read<AppState>();
    await app.deleteAllMyData();
    await auth.deleteAccount();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, LoginScreen.route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Header card: photo, name, email, edit.
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _changePhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.greenSoft,
                        backgroundImage:
                            (p?.photoPath ?? '').isNotEmpty
                                ? FileImage(File(p!.photoPath!))
                                : null,
                        child: (p?.photoPath ?? '').isEmpty
                            ? Text(
                                (p?.name.isNotEmpty ?? false)
                                    ? p!.name[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                    color: AppColors.deepGreen,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.deepGreen,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(5),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p?.name ?? '—',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      if ((p?.email ?? '').isNotEmpty)
                        Text(p!.email,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(
                        (p?.isPro ?? false)
                            ? 'Lifeez Pro'
                            : 'Free plan',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: (p?.isPro ?? false)
                              ? AppColors.gold
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                    onPressed: _editProfile,
                    child: const Text('Edit')),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pro status.
          _ProStatusCard(onTap: () {
            if (!(p?.isPro ?? false)) {
              Navigator.pushNamed(context, '/pro');
            }
          }),
          const SizedBox(height: 12),

          const SectionHeader(title: 'Preferences'),
          const SizedBox(height: 8),
          _themeRow(app),
          _switchRow(
            icon: 'notification',
            title: 'Notifications',
            subtitle: 'Activity alerts and reminders',
            value: p?.notificationsEnabled ?? true,
            onChanged: (v) =>
                app.saveProfile(p!.copyWith(notificationsEnabled: v)),
          ),
          _switchRow(
            icon: 'myday',
            title: 'Daily briefing',
            subtitle: 'My Day summary each morning',
            value: p?.dailyBriefingEnabled ?? true,
            onChanged: (v) =>
                app.saveProfile(p!.copyWith(dailyBriefingEnabled: v)),
          ),
          _row(
            icon: 'money',
            title: 'Monthly budget',
            subtitle:
                '\$${(p?.monthlyBudget ?? 0).toStringAsFixed(2)}',
            onTap: () => _editBudget(context, app),
          ),
          const SizedBox(height: 4),
          const SectionHeader(title: 'Rewards'),
          const SizedBox(height: 8),
          _row(
            icon: 'pro',
            title: 'Refer & earn Pro days',
            subtitle:
                '${p?.referralCount ?? 0} referrals • ${p?.proDaysEarned ?? 0} Pro days earned',
            onTap: () =>
                Navigator.pushNamed(context, '/referrals'),
          ),
          const SizedBox(height: 4),
          const SectionHeader(title: 'Support'),
          const SizedBox(height: 8),
          _row(
            icon: 'other',
            title: 'Help & FAQ',
            subtitle: 'Answers to common questions',
            onTap: () => Navigator.pushNamed(context, '/help'),
          ),
          _row(
            icon: 'family',
            title: 'Contact Support',
            subtitle: 'Get help from our team',
            onTap: () =>
                Navigator.pushNamed(context, '/support'),
          ),
          const SizedBox(height: 4),
          const SectionHeader(title: 'Legal'),
          const SizedBox(height: 8),
          _row(
            icon: 'document',
            title: 'Privacy Policy',
            subtitle: 'How your data is handled',
            onTap: () =>
                Navigator.pushNamed(context, '/privacy'),
          ),
          _row(
            icon: 'task',
            title: 'Terms of Service',
            subtitle: 'The fine print',
            onTap: () => Navigator.pushNamed(context, '/terms'),
          ),
          const SizedBox(height: 4),
          const SectionHeader(title: 'App'),
          const SizedBox(height: 8),
          _row(
            icon: 'pro',
            title: 'Rate Lifeez',
            subtitle: 'Love the app? Leave a rating',
            onTap: _rateApp,
          ),
          _row(
            icon: 'share',
            title: 'Share Lifeez',
            subtitle: 'Tell a friend about the app',
            onTap: _shareApp,
          ),
          _row(
            icon: 'other',
            title: 'Delete account',
            subtitle: 'Remove your account and all data',
            danger: true,
            onTap: _deleteAccount,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              colors: const [
                Color(0xFF6B7280),
                Color(0xFF4B5563)
              ],
              onPressed: _signOut,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '...';
                return Text('Lifeez v$version',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.muted));
              },
            ),
            ),
        ],
      ),
    );
  }

  Widget _themeRow(AppState app) {
    final mode = app.profile?.themeMode ?? 'system';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.card3D(radius: 18),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CategoryIcon(category: 'other', size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    Text('Light, dark, or follow system',
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'system',
                  label: Text('System'),
                  icon: Icon(Icons.settings_suggest_rounded,
                      size: 18)),
              ButtonSegment(
                  value: 'light',
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded, size: 18)),
              ButtonSegment(
                  value: 'dark',
                  label: Text('Dark'),
                  icon:
                      Icon(Icons.dark_mode_rounded, size: 18)),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                app.setThemeMode(s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.deepGreen,
              selectedForegroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required String icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.card3D(radius: 18),
      child: ListTile(
        leading: CategoryIcon(category: icon, size: 42),
        title: Text(title,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: GoogleFonts.poppins(
                fontSize: 12.5, color: AppColors.muted)),
        trailing: Switch.adaptive(
          value: value,
          activeThumbColor: AppColors.deepGreen,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _row({
    required String icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.card3D(radius: 18),
      child: ListTile(
        leading: CategoryIcon(category: icon, size: 42),
        title: Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: danger ? AppColors.danger : null)),
        subtitle: Text(subtitle,
            style: GoogleFonts.poppins(
                fontSize: 12.5, color: AppColors.muted)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.muted),
        onTap: onTap,
      ),
    );
  }

  void _editBudget(BuildContext context, AppState app) {
    final ctrl = TextEditingController(
        text: (app.profile?.monthlyBudget ?? 0).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly budget'),
        content: AppTextField(
            controller: ctrl,
            label: 'Budget (USD)',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && app.profile != null) {
                await app.saveProfile(
                    app.profile!.copyWith(monthlyBudget: v));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ProStatusCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ProStatusCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final isPro = p?.isPro ?? false;
    final trialDays = app.trialDaysLeft ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: isPro
            ? AppTheme.goldGradient(radius: 20)
            : AppTheme.card3D(radius: 20),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: AppTheme.tile3D(
                isPro
                    ? const [Color(0xFF8a6d1c), AppColors.gold]
                    : const [
                        AppColors.deepGreen,
                        AppColors.greenMid
                      ],
                radius: 14,
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPro ? 'Lifeez Pro active' : 'Go Pro',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isPro ? const Color(0xFF5c4a12) : null,
                    ),
                  ),
                  Text(
                    isPro
                        ? (trialDays > 0
                            ? 'Trial • $trialDays days left'
                            : 'Plan: ${p?.proPlan ?? 'pro'}')
                        : 'Unlock everything • 14-day free trial',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: isPro
                          ? const Color(0xFF7a6420)
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
