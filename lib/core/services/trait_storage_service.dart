import 'dart:typed_data';
import 'package:arjgo/core/services/database_service.dart';
import 'package:arjgo/core/services/vector_service.dart';
import 'package:flutter/foundation.dart';

class SavedScan {
  final String date;
  final String traitId;
  final String traitName;
  final String result;
  final String imagePath;
  final Map<String, dynamic>? structuredData;

  const SavedScan({
    required this.date,
    required this.traitId,
    required this.traitName,
    required this.result,
    required this.imagePath,
    this.structuredData,
  });

  factory SavedScan.fromJson(Map<String, dynamic> json) => SavedScan(
        date: json['date'] ?? json['created_at'],
        traitId: json['traitId'] ?? json['trait_id'],
        traitName: json['traitName'] ?? json['trait_name'],
        result: json['result'],
        imagePath: json['imagePath'] ?? json['image_path'],
        structuredData: null, // Structured data can be added later if needed
      );
}

class TraitStorageService {
  final _dbService = DatabaseService();
  final _vectorService = VectorService();

  static Future<void> init() async {
    // Hive init logic kept for safety/compatibility during migration phase
  }

  Future<void> save(SavedScan scan) async {
    final db = await _dbService.db;
    final id = DateTime.parse(scan.date).millisecondsSinceEpoch.toString();
    
    db.execute(
      'INSERT INTO scans (id, trait_id, trait_name, result, image_path, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [id, scan.traitId, scan.traitName, scan.result, scan.imagePath, scan.date],
    );

    // Vectorize results (Graceful failure)
    if (!DatabaseService.isVectorEnabled) return;

    try {
      final embedding = _vectorService.embed(scan.result);
      final blob = Float32List.fromList(embedding).buffer.asUint8List();
      db.execute(
        'INSERT INTO vec_scans (id, embedding) VALUES (?, ?)',
        [id, blob],
      );
    } catch (e) {
      debugPrint('TRAIT STORAGE ERROR: Could not save vector embedding: $e');
    }
  }

  Future<List<SavedScan>> getAll() async {
    final db = await _dbService.db;
    final results = db.select('SELECT * FROM scans ORDER BY created_at DESC');
    return results.map((row) => SavedScan.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> clear() async {
    final db = await _dbService.db;
    db.execute('DELETE FROM scans');
    try {
      db.execute('DELETE FROM vec_scans');
    } catch (_) {}
  }

  Future<void> delete(String date) async {
    final db = await _dbService.db;
    final id = DateTime.parse(date).millisecondsSinceEpoch.toString();
    db.execute('DELETE FROM scans WHERE id = ?', [id]);
    try {
      db.execute('DELETE FROM vec_scans WHERE id = ?', [id]);
    } catch (_) {}
  }

  /// Semantic search for scans
  Future<List<SavedScan>> searchScansSemantic(String query) async {
    if (!DatabaseService.isVectorEnabled || !_vectorService.isReady) {
      return _fallbackSearch(query);
    }

    try {
      final db = await _dbService.db;
      final embedding = _vectorService.embed(query);
      final blob = Float32List.fromList(embedding).buffer.asUint8List();

      final results = db.select('''
        SELECT 
          s.*,
          vec_distance_cosine(v.embedding, ?) as distance
        FROM scans s
        JOIN vec_scans v ON s.id = v.id
        WHERE distance < 0.35
        ORDER BY distance ASC
        LIMIT 10
      ''', [blob]);
      
      return results.map((row) => SavedScan.fromJson(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('TRAIT SEARCH ERROR: Vector search failed, falling back: $e');
      return _fallbackSearch(query);
    }
  }

  Future<List<SavedScan>> _fallbackSearch(String query) async {
    final db = await _dbService.db;
    final results = db.select(
      'SELECT * FROM scans WHERE result LIKE ? ORDER BY created_at DESC LIMIT 10',
      ['%$query%']
    );
    return results.map((row) => SavedScan.fromJson(Map<String, dynamic>.from(row))).toList();
  }
}
