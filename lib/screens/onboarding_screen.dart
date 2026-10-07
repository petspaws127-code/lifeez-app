import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../models/profile.dart';
import 'main_tabs.dart';

/// First-run setup: name, monthly income, monthly budget.
class OnboardingScreen extends StatefulWidget {
  static const route = '/onboarding';
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _income = TextEditingController();
  final _budget = TextEditingController();
  final _savings = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _income.dispose();
    _budget.dispose();
    _savings.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthService>();
    final profile = Profile(
      id: auth.userId ?? const Uuid().v4(),
      name: _name.text.trim(),
      currency: 'USD',
      monthlyIncome: double.tryParse(_income.text.trim()) ?? 0,
      monthlyBudget: double.tryParse(_budget.text.trim()) ?? 0,
      savingsGoal: double.tryParse(_savings.text.trim()) ?? 0,
    );
    await context.read<AppState>().saveProfile(profile);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, MainTabs.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Center(child: AppLogo(size: 72)),
                const SizedBox(height: 20),
                Text(
                  'Let’s set you up',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Everything starts at \$0 — make it yours.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _name,
                  label: 'Your name',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),
                AppTextField(
                  controller: _income,
                  label: 'Monthly income (USD)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? 'Enter a number, e.g. 3000'
                      : null,
                ),
                AppTextField(
                  controller: _budget,
                  label: 'Monthly budget (USD)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? 'Enter a number, e.g. 2500'
                      : null,
                ),
                AppTextField(
                  controller: _savings,
                  label: 'How much do you want to save this month? (USD)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? 'Enter a number, e.g. 500'
                      : null,
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: _busy ? 'Saving…' : 'Start using Lifeez',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _busy ? null : _finish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
