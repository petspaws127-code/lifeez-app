import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric unlock support for the Lifeez PIN lock screen.
///
/// Wraps `local_auth` for real fingerprint / face authentication and
/// stores the user's per-type opt-in in SharedPreferences. Biometrics are
/// strictly an *alternative* to the PIN — a PIN must exist first.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const _kFingerprintEnabled = 'biometric_fingerprint_enabled';
  static const _kFaceEnabled = 'biometric_face_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  /// True if the device has biometric hardware / OS support at all.
  Future<bool> get isSupported async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// True if the device reports fingerprint as an enrolled/available type.
  Future<bool> get hasFingerprint async {
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.contains(BiometricType.fingerprint);
    } catch (_) {
      return false;
    }
  }

  /// True if the device reports face as an enrolled/available type.
  Future<bool> get hasFace async {
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.contains(BiometricType.face);
    } catch (_) {
      return false;
    }
  }

  /// Runs a real biometric prompt. Returns true only when the OS reports
  /// a successful biometric match; false on cancel, failure, or any error.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ------------------------- user preferences -------------------------

  Future<bool> isFingerprintEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFingerprintEnabled) ?? false;
  }

  Future<void> setFingerprintEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFingerprintEnabled, value);
  }

  Future<bool> isFaceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFaceEnabled) ?? false;
  }

  Future<void> setFaceEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFaceEnabled, value);
  }

  /// True when the user has opted into at least one biometric type.
  Future<bool> get isAnyBiometricEnabled async {
    final results = await Future.wait([
      isFingerprintEnabled(),
      isFaceEnabled(),
    ]);
    return results.any((v) => v);
  }

  /// Clears both opt-ins (used when the PIN itself is removed, since
  /// biometrics are only an alternative to entering the PIN).
  Future<void> clearAll() async {
    await setFingerprintEnabled(false);
    await setFaceEnabled(false);
  }
}
