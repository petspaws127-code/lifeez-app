import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import 'login_screen.dart';
import 'pin_lock_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasFingerprint = false;
  bool _hasFace = false;
  bool _fingerprintEnabled = false;
  bool _faceEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final bio = BiometricService.instance;
    final results = await Future.wait([
      bio.hasFingerprint,
      bio.hasFace,
      bio.isFingerprintEnabled(),
      bio.isFaceEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      _hasFingerprint = results[0];
      _hasFace = results[1];
      _fingerprintEnabled = results[2];
      _faceEnabled = results[3];
    });
  }

  /// Toggling ON requires a successful biometric check first;
  /// the preference is saved only when authentication succeeds.
  Future<void> _toggleBiometric(
      {required bool fingerprint, required bool enable}) async {
    final bio = BiometricService.instance;
    if (enable) {
      final ok = await bio.authenticate(fingerprint
          ? 'Confirm to enable fingerprint unlock'
          : 'Confirm to enable face unlock');
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Authentication failed. Biometric unlock was not enabled.')),
        );
        return;
      }
    }
    if (fingerprint) {
      await bio.setFingerprintEnabled(enable);
    } else {
      await bio.setFaceEnabled(enable);
    }
    if (!mounted) return;
    setState(() {
      if (fingerprint) {
        _fingerprintEnabled = enable;
      } else {
        _faceEnabled = enable;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(enable
              ? 'Biometric unlock enabled.'
              : 'Biometric unlock disabled.')),
    );
  }

  Widget _biometricRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool available,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: available ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppTheme.card3D(radius: 18),
        child: ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.deepGreen),
          ),
          title: Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, color: AppColors.muted)),
          trailing: Switch(
            value: value,
            onChanged: available ? onChanged : null,
            activeThumbColor: AppColors.deepGreen,
          ),
          onTap: available ? () => onChanged(!value) : null,
        ),
      ),
    );
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
    final appState = context.read<AppState>();
    await auth.signOut();
    // Data kept on logout - user data persists;
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, LoginScreen.route, (_) => false);
  }

  Future<void> _deleteData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete my data?'),
        content: const Text(
            'This permanently removes all your tasks, expenses, bills and everything else. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().deleteAllMyData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All your data was deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Account
          GestureDetector(
            onTap: () => Navigator.pushNamed(
                context, ProfileScreen.route),
            child: Container(
              decoration: AppTheme.card3D(),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                Container(
                  decoration: AppTheme.tile3D(
                    const [
                      AppColors.deepGreen,
                      AppColors.greenMid
                    ],
                    radius: 16,
                  ),
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  child: Text(
                    (p?.name.isNotEmpty ?? false)
                        ? p!.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(p?.name ?? '—',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(
                          'Plan: ${(p?.plan ?? 'free').toUpperCase()} • ${(p?.currency ?? 'USD')}',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _row(
            icon: 'money',
            title: 'Monthly budget',
            subtitle:
                '\$${(p?.monthlyBudget ?? 0).toStringAsFixed(2)}',
            onTap: () => _editBudget(context),
          ),
          _row(
            icon: 'pro',
            title: 'Lifeez Pro',
            subtitle: (p?.isPro ?? false)
                ? 'Active${p?.trialEndsAt != null && (app.trialDaysLeft ?? 0) > 0 ? ' • trial' : ''}'
                : 'Free plan • 14-day trial available',
            onTap: () =>
                Navigator.pushNamed(context, '/pro'),
          ),
          _row(
            icon: 'pin',
            title: 'App PIN lock',
            subtitle: app.hasPin
                ? 'Enabled'
                : 'Protect the app with a 4-digit PIN',
            onTap: () => _pinOptions(context, app),
          ),
          // Biometric unlock options — only shown once a PIN exists,
          // since biometrics are an alternative to entering the PIN.
          if (app.hasPin) ...[
            _biometricRow(
              icon: Icons.fingerprint_rounded,
              title: 'Fingerprint unlock',
              subtitle: _hasFingerprint
                  ? 'Unlock the app with your fingerprint'
                  : 'Not available on this device',
              value: _fingerprintEnabled,
              available: _hasFingerprint,
              onChanged: (v) =>
                  _toggleBiometric(fingerprint: true, enable: v),
            ),
            _biometricRow(
              icon: Icons.face_rounded,
              title: 'Face unlock',
              subtitle: _hasFace
                  ? 'Unlock the app with your face'
                  : 'Not available on this device',
              value: _faceEnabled,
              available: _hasFace,
              onChanged: (v) =>
                  _toggleBiometric(fingerprint: false, enable: v),
            ),
          ],
          _row(
            icon: 'task',
            title: 'Privacy Policy',
            subtitle: 'How your data is handled',
            onTap: () =>
                Navigator.pushNamed(context, '/privacy'),
          ),
          _row(
            icon: 'document',
            title: 'Terms of Service',
            subtitle: 'The fine print',
            onTap: () =>
                Navigator.pushNamed(context, '/terms'),
          ),
          _row(
            icon: 'other',
            title: 'Help & FAQ',
            subtitle: 'Answers to common questions',
            onTap: () =>
                Navigator.pushNamed(context, '/help'),
          ),
          _row(
            icon: 'other',
            title: 'Delete my data',
            subtitle: 'Remove everything permanently',
            danger: true,
            onTap: _deleteData,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              colors: const [Color(0xFF1A9C63), Color(0xFF1A9C63)],
              onPressed: _signOut,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Lifeez v1.0.0',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required String icon,
    required String title,
    required String subtitle,
    Widget? trailing,
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
                color:
                    danger ? AppColors.danger : null)),
        subtitle: Text(subtitle,
            style: GoogleFonts.poppins(
                fontSize: 12.5, color: AppColors.muted)),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted)
                : null),
        onTap: onTap,
      ),
    );
  }

  void _pinOptions(BuildContext context, AppState app) {
    if (!app.hasPin) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (_) => const PinSetupSheet(),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App PIN lock'),
        content: const Text(
            'PIN lock is enabled. Change it or turn it off.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await app.removePin();
              // Biometrics are only an alternative to the PIN.
              await BiometricService.instance.clearAll();
              if (mounted) {
                setState(() {
                  _fingerprintEnabled = false;
                  _faceEnabled = false;
                });
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('PIN lock removed.')),
                );
              }
            },
            child: const Text('Turn off',
                style: TextStyle(color: AppColors.danger)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26)),
                ),
                builder: (_) => const PinSetupSheet(),
              );
            },
            child: const Text('Change PIN'),
          ),
        ],
      ),
    );
  }

  void _editBudget(BuildContext context) {
    final app = context.read<AppState>();
    final ctrl = TextEditingController(
        text: (app.profile?.monthlyBudget ?? 0)
            .toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly budget'),
        content: AppTextField(
            controller: ctrl,
            label: 'Budget (USD)',
            keyboardType:
                const TextInputType.numberWithOptions(
                    decimal: true)),
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
