import 'dart:io';
import 'dart:ffi';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vector/sqlite_vector.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;
  static bool isVectorEnabled = false;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'arjgo_vault.db');
    
    debugPrint('DB: Initializing at $dbPath');
    
    // 1. Load sqlite-vec extension
    try {
      debugPrint('DB: Registering sqlite-vec extension via SqliteExtension...');
      // On Android, we bundled it as libsqlite_vec.so in jniLibs
      final extension = SqliteExtension.inLibrary(
        DynamicLibrary.open('libsqlite_vec.so'),
        'sqlite3_vec_init',
      );
      sqlite3.ensureExtensionLoaded(extension);
      debugPrint('DB: sqlite-vec extension registered globally.');
    } catch (e) {
      debugPrint('DB: SqliteExtension registration failed: $e');
      // Fallback to the package helper just in case
      try {
        sqlite3.loadSqliteVectorExtension();
      } catch (_) {}
    }
    
    // 2. Open the database
    final db = sqlite3.open(dbPath);
    
    // 3. Final verification
    try {
      final version = db.select('SELECT vec_version() as v');
      debugPrint('DB: sqlite-vec active on connection, version: ${version.first['v']}');
      isVectorEnabled = true;
    } catch (e) {
      debugPrint('DB WARNING: Vector search DISABLED. Functions not available: $e');
      isVectorEnabled = false;
    }
    
    // 4. Enable Foreign Keys
    db.execute('PRAGMA foreign_keys = ON');
    
    // 5. Initialize tables
    _createTables(db);
    
    return db;
  }

  void _createTables(Database db) {
    // 1. Activity Logs
    db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        logged_at TEXT NOT NULL
      )
    ''');

    // 2. Scans
    db.execute('''
      CREATE TABLE IF NOT EXISTS scans (
        id TEXT PRIMARY KEY,
        trait_id TEXT NOT NULL,
        trait_name TEXT NOT NULL,
        result TEXT NOT NULL,
        image_path TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 3. Chat Sessions
    db.execute('''
      CREATE TABLE IF NOT EXISTS chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Chat History
    db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        sources TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES chat_sessions (id) ON DELETE CASCADE
      )
    ''');

    // 5. Documents
    db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 6. Finance Records
    db.execute('''
      CREATE TABLE IF NOT EXISTS finance_records (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 7. Liabilities (EMIs)
    db.execute('''
      CREATE TABLE IF NOT EXISTS liabilities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        monthly_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        remaining_amount REAL NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 6. Document Chunks (for RAG)
    db.execute('''
      CREATE TABLE IF NOT EXISTS document_chunks (
        id TEXT PRIMARY KEY,
        doc_id TEXT NOT NULL,
        content TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        FOREIGN KEY (doc_id) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');
    
    // 6. Vector Tables (VIRTUAL tables for sqlite-vec)
    _createVectorTable(db, 'vec_scans');
    _createVectorTable(db, 'vec_logs');
    _createVectorTable(db, 'vec_chunks');
    _createVectorTable(db, 'vec_chat');
    _createVectorTable(db, 'vec_finance');
  }

  void _createVectorTable(Database db, String tableName) {
    try {
      db.execute('CREATE VIRTUAL TABLE IF NOT EXISTS $tableName USING vec0(id TEXT PRIMARY KEY, embedding float[384])');
      debugPrint('DB: Vector table $tableName initialized.');
    } catch (e) {
      debugPrint('DB ERROR: Could not create vector table $tableName. $e');
    }
  }

  // Utility to dispose
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
