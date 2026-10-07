import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool get isSignedIn =>
      SupabaseService.client.auth.currentUser != null;

  String? get userId => SupabaseService.currentUserId;

  // ---------------------------------------------------------------- Google
  Future<void> signInWithGoogle() async {
    // TODO: create OAuth client IDs in Google Cloud Console
    // (https://console.cloud.google.com → APIs & Services → Credentials):
    //   - Android client (needs your SHA-1 from `keytool -list -v`)
    //   - iOS client (needs your iOS bundle id)
    //   - Web client → paste below as serverClientId
    // Then enable the Google provider in Supabase → Authentication → Providers.
    const iosClientId = 'TODO-PASTE-GOOGLE-iOS-CLIENT-ID';
    const serverClientId = 'TODO-PASTE-GOOGLE-WEB-CLIENT-ID';

    final googleSignIn = GoogleSignIn(
      clientId: iosClientId.startsWith('TODO') ? null : iosClientId,
      serverClientId:
          serverClientId.startsWith('TODO') ? null : serverClientId,
      scopes: const ['email', 'profile'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      // User cancelled the account picker — not an error.
      return;
    }
    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.startsWith('TODO')) {
      throw const AuthSetupException(
        'Google sign-in is not configured yet. Add your Google OAuth client '
        'IDs in lib/services/auth_service.dart (see the TODO above).',
      );
    }
    await SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
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

  // ----------------------------------------------------------------- Misc
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    await SupabaseService.client.auth.signOut();
    notifyListeners();
  }
}
