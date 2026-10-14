import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase bootstrap.
///
/// Supabase credentials for lifeez-app project.
class SupabaseService {
  static bool _ready = false;

  /// True only after [init] completed successfully. Guards startup paths
  /// so a failed backend init can never crash the app before first frame.
  static bool get isReady => _ready;

  static Future<void> init() async {
    await Supabase.initialize(
            url: 'https://mxoejkweedxhndzwpxmj.supabase.co',
            publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14b2Vqa3dlZWR4aG5kendweG1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0MzcxMDQsImV4cCI6MjEwNzAxMzEwNH0.EmB1GGm_as8AmVKEE_gVeSAP6B-MzzCz_OHULD7yvyg',
    );
    _ready = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }
}
