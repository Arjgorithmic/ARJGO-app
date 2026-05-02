import 'package:arjgo/core/models/chat_session.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/services/chat_history_service.dart';
import 'package:arjgo/core/services/activity_log_service.dart';
import 'package:arjgo/core/services/document_service.dart';
import 'package:arjgo/core/services/finance_service.dart';
import 'package:arjgo/core/services/llama_server_service.dart';
import 'package:arjgo/core/services/trait_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? sources; // New: For RAG citations

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.sources,
  });

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map) {
    return ChatMessage(
      content: map['content'] as String,
      isUser: map['is_user'] as bool,
      timestamp: DateTime.parse(map['timestamp'] as String),
      sources: map['sources'] != null ? List<String>.from(map['sources'] as Iterable) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'is_user': isUser,
      'timestamp': timestamp.toIso8601String(),
      'sources': sources,
    };
  }
}

class ChatService extends StateNotifier<ChatSession?> {
  final Ref _ref;
  final Dio _dio = Dio();
  final _historyService = ChatHistoryService();
  final _logService = ActivityLogService();
  final _traitService = TraitStorageService();
  final _docService = DocumentService();
  final _financeService = FinanceService();

  ChatService(this._ref) : super(null) {
    _initDefaultSession();
  }

  Future<void> _initDefaultSession() async {
    final sessions = await _historyService.getAllSessions();
    if (sessions.isNotEmpty) {
      state = sessions.first;
    } else {
      state = await _historyService.createNewSession();
    }
  }

  Future<void> switchSession(ChatSession session) async {
    state = session;
  }

  Future<void> createNewSession() async {
    state = await _historyService.createNewSession();
  }

