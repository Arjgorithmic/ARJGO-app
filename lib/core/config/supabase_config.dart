import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SupabaseConfig {
  // TODO: Replace with your actual Supabase project URL and Anon Key
  static const String url = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String anonKey = 'YOUR_ANON_KEY';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
