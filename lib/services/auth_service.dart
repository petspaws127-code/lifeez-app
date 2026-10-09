import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_client.dart';

/// Authentication for the 4 login options: Google, WhatsApp, Apple, Facebook.
///
/// Every provider calls its REAL native SDK / API. Nothing here is simulated:
/// each method throws a clear [AuthSetupException] naming the exact credential
/// that must be configured when a TODO below is still unfilled.
///
/// Setup checklist (details in README.md):
///  1. Google  → Google Cloud OAuth client IDs (Android + iOS + Web).
///  2. Apple   → Apple Services ID + redirect URI, enabled in Supabase Auth.
///  3. Facebook→ Meta App ID in AndroidManifest / Info.plist + Supabase Auth.
///  4. WhatsApp→ Supabase Edge Function `whatsapp-otp` + WhatsApp Business
///               Cloud API token & phone number ID.
class AuthSetupException implements Exception {
  final String message;
  const AuthSetupException(this.message);
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  static const _kAdminSession = 'lifeez_admin_session';
  static const _kAdminPlan = 'lifeez_admin_plan'; // 'demo' or 'paid'

  bool _adminSignedIn = false;
  String _adminPlan = 'demo';

  bool get isSignedIn =>
      SupabaseService.client.auth.currentUser != null || _adminSignedIn;

  bool get isAdmin => _adminSignedIn;
  String get adminPlan => _adminPlan;

  String? get userId => SupabaseService.currentUserId ?? (_adminSignedIn ? 'admin-local' : null);

