import 'dart:typed_data';
import 'package:arjgo/core/services/database_service.dart';
import 'package:arjgo/core/services/vector_service.dart';
import 'package:arjgo/core/services/activity_log_service.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

class MigrationService {
  static Future<void> migrate() async {
    final dbService = DatabaseService();
    final db = await dbService.db;
    final vectorService = VectorService();
    
    // Check if already migrated by checking if activity_logs table has data
    final results = db.select('SELECT COUNT(*) as count FROM activity_logs');
    if (results.first['count'] as int > 0) {
      debugPrint('MIGRATION: SQLite already has data. Skipping.');
      return;
    }

    debugPrint('MIGRATION: Starting from Hive to SQLite...');

    // 1. Migrate Activity Logs
    if (Hive.isBoxOpen(ActivityLogService.boxName)) {
      final logBox = Hive.box(ActivityLogService.boxName);
      debugPrint('MIGRATION: Migrating ${logBox.length} activity logs...');
      
      for (var key in logBox.keys) {
        try {
          final log = Map<String, dynamic>.from(logBox.get(key));
          final id = log['id'] ?? key.toString();
          
          db.execute(
            'INSERT INTO activity_logs (id, content, created_at, logged_at) VALUES (?, ?, ?, ?)',
            [id, log['content'], log['created_at'], log['logged_at']],
          );
          
          // Vectorize (Graceful failure)
          if (DatabaseService.isVectorEnabled) {
            try {
              final embedding = vectorService.embed(log['content'] as String);
              final blob = Float32List.fromList(embedding).buffer.asUint8List();
              db.execute(
                'INSERT INTO vec_logs (id, embedding) VALUES (?, ?)',
                [id, blob],
              );
            } catch (e) {
              debugPrint('MIGRATION WARNING: Could not vectorize log: $e');
            }
          }
        } catch (e) {
          debugPrint('MIGRATION ERROR (Log): $e');
        }
      }
    }

    // 2. Migrate Scans
    try {
      final scanBox = await Hive.openBox('traits_history');
      debugPrint('MIGRATION: Migrating ${scanBox.length} scans...');
      
      for (var key in scanBox.keys) {
        try {
          final scan = Map<String, dynamic>.from(scanBox.get(key));
          final id = DateTime.parse(scan['date']).millisecondsSinceEpoch.toString();
          
          db.execute(
            'INSERT INTO scans (id, trait_id, trait_name, result, image_path, created_at) VALUES (?, ?, ?, ?, ?, ?)',
            [id, scan['traitId'], scan['traitName'], scan['result'], scan['imagePath'], scan['date']],
          );
          
          // Vectorize (Graceful failure)
          if (DatabaseService.isVectorEnabled) {
            try {
              final embedding = vectorService.embed(scan['result'] as String);
              final blob = Float32List.fromList(embedding).buffer.asUint8List();
              db.execute(
                'INSERT INTO vec_scans (id, embedding) VALUES (?, ?)',
                [id, blob],
              );
            } catch (e) {
              debugPrint('MIGRATION WARNING: Could not vectorize scan: $e');
            }
          }
        } catch (e) {
          debugPrint('MIGRATION ERROR (Scan): $e');
        }
      }
    } catch (e) {
      debugPrint('MIGRATION: No scan history found or error opening box.');
    }

    debugPrint('MIGRATION: Completed successfully.');
  }
}
