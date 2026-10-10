import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import '../services/whatsapp_service.dart';
import 'main_tabs.dart';
import 'otp_verify_screen.dart';
import '../widgets/google_logo.dart';
import '../widgets/apple_logo.dart';

/// Option A passwordless login: email -> 6-digit code. No password.
/// Social buttons (Google/Apple) below. Admin bypass kept at bottom.
class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _socialLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _afterSignIn() async {
    final app = context.read<AppState>();
    final whatsapp = context.read<WhatsAppService>();
    await app.loadAll();
    await whatsapp.restore();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      MainTabs.route, // Onboarding hidden for now - direct to dashboard
    );
  }

  void _showError(String rawMsg) {
    if (!mounted) return;
    final msg = _friendlyError(rawMsg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF1A9C63),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid') && lower.contains('email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('socket')) {
      return 'Connection issue. Please check your internet and try again.';
    }
    if (lower.contains('too many') || lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('cancelled') || lower.contains('canceled')) {
      return 'Sign-in was cancelled.';
    }
    if (lower.contains('not configured') || lower.contains('setup')) {
      return 'This sign-in method is being set up. Try email code for now.';
    }
    var clean =
        raw.replaceAll(RegExp(r'exception:?\s*', caseSensitive: false), '').trim();
    if (clean.length > 120) clean = '${clean.substring(0, 117)}...';
    return clean.isEmpty ? 'Something went wrong. Please try again.' : clean;
  }

  bool _validEmail(String e) =>
      e.isNotEmpty && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);

  Future<void> _handleContinue() async {
    final email = _emailCtrl.text.trim();
    if (!_validEmail(email)) {
      _showError('Enter a valid email address');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().sendEmailOtp(email);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(email: email),
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _socialLoading = true);
    try {
      await context.read<AuthService>().signInWithGoogle();
      if (mounted) await _afterSignIn();
    } catch (e) {
      // AuthService throws friendly messages for known config problems.
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _socialLoading = false);
    }
  }

  Future<void> _handleApple() async {
    setState(() => _socialLoading = true);
    try {
      await context.read<AuthService>().signInWithApple();
      if (mounted) await _afterSignIn();
    } catch (e) {
      _showError('Apple sign-in is being set up. Try email code for now.');
    } finally {
      if (mounted) setState(() => _socialLoading = false);
    }
  }

  Future<void> _handleAdmin() async {
    try {
      await context.read<AuthService>().signInAsAdmin();
      if (mounted) await _afterSignIn();
    } catch (e) {
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Center(child: AppLogo(size: 88)),
              const SizedBox(height: 12),
              Text(
                'Lifeez',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your email to continue',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1A9C63),
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (_) => _handleContinue(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A9C63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: GoogleFonts.poppins(color: AppColors.muted),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google
                  GestureDetector(
                    onTap: _socialLoading ? null : _handleGoogle,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(child: GoogleLogo(size: 28)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Apple
                  GestureDetector(
                    onTap: _socialLoading ? null : _handleApple,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                          child: AppleLogo(size: 28)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "We'll email you a login code.\nNo password needed.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 40),
              // Temporary admin bypass - keep until real auth is verified
              Center(
                child: TextButton(
                  onPressed: _handleAdmin,
                  child: Text(
                    'Admin — Enter Directly',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