  Future<void> sendMessage(String text) async {
    if (state == null) return;

    final userMessage = ChatMessage(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    final updatedMessages = [...state!.messages, userMessage];
    String updatedTitle = state!.title;
    
    if (updatedTitle == 'New Chat' && text.length > 5) {
      updatedTitle = text.length > 30 ? '${text.substring(0, 27)}...' : text;
    }

    state = ChatSession(
      id: state!.id,
      title: updatedTitle,
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
    
    await _historyService.saveSession(state!);

    final auth = _ref.read(authProvider).state;
    
    try {
      String response;
      List<String>? sources;

      if (auth.isOnlineModel && auth.openRouterKey != null) {
        final result = await _runCloudChat(text, auth.openRouterKey!);
        response = result['content'] as String;
        sources = result['sources'] as List<String>?;
      } else {
        final result = await _runLocalChat(text);
        response = result['content'] as String;
        sources = result['sources'] as List<String>?;
      }

      // Handle Agentic Actions
      await _handleAgenticActions(response);

      final aiMessage = ChatMessage(
        content: _stripActions(response),
        isUser: false,
        timestamp: DateTime.now(),
        sources: sources,
      );
      
      final finalMessages = [...state!.messages, aiMessage];
      state = ChatSession(
        id: state!.id,
        title: state!.title,
        messages: finalMessages,
        updatedAt: DateTime.now(),
      );
      
      await _historyService.saveSession(state!);
    } catch (e) {
      final errorMessage = ChatMessage(
        content: 'Error: Could not connect to the intelligence engine. $e',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = ChatSession(
        id: state!.id,
        title: state!.title,
        messages: [...state!.messages, errorMessage],
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> _handleAgenticActions(String response) async {
    final actionRegex = RegExp(r'\[ACTION:\s*(\w+)\s*(.*?)\]', dotAll: true);
    final matches = actionRegex.allMatches(response);

    for (final match in matches) {
      final actionType = match.group(1);
      final paramsRaw = match.group(2) ?? '';
      
      if (actionType == 'CREATE_LOG') {
        final content = _extractParam(paramsRaw, 'content');
        if (content.isNotEmpty) {
          await _logService.saveLog(content);
        }
      }
    }
  }

  String _extractParam(String params, String name) {
    final regex = RegExp('$name="(.*?)"', dotAll: true);
    return regex.firstMatch(params)?.group(1) ?? '';
  }

  String _stripActions(String text) {
    final actionRegex = RegExp(r'\[ACTION:\s*(\w+)\s*(.*?)\]', dotAll: true);
    String stripped = text.replaceAll(actionRegex, '').trim();
    
    // If stripped is empty, the model likely put the entire message inside a tag
    if (stripped.isEmpty) {
      final firstMatch = actionRegex.firstMatch(text);
      if (firstMatch != null) {
        final params = firstMatch.group(2) ?? '';
        final content = _extractParam(params, 'content');
        if (content.isNotEmpty) return content;
      }
    }
    
    return stripped;
  }

  Future<Map<String, dynamic>> _runLocalChat(String text) async {
    final relevantLogs = await _logService.searchLogsSemantic(text);
    final relevantScans = await _traitService.searchScansSemantic(text);
    final relevantDocs = await _docService.queryKnowledgeBase(text);
    final relevantFinances = await _financeService.searchFinancesSemantic(text);

    List<String> sources = [];
    String contextStr = 'No relevant personal data found.';
    
    if (relevantLogs.isNotEmpty || relevantScans.isNotEmpty || relevantDocs.isNotEmpty || relevantFinances.isNotEmpty) {
      contextStr = '';
      if (relevantLogs.isNotEmpty) {
        contextStr += "\n[RELEVANT MEMORIES]\n" + relevantLogs.map((l) => "- ${l.content}").join("\n");
      }
      if (relevantScans.isNotEmpty) {
        contextStr += "\n[RELEVANT SCANS]\n" + relevantScans.map((s) => "- ${s.traitName}: ${s.result}").join("\n");
      }
      if (relevantFinances.isNotEmpty) {
        contextStr += "\n[FINANCE DATA]\n" + relevantFinances.map((f) => "- ${f.type.name.toUpperCase()}: ${f.category} (₹${f.amount.toStringAsFixed(2)}) - ${f.description}").join("\n");
      }
      if (relevantDocs.isNotEmpty) {
        contextStr += "\n[KNOWLEDGE BASE]\n" + relevantDocs.map((d) {
          if (!sources.contains(d.docName)) sources.add(d.docName);
          return "From ${d.docName}: ${d.content}";
        }).join("\n\n");
      }
    }

    final history = state!.messages.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.content,
    }).toList();

    if (LlamaServer.isInferenceRunning) {
      return {
        'content': '⚠️ The intelligence engine is currently busy with another request (e.g. a scan). Please wait a few seconds and try again.',
        'sources': null,
      };
    }

    LlamaServer.isInferenceRunning = true;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final timeStr = DateFormat('jm').format(now);

    try {
      final response = await _dio.post(
        'http://127.0.0.1:8080/v1/chat/completions',
        data: {
          'model': 'qwen2-vl',
          'messages': [
            {
              'role': 'system', 
               'content': 'You are Arjgo, a personal intelligence engine. '
                         'CURRENT DATE: $dateStr, $timeStr. '
                         'MODEL: Local (llama-server). '
                         'INSTRUCTIONS:\n'
                         '1. Respond naturally in plain text for general conversation.\n'
                         '2. To perform background actions, append tags like [ACTION: CREATE_LOG content="..."] to your text.\n'
                         '3. DO NOT wrap your entire reply in a tag unless it is purely a background task.\n'
                         '4. If asked for the date or status, reply in plain text using the info provided above.\n\n'
                         'CONTEXT:\n$contextStr'
            },
            ...history,
          ],
          'temperature': 0.7,
          'max_tokens': 1024,
        },
      ).timeout(const Duration(seconds: 120));

      return {
        'content': response.data['choices'][0]['message']['content'] as String,
        'sources': sources.isEmpty ? null : sources,
      };
    } finally {
      LlamaServer.isInferenceRunning = false;
    }
  }

  Future<Map<String, dynamic>> _runCloudChat(String text, String apiKey) async {
    final relevantLogs = await _logService.searchLogsSemantic(text);
    final relevantScans = await _traitService.searchScansSemantic(text);
    final relevantDocs = await _docService.queryKnowledgeBase(text);
    final relevantFinances = await _financeService.searchFinancesSemantic(text);

    List<String> sources = [];
    String contextStr = 'No relevant personal data found.';
    
    if (relevantLogs.isNotEmpty || relevantScans.isNotEmpty || relevantDocs.isNotEmpty || relevantFinances.isNotEmpty) {
      contextStr = '';
      if (relevantLogs.isNotEmpty) {
        contextStr += "\n[RELEVANT MEMORIES]\n" + relevantLogs.map((l) => "- ${l.content}").join("\n");
      }
      if (relevantScans.isNotEmpty) {
        contextStr += "\n[RELEVANT SCANS]\n" + relevantScans.map((s) => "- ${s.traitName}: ${s.result}").join("\n");
      }
      if (relevantFinances.isNotEmpty) {
        contextStr += "\n[FINANCE DATA]\n" + relevantFinances.map((f) => "- ${f.type.name.toUpperCase()}: ${f.category} (₹${f.amount.toStringAsFixed(2)}) - ${f.description}").join("\n");
      }
      if (relevantDocs.isNotEmpty) {
        contextStr += "\n[KNOWLEDGE BASE]\n" + relevantDocs.map((d) {
          if (!sources.contains(d.docName)) sources.add(d.docName);
          return "From ${d.docName}: ${d.content}";
        }).join("\n\n");
      }
    }

    final history = state!.messages.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.content,
    }).toList();

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final timeStr = DateFormat('jm').format(now);

    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://arjgo.app',
        'X-Title': 'Arjgo',
      }),
      data: {
        'model': 'qwen/qwen-2-vl-72b-instruct',
        'messages': [
          {
            'role': 'system', 
            'content': 'You are Arjgo, a personal intelligence engine. '
                       'CURRENT DATE: $dateStr, $timeStr. '
                       'MODEL: Cloud (OpenRouter). '
                       'INSTRUCTIONS:\n'
                       '1. Respond naturally in plain text for general conversation.\n'
                       '2. To perform background actions, append tags like [ACTION: CREATE_LOG content="..."] to your text.\n'
                       '3. DO NOT wrap your entire reply in a tag unless it is purely a background task.\n\n'
                       'CONTEXT:\n$contextStr'
          },
          ...history,
        ],
      },
    ).timeout(const Duration(seconds: 60));

