import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import '../services/whatsapp_service.dart';
import '../services/supabase_client.dart';
import 'onboarding_screen.dart';
import 'main_tabs.dart';

/// Clean login screen: Google + Email only.
class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSignup = false;
  bool _obscurePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
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
      app.profile == null ? OnboardingScreen.route : MainTabs.route,
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
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF2D5A3D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Maps technical auth errors to friendly user messages.
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid_credentials')) {
      return _isSignup
          ? 'Something went wrong. Please try again.'
          : 'Incorrect email or password. Please try again.';
    }
    if (lower.contains('user already registered') || lower.contains('already registered') || lower.contains('email already')) {
      return 'This email is already registered. Try logging in instead!';
    }
    if (lower.contains('password') && (lower.contains('weak') || lower.contains('short') || lower.contains('6 characters'))) {
      return 'Password must be at least 6 characters long.';
    }
    if (lower.contains('email') && lower.contains('invalid')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('network') || lower.contains('connection') || lower.contains('timeout') || lower.contains('socket')) {
      return 'Connection issue. Please check your internet and try again.';
    }
    if (lower.contains('too many') || lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('cancelled') || lower.contains('canceled')) {
      return 'Sign-in was cancelled.';
    }
    if (lower.contains('not configured') || lower.contains('setup')) {
      return 'Google sign-in is being set up. Please use email for now.';
    }
    // Fallback: clean up the raw message
    var clean = raw.replaceAll(RegExp(r'exception:?\s*', caseSensitive: false), '').trim();
    if (clean.length > 120) clean = '${clean.substring(0, 117)}...';
    return clean.isEmpty ? 'Something went wrong. Please try again.' : clean;
  }

  Future<void> _handleGoogle() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().signInWithGoogle();
      if (mounted) await _afterSignIn();
    } catch (e) {
      _showError('Google sign-in needs setup. Please use Email for now.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter a valid email address');
      return;
    }
    if (pass.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      if (_isSignup) {
        await auth.signUpWithEmail(email, pass);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Check email to confirm, then log in.'),
            ),
          );
          setState(() => _isSignup = false);
        }
      } else {
        await auth.signInWithEmail(email, pass);
        if (mounted) await _afterSignIn();
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgot() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter your email first');
      return;
    }
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
      }
    } catch (e) {
      _showError('Could not send reset email');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(child: AppLogo(size: 88)),
              const SizedBox(height: 20),
              Text(
                _isSignup ? 'Create account' : 'Welcome back!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignup
                    ? 'Sign up to get started with Lifeez'
                    : 'Log in to continue to Lifeez',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 32),
              // Google button
              ElevatedButton.icon(
                onPressed: _loading ? null : _handleGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: Text(
                  'Continue with Google',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
              // Email field
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Password field
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: (_) => _handleEmail(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _handleForgot,
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Login/Signup button
              ElevatedButton(
                onPressed: _loading ? null : _handleEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepGreen,
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
                        _isSignup ? 'Sign Up' : 'Log In',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              // Toggle signup/login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignup
                        ? 'Already have an account? '
                        : "Don't have an account? ",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.muted,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isSignup = !_isSignup),
                    child: Text(
                      _isSignup ? 'Log in' : 'Sign up',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'By continuing you agree to the Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
