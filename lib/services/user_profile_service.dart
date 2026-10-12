import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple, direct user profile from Supabase Auth.
/// Single source of truth: Supabase auth user metadata.
/// (User-provided pattern — no complex multi-layer sync.)
class UserProfileService {
  static User? get currentUser =>
      Supabase.instance.client.auth.currentUser;

  /// Display name: full_name -> name -> email prefix -> 'Lifeez User'
  static String get displayName {
    final user = currentUser;
    if (user == null) return 'Lifeez User';
    final meta = user.userMetadata;
    if (meta != null) {
      for (final k in ['full_name', 'name', 'display_name']) {
        final v = meta[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    final email = user.email ?? '';
    if (email.contains('@')) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) {
        // Capitalize first letter for nicer display
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
    }
    return 'Lifeez User';
  }

  /// Avatar URL: avatar_url -> picture
  static String? get avatarUrl {
    final meta = currentUser?.userMetadata;
    if (meta == null) return null;
    for (final k in ['avatar_url', 'picture', 'photo_url']) {
      final v = meta[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// Save display name directly to Supabase auth metadata.
  static Future<void> saveDisplayName(String name) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'full_name': name.trim()}),
    );
  }
}
