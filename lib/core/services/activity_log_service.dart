import 'dart:typed_data';
import 'package:arjgo/core/services/database_service.dart';
import 'package:arjgo/core/services/vector_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class ActivityLog {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime loggedAt;

  ActivityLog({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.loggedAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      loggedAt: DateTime.parse(map['logged_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'logged_at': loggedAt.toIso8601String(),
    };
  }
}

class ActivityLogService {
  static const String boxName = 'activity_logs'; // Kept for migration reference
  final _dbService = DatabaseService();
  final _vectorService = VectorService();

  Future<void> saveLog(String content) async {
    final db = await _dbService.db;
    final id = const Uuid().v4();
    final now = DateTime.now();
    
    final log = ActivityLog(
      id: id,
      content: content,
      createdAt: now,
      loggedAt: now,
    );

    // Relational save
    db.execute(
      'INSERT INTO activity_logs (id, content, created_at, logged_at) VALUES (?, ?, ?, ?)',
      [log.id, log.content, log.createdAt.toIso8601String(), log.loggedAt.toIso8601String()],
    );

    // Semantic Vector save (Graceful failure)
    if (!DatabaseService.isVectorEnabled) return;
    
    try {
      final embedding = _vectorService.embed(content);
      final blob = Float32List.fromList(embedding).buffer.asUint8List();
      db.execute(
        'INSERT INTO vec_logs (id, embedding) VALUES (?, ?)',
        [id, blob],
      );
    } catch (e) {
      debugPrint('LOG SERVICE ERROR: Could not save vector embedding: $e');
    }
  }

  Future<List<ActivityLog>> getLogs() async {
    final db = await _dbService.db;
    final results = db.select('SELECT * FROM activity_logs ORDER BY logged_at DESC');
    return results.map((row) => ActivityLog.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> deleteLog(String id) async {
    final db = await _dbService.db;
    db.execute('DELETE FROM activity_logs WHERE id = ?', [id]);
    try {
      db.execute('DELETE FROM vec_logs WHERE id = ?', [id]);
    } catch (_) {}
  }

  Future<void> clearLogs() async {
    final db = await _dbService.db;
    db.execute('DELETE FROM activity_logs');
    try {
      db.execute('DELETE FROM vec_logs');
    } catch (_) {}
  }

  /// New Semantic Search Capability
  Future<List<ActivityLog>> searchLogsSemantic(String query) async {
    if (!DatabaseService.isVectorEnabled || !_vectorService.isReady) {
      return _fallbackSearch(query);
    }
    
    try {
      final db = await _dbService.db;
      final embedding = _vectorService.embed(query);
      final blob = Float32List.fromList(embedding).buffer.asUint8List();

      final results = db.select('''
        SELECT 
          l.*,
          vec_distance_cosine(v.embedding, ?) as distance
        FROM activity_logs l
        JOIN vec_logs v ON l.id = v.id
        WHERE distance < 0.35 -- Lower is more similar
        ORDER BY distance ASC
        LIMIT 10
      ''', [blob]);
      
      return results.map((row) => ActivityLog.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('LOG SEARCH ERROR: Vector search failed, falling back: $e');
      return _fallbackSearch(query);
    }
  }

  Future<List<ActivityLog>> _fallbackSearch(String query) async {
    final db = await _dbService.db;
    final results = db.select(
      'SELECT * FROM activity_logs WHERE content LIKE ? ORDER BY logged_at DESC LIMIT 10',
      ['%$query%']
    );
    return results.map((row) => ActivityLog.fromMap(Map<String, dynamic>.from(row))).toList();
  }
}