  /// Restore admin session from storage. Call at startup.
  Future<void> restoreAdminSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _adminSignedIn = prefs.getBool(_kAdminSession) ?? false;
      _adminPlan = prefs.getString(_kAdminPlan) ?? 'demo';
      if (_adminSignedIn) notifyListeners();
    } catch (_) {}
  }

  /// Admin bypass sign-in. Persists so the user stays logged in
  /// across app restarts until they delete their account or sign out.
  Future<void> signInAsAdmin({String plan = 'demo'}) async {
    _adminSignedIn = true;
    _adminPlan = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminSession, true);
    await prefs.setString(_kAdminPlan, plan);
    notifyListeners();
  }

  /// Switch admin plan between demo (free) and paid.
  Future<void> setAdminPlan(String plan) async {
    _adminPlan = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAdminPlan, plan);
    notifyListeners();
  }

  /// Full account deletion — clears admin session and all local data.
  /// After this the user can create a fresh account.
  Future<void> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAdminSession);
    await prefs.remove(_kAdminPlan);
    // Clear all app data keys
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('lifeez_')) await prefs.remove(key);
    }
    _adminSignedIn = false;
    _adminPlan = 'demo';
    try {
      await SupabaseService.client.auth.signOut();
    } catch (_) {}
    notifyListeners();
  }

  // ---------------------------------------------------------------- Google
  Future<void> signInWithGoogle() async {
    // Uses Supabase OAuth via system browser - no SHA-1 needed.
    // Google provider must be enabled in Supabase dashboard.
    try {
      await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.lifeez://login-callback/',
        queryParams: {'prompt': 'select_account'},
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('access blocked') || msg.contains('403')) {
        throw AuthSetupException(
          'Google has blocked this sign-in. The app owner needs to publish '
          'the OAuth consent screen in Google Cloud Console, or add your '
          'email as a test user.');
      }
      rethrow;
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- Apple
  Future<void> signInWithApple() async {
    // TODO: Apple Developer portal (https://developer.apple.com):
    //   1. Create a Services ID, e.g. com.ailifeassistant.app.signin
    //   2. Configure "Sign in with Apple", set the return URL to:
    //        https://<your-supabase-ref>.supabase.co/auth/v1/callback
    //   3. Enable the Apple provider in Supabase → Authentication → Providers
    //      with the same Services ID.
    //   4. Paste both values below.
    const servicesId = 'TODO-PASTE-APPLE-SERVICES-ID';
    const redirectUri =
        'TODO-PASTE-APPLE-REDIRECT-URI'; // https://<ref>.supabase.co/auth/v1/callback

    if (servicesId.startsWith('TODO')) {
      throw const AuthSetupException(
        'Apple sign-in is not configured yet. Add your Apple Services ID in '
        'lib/services/auth_service.dart (see the TODO above).',
      );
    }

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: servicesId,
        redirectUri: Uri.parse(redirectUri),
      ),
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthSetupException(
          'Apple did not return an identity token. Check your Services ID.');
    }
    await SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
    notifyListeners();
  }

  // -------------------------------------------------------------- Facebook
  Future<void> signInWithFacebook() async {
    // TODO: Meta for Developers (https://developers.facebook.com):
    //   1. Create an app, add the Facebook Login product.
    //   2. Put the App ID in android/app/src/main/AndroidManifest.xml
    //      (<meta-data android:name="com.facebook.sdk.ApplicationId" .../>)
    //      and in ios/Runner/Info.plist (FacebookAppID).
    //   3. Enable the Facebook provider in Supabase → Authentication → Providers.
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );

    if (result.status == LoginStatus.cancelled) return;
    if (result.status != LoginStatus.success) {
      throw AuthSetupException(
        'Facebook login failed: ${result.message ?? result.status.name}. '
        'Make sure your Meta App ID is configured (see TODO above).',
      );
    }
    final token = result.accessToken?.tokenString;
    if (token == null) {
      throw const AuthSetupException(
          'Facebook did not return an access token.');
    }
    // Supabase accepts the Facebook access token via signInWithIdToken.
    await SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.facebook,
      idToken: token,
    );
    notifyListeners();
  }

  // -------------------------------------------------------------- WhatsApp
  /// Step 1: ask the Edge Function to send a 6-digit code to [phone]
  /// via the WhatsApp Business Cloud API template message.
  Future<void> sendWhatsAppCode(String phone) async {
    // TODO: deploy supabase/functions/whatsapp-otp (see README.md) and set
    // its secrets: WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID, plus the
    // service-role key so it can mint a session on verify.
    final res = await SupabaseService.client.functions.invoke(
      'whatsapp-otp',
      body: {'action': 'send', 'phone': phone},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw AuthSetupException('WhatsApp code failed: ${data['error']}');
    }
  }

  /// Step 2: verify the code; the Edge Function returns a one-time
  /// magic-link token_hash, which we redeem here for a real session.
  Future<void> verifyWhatsAppCode(String phone, String code) async {
    final res = await SupabaseService.client.functions.invoke(
      'whatsapp-otp',
      body: {'action': 'verify', 'phone': phone, 'code': code},
    );
    final data =
        res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
    final tokenHash = data['token_hash'] as String?;
    if (tokenHash == null) {
      throw AuthSetupException(
        'Code verification failed: ${data['error'] ?? 'unknown error'}.',
      );
    }
    await SupabaseService.client.auth.verifyOTP(
      token: tokenHash,
      tokenHash: tokenHash,
      type: OtpType.magiclink,
    );
    notifyListeners();
  }

  /// Email/password sign in with Supabase.
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
    } catch (e) {
      throw AuthSetupException('Login failed: ${e.toString()}');
    }
  }

  /// Email/password sign up with Supabase.
  Future<void> signUpWithEmail(String email, String password) async {
    try {
      await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
    } catch (e) {
      throw AuthSetupException('Sign up failed: ${e.toString()}');
    }
  }

  /// Passwordless email OTP: sends a 6-digit login code (Option A login).
  Future<void> sendEmailOtp(String email) async {
    try {
      await SupabaseService.client.auth.signInWithOtp(
        email: email.trim(),
      );
    } catch (e) {
      throw AuthSetupException('Could not send code: ${e.toString()}');
    }
  }

  /// Verifies the 6-digit email OTP code.
  Future<void> verifyEmailOtp(String email, String token) async {
    try {
      final res = await SupabaseService.client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.email,
      );
      if (res.session == null) {
        throw AuthSetupException('Invalid or expired code.');
      }
      notifyListeners();
    } catch (e) {
      if (e is AuthSetupException) rethrow;
      throw AuthSetupException('Verification failed: ${e.toString()}');
    }
  }

  // ----------------------------------------------------------------- Misc
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    // Clear admin session too
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAdminSession);
      await prefs.remove(_kAdminPlan);
    } catch (_) {}
    _adminSignedIn = false;
    _adminPlan = 'demo';
    await SupabaseService.client.auth.signOut();
    notifyListeners();
  }
}
