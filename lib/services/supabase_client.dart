import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase bootstrap.
///
/// TODO: paste your Supabase project credentials below (Supabase dashboard
/// → Project Settings → API). The app will not start without them.
class SupabaseService {
  static Future<void> init() async {
    await Supabase.initialize(
      // TODO: paste your Supabase project URL, e.g. https://xyzcompany.supabase.co
      url: 'TODO-PASTE-YOUR-SUPABASE-URL',
      // TODO: paste your Supabase "anon public" key (Project Settings → API).
      publishableKey: 'TODO-PASTE-YOUR-SUPABASE-ANON-KEY',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;
}
