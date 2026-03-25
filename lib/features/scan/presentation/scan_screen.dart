import 'dart:convert';
import 'dart:typed_data';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class _ScanState {
  final Uint8List? imageBytes;
  final bool isAnalyzing;
  final String? result;

  const _ScanState({this.imageBytes, this.isAnalyzing = false, this.result});

  _ScanState copyWith(
          {Uint8List? imageBytes,
          bool? isAnalyzing,
          String? result}) =>
      _ScanState(
        imageBytes: imageBytes ?? this.imageBytes,
        isAnalyzing: isAnalyzing ?? this.isAnalyzing,
        result: result ?? this.result,
      );
}

class _ScanNotifier extends StateNotifier<_ScanState> {
  final AuthState authState;
  final Dio _dio = Dio();
  
  _ScanNotifier(this.authState) : super(const _ScanState());

  void setImage(Uint8List bytes) {
    state = _ScanState(imageBytes: bytes, isAnalyzing: false, result: null);
  }

  Future<void> analyze() async {
    if (state.imageBytes == null) return;
    state = state.copyWith(isAnalyzing: true, result: null);

    const commonPrompt = 'Describe this image clearly for a minimalist AI tool. Focus on objects and context.';

    if (authState.isOnlineModel && authState.openRouterKey.isNotEmpty) {
      // ── ONLINE: OpenRouter ──────────────────────────────────────────
      try {
        final base64Image = base64Encode(state.imageBytes!);
        // Using OpenRouter multimodal template
        final response = await _dio.post(
          'https://openrouter.ai/api/v1/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer ${authState.openRouterKey}',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://arjgo.app', // Required for some providers
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

        final result = response.data['choices'][0]['message']['content'] as String;
        state = state.copyWith(
          isAnalyzing: false,
          result: 'ENGINE: QWEN3-VL-8B-INSTRUCT (Cloud)\n\n$result',
        );
      } catch (e) {
        state = state.copyWith(
          isAnalyzing: false,
          result: 'Analysis unavailable. Please check your API key and connection.\nError: $e',
        );
      }
    } else {
      // ── OFFLINE: Simulated ──────────────────────────────────────────
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(
        isAnalyzing: false,
        result:
            'ENGINE: QWEN3-VL-2B-INSTRUCT (Local)\n\n'
            'The view contains a distinct arrangement of minimalist elements. '
            'Objects appear with high edge-contrast against the background. '
            'Composition suggests a focused subject in the center.\n\n'
            'Prompt: $commonPrompt',
      );
    }
  }

  void reset() => state = const _ScanState();
}

final _scanStateProvider =
    StateNotifierProvider<_ScanNotifier, _ScanState>((ref) {
  final authState = ref.watch(authProvider);
  return _ScanNotifier(authState);
});

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => notifier.reset(),
                    child: const Icon(Icons.arrow_back,
                        size: 18, color: AppColors.text),
                  ),
                ],
              ),
            ),

            if (state.imageBytes != null) ...[
              // Image preview
              const SizedBox(height: 16),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      state.imageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),

              // Divider + result
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Divider(),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                child: Text(
                  'ANALYSIS',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: state.isAnalyzing
                      ? Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.2,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Analysing…',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AppColors.grey,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        )
                      : state.result != null
                          ? SingleChildScrollView(
                              child: Text(
                                state.result!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.text,
                                  height: 1.6,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: () => notifier.analyze(),
                              child: Text(
                                'TAP TO ANALYSE',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                ),
              ),
            ] else ...[
              const Spacer(),
              Center(
                child: Text(
                  'Point. Capture. Understand.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: AppColors.grey,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Camera button
              Center(
                child: GestureDetector(
                  onTap: modelReady
                      ? () => _captureImage(context, notifier)
                      : null,
                  child: Opacity(
                    opacity: modelReady ? 1.0 : 0.4,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              if (!modelReady) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Model loading…',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage(
      BuildContext context, _ScanNotifier notifier) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        notifier.setImage(bytes);
      }
    } catch (_) {
      // Fall back to gallery on web where camera may not be available
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          notifier.setImage(bytes);
        }
      } catch (e) {
        debugPrint('Image pick error: $e');
      }
    }
  }
}
