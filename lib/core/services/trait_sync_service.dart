import 'package:arjgo/core/models/trait.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TraitSyncService {
  static const String _boxName = 'dynamic_traits';
  final _supabase = Supabase.instance.client;

  Future<void> syncTraits() async {
    try {
      debugPrint('TraitSync: Starting sync from Supabase...');
      final response = await _supabase
          .from('traits')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final box = await Hive.openBox(_boxName);
      
      // Clear old traits and save new ones
      await box.clear();
      for (var item in data) {
        await box.put(item['id'], {
          'id': item['id'],
          'name': item['name'],
          'description': item['description'] ?? '',
          'prompt_template': item['prompt_template'],
        });
      }
      debugPrint('TraitSync: Successfully synced ${data.length} traits.');
    } catch (e) {
      debugPrint('TraitSync: Sync failed: $e');
      // If sync fails, we still have Hive cache from last time
    }
  }

  Future<List<Trait>> getCachedTraits() async {
    final box = await Hive.openBox(_boxName);
    if (box.isEmpty) return [];

    return box.values.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return Trait(
        id: map['id'],
        name: map['name'],
        promptTemplate: map['prompt_template'],
        // description: map['description'], // Add if model supports it
      );
    }).toList();
  }
}
