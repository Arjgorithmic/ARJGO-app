import 'dart:io';
import 'dart:typed_data';
import 'package:arjgo/core/services/database_service.dart';
import 'package:arjgo/core/services/vector_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class ArjgoDocument {
  final String id;
  final String name;
  final String path;
  final DateTime createdAt;

  ArjgoDocument({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAt,
  });
}

class KnowledgeChunk {
  final String content;
  final String docName;
  final String docId;
  final double distance;

  KnowledgeChunk({
    required this.content,
    required this.docName,
    required this.docId,
    required this.distance,
  });
}

class DocumentService {
  final _dbService = DatabaseService();
  final _vectorService = VectorService();

  Future<void> ingestDocument(File file) async {
    final db = await _dbService.db;
    final id = const Uuid().v4();
    final name = p.basename(file.path);
    
    debugPrint('DOC: Ingesting $name...');
    
    try {
      // 1. Extract text
      String text = '';
      if (file.path.toLowerCase().endsWith('.pdf')) {
        text = await _extractPdfText(file);
      } else {
        text = await file.readAsString();
      }

      if (text.trim().isEmpty) throw Exception('Document is empty or unreadable.');

      // 2. Save document record
      db.execute(
        'INSERT INTO documents (id, name, path, created_at) VALUES (?, ?, ?, ?)',
        [id, name, file.path, DateTime.now().toIso8601String()],
      );

      // 3. Chunk and Vectorize
      await _indexChunks(id, text);
      debugPrint('DOC: Ingestion complete for $name.');
    } catch (e) {
      debugPrint('DOC ERROR: Ingestion failed for $name: $e');
      rethrow;
    }
  }

  Future<String> _extractPdfText(File file) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      debugPrint('PDF ERROR: Extraction failed: $e');
      return '';
    }
  }

  Future<void> _indexChunks(String docId, String text) async {
    final db = await _dbService.db;
    // Simple window chunking
    const chunkSize = 600; // ~150 tokens
    const overlap = 120;
    
    int index = 0;
    for (int i = 0; i < text.length; i += (chunkSize - overlap)) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      final chunk = text.substring(i, end);
      
      final chunkId = '${docId}_$index';
      db.execute(
        'INSERT INTO document_chunks (id, doc_id, content, chunk_index) VALUES (?, ?, ?, ?)',
        [chunkId, docId, chunk, index],
      );

      // Vectorize (Graceful failure)
      if (!DatabaseService.isVectorEnabled) return;

      try {
        final embedding = _vectorService.embed(chunk);
        final blob = Float32List.fromList(embedding).buffer.asUint8List();
        db.execute(
          'INSERT INTO vec_chunks (id, embedding) VALUES (?, ?)',
          [chunkId, blob],
        );
      } catch (e) {
        debugPrint('DOC INDEX ERROR: Could not save vector embedding: $e');
      }

      index++;
      if (i + chunkSize >= text.length) break;
    }
  }

  Future<List<ArjgoDocument>> getDocuments() async {
    final db = await _dbService.db;
    final results = db.select('SELECT * FROM documents ORDER BY created_at DESC');
    return results.map((row) => ArjgoDocument(
      id: row['id'] as String,
      name: row['name'] as String,
      path: row['path'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    )).toList();
  }

  Future<void> deleteDocument(String id) async {
    final db = await _dbService.db;
    db.execute('DELETE FROM documents WHERE id = ?', [id]);
    // Cascade delete handles document_chunks and manual delete for vec_chunks
    try {
      db.execute('DELETE FROM vec_chunks WHERE id LIKE ?', ['${id}_%']);
    } catch (_) {}
  }

  /// The RAG Core: Find relevant chunks across all or specific documents
  Future<List<KnowledgeChunk>> queryKnowledgeBase(String query, {int limit = 5}) async {
    if (!DatabaseService.isVectorEnabled || !_vectorService.isReady) {
      return _fallbackSearch(query, limit: limit);
    }

    try {
      final db = await _dbService.db;
      final embedding = _vectorService.embed(query);
      final blob = Float32List.fromList(embedding).buffer.asUint8List();

      final results = db.select('''
        SELECT 
          c.content,
          d.name as doc_name,
          d.id as doc_id,
          vec_distance_cosine(v.embedding, ?) as distance
        FROM document_chunks c
        JOIN documents d ON c.doc_id = d.id
        JOIN vec_chunks v ON c.id = v.id
        WHERE distance < 0.4
        ORDER BY distance ASC
        LIMIT ?
      ''', [blob, limit]);
      
      return results.map((row) => KnowledgeChunk(
        content: row['content'] as String,
        docName: row['doc_name'] as String,
        docId: row['doc_id'] as String,
        distance: row['distance'] as double,
      )).toList();
    } catch (e) {
      debugPrint('DOC QUERY ERROR: Vector search failed, falling back: $e');
      return _fallbackSearch(query, limit: limit);
    }
  }

  Future<List<KnowledgeChunk>> _fallbackSearch(String query, {int limit = 5}) async {
    final db = await _dbService.db;
    final results = db.select('''
      SELECT 
        c.content,
        d.name as doc_name,
        d.id as doc_id
      FROM document_chunks c
      JOIN documents d ON c.doc_id = d.id
      WHERE c.content LIKE ?
      LIMIT ?
    ''', ['%$query%', limit]);
    
    return results.map((row) => KnowledgeChunk(
      content: row['content'] as String,
      docName: row['doc_name'] as String,
      docId: row['doc_id'] as String,
      distance: 0.5, // Dummy distance for non-semantic search
    )).toList();
  }
}

