import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/whatsapp_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final appState = context.read<AppState>();
    await auth.signOut();
    appState.clearLocal();
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
    final wa = context.watch<WhatsAppService>();
    final p = app.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Account
          Container(
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
          const SizedBox(height: 12),

          _row(
            icon: 'grocery',
            title: 'WhatsApp',
            subtitle: wa.isConnected
                ? 'Connected • ${wa.phoneNumber ?? ''}'
                : 'Not connected',
            trailing: wa.isConnected
                ? TextButton(
                    onPressed: () => wa.disconnect(),
                    child: const Text('Disconnect'))
                : null,
          ),
          _row(
            icon: 'money',
            title: 'Monthly budget',
            subtitle:
                '\$${(p?.monthlyBudget ?? 0).toStringAsFixed(2)}',
            onTap: () => _editBudget(context),
          ),
          _row(
            icon: 'task',
            title: 'Privacy Policy',
            subtitle: 'How your data is handled',
            onTap: () => _open(
                'https://ailifeassistant.app/privacy'),
          ),
          _row(
            icon: 'document',
            title: 'Terms of Service',
            subtitle: 'The fine print',
            onTap: () =>
                _open('https://ailifeassistant.app/terms'),
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
              colors: const [Color(0xFF6B7280), Color(0xFF4B5563)],
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
