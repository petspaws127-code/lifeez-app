import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/ui_kit.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import '../services/whatsapp_service.dart';
import 'onboarding_screen.dart';
import 'main_tabs.dart';

/// Login screen with EXACTLY 4 options: Google, WhatsApp, Apple, Facebook.
/// Each button calls its real SDK (see AuthService); missing credentials
/// surface a clear setup message instead of a fake login.
/// TEMPORARY: an admin direct-entry link below the buttons skips auth so the
/// owner can test the app; remove it when the real SDK/API logins are wired.
class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _busy;

  Future<void> _afterSignIn() async {
    final app = context.read<AppState>();
    final whatsapp = context.read<WhatsAppService>();
    await app.loadAll();
    await whatsapp.restore();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      app.profile == null ? OnboardingScreen.route : MainTabs.route,
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Heads up'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Admin bypass options: Demo (free) or Paid Pro.
  void _showAdminOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin entry'),
        content: const Text('Choose your test account type:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthService>().signInAsAdmin(plan: 'demo');
              if (context.mounted) await _afterSignIn();
            },
            child: const Text('Demo (Free)'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthService>().signInAsAdmin(plan: 'paid');
              if (context.mounted) await _afterSignIn();
            },
            child: const Text('Paid Pro'),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn(
      String key, Future<void> Function(AuthService) action) async {
    setState(() => _busy = key);
    try {
      await action(context.read<AuthService>());
      if (!mounted) return;
      if (context.read<AuthService>().isSignedIn) {
        await _afterSignIn();
      }
    } on AuthSetupException catch (e) {
      _showError(e.message);
    } catch (e) {
      final msg = e.toString();
      // Google ApiException: 10 = DEVELOPER_ERROR (SHA-1 / OAuth not registered)
      if (msg.contains('ApiException: 10')) {
        _showError(
          'Google sign-in needs setup: the app is not registered in Google '
          'Cloud Console yet. Please use "Admin · Enter directly" for now.',
        );
      } else {
        _showError('Sign-in failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _openWhatsAppLogin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const _WhatsAppLoginSheet(),
    ).then((ok) {
      if (ok == true && mounted) _afterSignIn();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(child: AppLogo(size: 96)),
              const SizedBox(height: 20),
              Text(
                'Lifeez',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell it. It remembers it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 15, color: AppColors.muted),
              ),
              const SizedBox(height: 44),
              _providerButton(
                key: 'google',
                label: 'Continue with Google',
                background: Colors.white,
                foreground: AppColors.ink,
                border: true,
                leading: const FaIcon(FontAwesomeIcons.google,
                    color: Color(0xFF4285F4), size: 24),
                onTap: () =>
                    _signIn('google', (a) => a.signInWithGoogle()),
              ),
              const SizedBox(height: 14),
              _providerButton(
                key: 'whatsapp',
                label: 'Continue with WhatsApp',
                background: AppColors.whatsapp,
                foreground: Colors.white,
                leading: const FaIcon(FontAwesomeIcons.whatsapp,
                    color: Colors.white, size: 24),
                onTap: () {
                  setState(() => _busy = 'whatsapp');
                  _openWhatsAppLogin();
                  setState(() => _busy = null);
                },
              ),
              const SizedBox(height: 14),
              _providerButton(
                key: 'apple',
                label: 'Continue with Apple',
                background: Colors.black,
                foreground: Colors.white,
                leading: const FaIcon(FontAwesomeIcons.apple,
                    color: Colors.white, size: 24),
                onTap: () =>
                    _signIn('apple', (a) => a.signInWithApple()),
              ),
              const SizedBox(height: 14),
              _providerButton(
                key: 'facebook',
                label: 'Continue with Facebook',
                background: const Color(0xFF1877F2),
                foreground: Colors.white,
                leading: const FaIcon(FontAwesomeIcons.facebookF,
                    color: Colors.white, size: 24),
                onTap: () =>
                    _signIn('facebook', (a) => a.signInWithFacebook()),
              ),
              const SizedBox(height: 20),
              // TEMPORARY admin bypass — remove when real logins are wired.
              Center(
                child: TextButton.icon(
                  onPressed: () => _showAdminOptions(context),
                  icon: const Icon(Icons.admin_panel_settings_outlined,
                      size: 16, color: AppColors.muted),
                  label: Text(
                    'Admin · Enter directly (temporary)',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'By continuing you agree to the Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _providerButton({
    required String key,
    required String label,
    required Color background,
    required Color foreground,
    required Widget leading,
    required VoidCallback onTap,
    bool border = false,
  }) {
    final busy = _busy == key;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: border
            ? Border.all(color: AppColors.ivoryDeep, width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x140C3B2E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else ...[
                  leading,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// WhatsApp number + code verification bottom sheet.
class _WhatsAppLoginSheet extends StatefulWidget {
  const _WhatsAppLoginSheet();

  @override
  State<_WhatsAppLoginSheet> createState() =>
      _WhatsAppLoginSheetState();
}

class _WhatsAppLoginSheetState
    extends State<_WhatsAppLoginSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _phone.text.trim();
    if (phone.length < 7) {
      setState(() => _error = 'Enter a valid WhatsApp number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().sendWhatsAppCode(phone);
      setState(() {
        _codeSent = true;
        _busy = false;
      });
    } on AuthSetupException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not send code: $e';
      });
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<AuthService>()
          .verifyWhatsAppCode(_phone.text.trim(), _code.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthSetupException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Verification failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                decoration: AppTheme.tile3D(
                  const [AppColors.whatsapp, AppColors.whatsappDark],
                  radius: 12,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with WhatsApp',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_codeSent) ...[
            Text(
              'Enter your WhatsApp number. We will send you a 6-digit code.',
              style: GoogleFonts.poppins(
                  color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            AppTextField(
                controller: _phone,
                label: 'WhatsApp number (e.g. +1 555 123 4567)',
                keyboardType: TextInputType.phone),
          ] else ...[
            Text(
              'Enter the 6-digit code sent to ${_phone.text.trim()}.',
              style: GoogleFonts.poppins(
                  color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            AppTextField(
                controller: _code,
                label: 'Verification code',
                keyboardType: TextInputType.number),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: GoogleFonts.poppins(
                    color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          GradientButton(
            label: _busy
                ? 'Please wait…'
                : (_codeSent ? 'Verify code' : 'Send code'),
            onPressed: _busy ? null : (_codeSent ? _verify : _send),
          ),
        ],
      ),
    );
  }
}
