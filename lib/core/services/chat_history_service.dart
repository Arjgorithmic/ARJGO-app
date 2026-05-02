import 'dart:convert';
import 'package:arjgo/core/models/chat_session.dart';
import 'package:arjgo/core/services/database_service.dart';
import 'package:arjgo/core/services/chat_service.dart';
import 'package:uuid/uuid.dart';

class ChatHistoryService {
  static const String boxName = 'chat_sessions'; // Kept for reference
  final _dbService = DatabaseService();

  Future<void> saveSession(ChatSession session) async {
    final db = await _dbService.db;
    
    // 1. Save or Update Session Metadata
    db.execute(
      'INSERT OR REPLACE INTO chat_sessions (id, title, updated_at) VALUES (?, ?, ?)',
      [session.id, session.title, session.updatedAt.toIso8601String()],
    );

    // 2. Clear and Re-save Messages for this session
    db.execute('DELETE FROM chat_messages WHERE session_id = ?', [session.id]);
    
    for (var msg in session.messages) {
      final msgId = const Uuid().v4();
      final sourcesJson = msg.sources != null ? jsonEncode(msg.sources) : null;
      
      db.execute(
        'INSERT INTO chat_messages (id, session_id, role, content, sources, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        [
          msgId,
          session.id,
          msg.isUser ? 'user' : 'assistant',
          msg.content,
          sourcesJson,
          msg.timestamp.toIso8601String()
        ],
      );
    }
  }

  Future<List<ChatSession>> getAllSessions() async {
    final db = await _dbService.db;
    
    final sessionRows = db.select('SELECT * FROM chat_sessions ORDER BY updated_at DESC');
    final List<ChatSession> sessions = [];

    for (var row in sessionRows) {
      final sessionId = row['id'] as String;
      final msgRows = db.select(
        'SELECT * FROM chat_messages WHERE session_id = ? ORDER BY created_at ASC',
        [sessionId],
      );

      final messages = msgRows.map((m) {
        final sourcesRaw = m['sources'] as String?;
        final List<String>? sources = sourcesRaw != null ? List<String>.from(jsonDecode(sourcesRaw)) : null;
        
        return ChatMessage(
          content: m['content'] as String,
          isUser: m['role'] == 'user',
          timestamp: DateTime.parse(m['created_at'] as String),
          sources: sources,
        );
      }).toList();

      sessions.add(ChatSession(
        id: sessionId,
        title: row['title'] as String,
        messages: messages,
        updatedAt: DateTime.parse(row['updated_at'] as String),
      ));
    }
    
    return sessions;
  }

  Future<void> deleteSession(String id) async {
    final db = await _dbService.db;
    db.execute('DELETE FROM chat_sessions WHERE id = ?', [id]);
    // Cascade delete handles chat_messages if foreign keys are enabled
  }

  Future<ChatSession> createNewSession() async {
    final session = ChatSession(
      id: const Uuid().v4(),
      title: 'New Chat',
      messages: [],
      updatedAt: DateTime.now(),
    );
    await saveSession(session);
    return session;
  }
}