    return {
      'content': response.data['choices'][0]['message']['content'] as String,
      'sources': sources.isEmpty ? null : sources,
    };
  }

  Future<void> renameSession(String id, String newTitle) async {
    if (state != null && state!.id == id) {
      state = ChatSession(
        id: state!.id,
        title: newTitle,
        messages: state!.messages,
        updatedAt: DateTime.now(),
      );
      await _historyService.saveSession(state!);
    } else {
      final sessions = await _historyService.getAllSessions();
      final session = sessions.firstWhere((s) => s.id == id);
      final updated = ChatSession(
        id: session.id,
        title: newTitle,
        messages: session.messages,
        updatedAt: DateTime.now(),
      );
      await _historyService.saveSession(updated);
      if (state == null) {
        await _initDefaultSession();
      } else {
        state = state; 
      }
    }
  }

  Future<void> deleteCurrentSession() async {
    if (state == null) return;
    await _historyService.deleteSession(state!.id);
    await _initDefaultSession();
  }
}

final chatProvider = StateNotifierProvider<ChatService, ChatSession?>((ref) {
  return ChatService(ref);
});

final chatHistoryProvider = FutureProvider<List<ChatSession>>((ref) async {
  // Watch chatProvider to refresh list when session is updated/deleted
  ref.watch(chatProvider);
  return ChatHistoryService().getAllSessions();
});
