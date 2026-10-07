import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../services/app_state.dart';
import '../services/biometric_service.dart';

/// PIN lock screen — shown when the app is locked.
/// Enter the 4-digit PIN to unlock. Set/change the PIN in Settings.
class PinLockScreen extends StatefulWidget {
  static const route = '/pin-lock';
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;
  bool _bioBusy = false;
  bool _fingerprintEnabled = false;
  bool _faceEnabled = false;

  @override
  void initState() {
    super.initState();
    // Offer biometric unlock immediately when any type is enabled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoBiometricUnlock();
    });
  }

  Future<void> _autoBiometricUnlock() async {
    final bio = BiometricService.instance;
    final fpOn = await bio.isFingerprintEnabled();
    final faceOn = await bio.isFaceEnabled();
    if (!mounted) return;
    setState(() {
      _fingerprintEnabled = fpOn;
      _faceEnabled = faceOn;
    });
    if (fpOn || faceOn) {
      await _runBiometricAuth(auto: true);
    }
  }

  /// Manual retry from the "Use fingerprint / Use face ID" buttons.
  Future<void> _manualBiometricUnlock() async {
    await _runBiometricAuth(auto: false);
  }

  Future<void> _runBiometricAuth({required bool auto}) async {
    if (_bioBusy || _busy) return;
    setState(() {
      _bioBusy = true;
      _error = null;
    });
    final ok =
        await BiometricService.instance.authenticate('Unlock Lifeez');
    if (!mounted) return;
    setState(() => _bioBusy = false);
    if (ok) {
      _onBiometricSuccess();
    } else if (!auto) {
      setState(() =>
          _error = 'Biometric unlock failed. Enter your PIN.');
    }
  }

  void _onBiometricSuccess() {
    // Biometric auth passed — unlock the app (PIN stays as fallback).
    if (mounted) {
      context.read<AppState>().unlock();
    }
  }

  void _press(String d) {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final ok = context.read<AppState>().verifyPin(_pin);
    setState(() => _busy = false);
    if (!ok && mounted) {
      setState(() {
        _error = 'Wrong PIN. Try again.';
        _pin = '';
      });
    }
    // On success AppState notifies and the gate below rebuilds.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Center(child: AppLogo(size: 84)),
            const SizedBox(height: 16),
            Text('Welcome back',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen)),
            const SizedBox(height: 6),
            Text('Enter your 4-digit PIN',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.muted)),
            const SizedBox(height: 28),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? AppColors.deepGreen
                        : AppColors.greenSoft,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: GoogleFonts.poppins(
                      color: AppColors.danger, fontSize: 13)),
            ],
            const Spacer(),
            // Keypad
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 48),
              child: GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (_, i) {
                  if (i == 9) {
                    return const SizedBox.shrink();
                  }
                  if (i == 10) {
                    return _key('0');
                  }
                  if (i == 11) {
                    return IconButton(
                      icon: const Icon(
                          Icons.backspace_outlined,
                          color: AppColors.muted),
                      onPressed: _backspace,
                    );
                  }
                  return _key('${i + 1}');
                },
              ),
            ),
            const SizedBox(height: 8),
            // Biometric unlock — manual retry buttons (PIN keypad
            // above always stays available as the fallback).
            if (_fingerprintEnabled || _faceEnabled) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  if (_fingerprintEnabled)
                    TextButton.icon(
                      onPressed:
                          _bioBusy ? null : _manualBiometricUnlock,
                      icon: _bioBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.fingerprint_rounded,
                              color: AppColors.deepGreen,
                            ),
                      label: Text('Use fingerprint',
                          style: GoogleFonts.poppins(
                              color: AppColors.deepGreen,
                              fontWeight: FontWeight.w600)),
                    ),
                  if (_faceEnabled)
                    TextButton.icon(
                      onPressed:
                          _bioBusy ? null : _manualBiometricUnlock,
                      icon: _bioBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.face_rounded,
                              color: AppColors.deepGreen,
                            ),
                      label: Text('Use face ID',
                          style: GoogleFonts.poppins(
                              color: AppColors.deepGreen,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _key(String d) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _press(d),
          child: Center(
            child: Text(d,
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

/// PIN setup sheet used from Settings (set or change the PIN).
class PinSetupSheet extends StatefulWidget {
  const PinSetupSheet({super.key});

  @override
  State<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<PinSetupSheet> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = _pin1.text.trim();
    final b = _pin2.text.trim();
    if (a.length != 4 || int.tryParse(a) == null) {
      setState(
          () => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    if (a != b) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await context.read<AppState>().setPin(a);
    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN set.')),
    );
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
          Text(
              context.read<AppState>().hasPin
                  ? 'Change PIN'
                  : 'Set a 4-digit PIN',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _pin1,
            decoration:
                const InputDecoration(labelText: 'New PIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
          ),
          TextField(
            controller: _pin2,
            decoration: const InputDecoration(
                labelText: 'Confirm PIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!,
                style: GoogleFonts.poppins(
                    color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save PIN'),
          ),
        ],
      ),
    );
  }
}
