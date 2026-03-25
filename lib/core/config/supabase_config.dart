import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SupabaseConfig {
  // TODO: Replace with your actual Supabase project URL and Anon Key
  static const String url = 'https://trztxjwjciaeckrasxzg.supabase.co';
  static const String anonKey = 'sb_publishable_7ZgAdKAXOaf1k5_lzTsa8A_e8PGx7_K';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
