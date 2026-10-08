import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase bootstrap.
///
/// Supabase credentials for lifeez-app project.
class SupabaseService {
  static Future<void> init() async {
    await Supabase.initialize(
            url: 'https://mxoejkweedxhndzwpxmj.supabase.co',
            publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14b2Vqa3dlZWR4aG5kendweG1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0MzcxMDQsImV4cCI6MjEwNzAxMzEwNH0.EmB1GGm_as8AmVKEE_gVeSAP6B-MzzCz_OHULD7yvyg',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;
}
