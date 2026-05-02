import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackService {
  final _client = Supabase.instance.client;

  Future<void> submitFeedback({
    required String name,
    required String email,
    required String content,
  }) async {
    await _client.from('feedback').insert({
      'name': name,
      'email': email,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
