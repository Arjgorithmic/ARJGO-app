import 'dart:convert';
import 'dart:typed_data';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/services/scan_history_service.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class _ScanState {
  final Uint8List? imageBytes;
  final bool isAnalyzing;
  final String? result;
  final List<ScanResult> history;

  const _ScanState({
    this.imageBytes,
    this.isAnalyzing = false,
    this.result,
    this.history = const [],
  });

  _ScanState copyWith({
    Uint8List? imageBytes,
    bool? isAnalyzing,
    String? result,
    List<ScanResult>? history,
  }) =>
      _ScanState(
        imageBytes: imageBytes ?? this.imageBytes,
        isAnalyzing: isAnalyzing ?? this.isAnalyzing,
        result: result ?? this.result,
        history: history ?? this.history,
      );
}

class _ScanNotifier extends StateNotifier<_ScanState> {
  final AuthState authState;
  final Dio _dio = Dio();
  final ScanHistoryService _historyService = ScanHistoryService();

  _ScanNotifier(this.authState) : super(const _ScanState()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await _historyService.getHistory();
    state = state.copyWith(history: h);
  }

  void setImage(Uint8List bytes) {
    state = state.copyWith(imageBytes: bytes, isAnalyzing: false, result: null);
  }

  Future<void> analyze() async {
    if (state.imageBytes == null) return;
    state = state.copyWith(isAnalyzing: true, result: null);

    const commonPrompt =
        'Describe this image clearly for a minimalist AI tool. Focus on objects and context.';
    String finalResult = '';

    if (authState.isOnlineModel && authState.openRouterKey.isNotEmpty) {
      try {
        final base64Image = base64Encode(state.imageBytes!);
        final response = await _dio.post(
          'https://openrouter.ai/api/v1/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer ${authState.openRouterKey}',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://arjgo.app',
              'X-Title': 'Arjgo App',
            },
          ),
          data: {
            'model': 'qwen/qwen3-vl-8b-instruct',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': commonPrompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                  },
                ],
              }
            ],
          },
        );

        finalResult =
            response.data['choices'][0]['message']['content'] as String;
      } catch (e) {
        finalResult = 'Error: $e';
      }
    } else {
      await Future.delayed(const Duration(seconds: 2));
      finalResult = 'ENGINE: LOCAL · QWEN3-VL-2B\n\n'
          'The image contains structural geometry with high contrast. '
          'Primary object identified in central focal point.';
    }

    state = state.copyWith(isAnalyzing: false, result: finalResult);

    // Save to history
    final resObj = ScanResult(
      date: DateTime.now().toIso8601String(),
      result: finalResult,
      imageUrl: '',
    );
    await _historyService.saveResult(resObj);
    _loadHistory();
  }

  void reset() =>
      state = state.copyWith(imageBytes: null, result: null, isAnalyzing: false);
}

final _scanStateProvider =
    StateNotifierProvider<_ScanNotifier, _ScanState>((ref) {
  final authState = ref.watch(authProvider);
  return _ScanNotifier(authState);
});

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  Future<void> _pickImage(ImageSource source, _ScanNotifier notifier) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1024);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      notifier.setImage(bytes);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_scanStateProvider);
    final notifier = ref.read(_scanStateProvider.notifier);
    final authState = ref.watch(authProvider);
    final modelReady = authState.isModelConfigured;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  const ArjgoLogo(),
                  const Spacer(),
                  if (state.imageBytes != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => notifier.reset(),
                    ),
                ],
              ),
            ),

            if (state.imageBytes != null) ...[
              const SizedBox(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          state.imageBytes!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: state.isAnalyzing
                              ? const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 1))
                              : SingleChildScrollView(
                                  child: Text(
                                    state.result ?? 'READY FOR ANALYSIS',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w300,
                                      height: 1.6,
                                      color: state.result == null
                                          ? AppColors.grey
                                          : Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (state.result == null && !state.isAnalyzing) ...[
                        const SizedBox(height: 16),
                        _ActionBtn(
                            label: 'ANALYSE', onTap: () => notifier.analyze()),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: state.history.isEmpty
                    ? Center(
                        child: Text(
                          'CAPTURE TO BEGIN',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey,
                            letterSpacing: 2,
                          ),
                        ),
                      )
                    : _HistoryList(history: state.history),
              ),
            ],

            // Bottom controls
            if (state.imageBytes == null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundBtn(
                      icon: Icons.photo_library_outlined,
                      onTap: () => _pickImage(ImageSource.gallery, notifier),
                      small: true,
                    ),
                    const SizedBox(width: 40),
                    _RoundBtn(
                      icon: Icons.camera_alt_outlined,
                      onTap: modelReady
                          ? () => _pickImage(ImageSource.camera, notifier)
                          : null,
                    ),
                    const SizedBox(width: 40),
                    const SizedBox(width: 48), // Spacer for symmetry
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: AppColors.accent,
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool small;
  const _RoundBtn({required this.icon, this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 48.0 : 72.0;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1.0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Icon(icon, color: AppColors.accent, size: small ? 20 : 28),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<ScanResult> history;
  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final item = history[i];
        final date = DateTime.tryParse(item.date) ?? DateTime.now();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMM d, h:mm a').format(date),
                style: GoogleFonts.dmSans(
                    fontSize: 9,
                    color: AppColors.grey,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                item.result,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}
