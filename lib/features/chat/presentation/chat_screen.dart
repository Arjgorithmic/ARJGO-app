import 'package:arjgo/core/models/chat_session.dart';
import 'package:arjgo/core/services/chat_service.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() => _isTyping = true);
    
    await ref.read(chatProvider.notifier).sendMessage(text);
    
    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          currentSession?.title.toUpperCase() ?? 'CHAT',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            onPressed: () => ref.read(chatProvider.notifier).createNewSession(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => ref.read(chatProvider.notifier).deleteCurrentSession(),
          ),
        ],
      ),
      drawer: const _ChatSessionsDrawer(),
      body: Column(
        children: [
          Expanded(
            child: currentSession == null || currentSession.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount: currentSession.messages.length,
                    itemBuilder: (context, i) => _ChatBubble(message: currentSession.messages[i]),
                  ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(height: 2, width: 40, child: LinearProgressIndicator(minHeight: 1, color: AppColors.accent, backgroundColor: Colors.transparent)),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ArjgoLogo(fontSize: 14),
          const SizedBox(height: 16),
          Text(
            'ARJGO INTELLIGENCE IS ACTIVE',
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppColors.grey.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: (_) => _sendMessage(),
              style: GoogleFonts.dmSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.arrow_upward, color: AppColors.accent),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _ChatSessionsDrawer extends ConsumerWidget {
  const _ChatSessionsDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(chatHistoryProvider);
    final currentSession = ref.watch(chatProvider);

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            child: Text(
              'HISTORY',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: AppColors.grey,
              ),
            ),
          ),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 1)),
              error: (e, _) => const Center(child: Text('Error loading history')),
              data: (sessions) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sessions.length,
                itemBuilder: (context, i) {
                  final s = sessions[i];
                  final isSelected = s.id == currentSession?.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent.withOpacity(0.05) : Colors.transparent,
                      border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent),
                    ),
                    child: ListTile(
                      title: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.accent : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('MMM d, HH:mm').format(s.updatedAt),
                        style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.grey),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.edit_outlined, size: 16, color: isSelected ? AppColors.accent : AppColors.grey),
                        onPressed: () => _showRenameDialog(context, ref, s),
                      ),
                      onTap: () {
                        ref.read(chatProvider.notifier).switchSession(s);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: OutlinedButton(
              onPressed: () {
                ref.read(chatProvider.notifier).createNewSession();
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                'NEW SESSION',
                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(),
        title: Text('RENAME SESSION', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.dmSans(fontSize: 14),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.dmSans(color: AppColors.grey, fontSize: 11)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(chatProvider.notifier).renameSession(session.id, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text('RENAME', style: GoogleFonts.dmSans(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.accent : Theme.of(context).cardColor,
          border: message.isUser ? null : Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: message.isUser ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                height: 1.5,
              ),
            ),
            if (message.sources != null && message.sources!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.sources!.map((s) => _SourceChip(name: s)).toList(),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: GoogleFonts.dmSans(
                fontSize: 8,
                color: message.isUser ? Colors.white.withOpacity(0.6) : AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String name;

  const _SourceChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 10, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            name.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

