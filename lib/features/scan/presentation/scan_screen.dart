import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/services/scan_history_service.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/features/skills/presentation/skills_screen.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class _ScanState {
  final String? tempLocalPath;
  final bool isAnalyzing;
  final String? result;
  final List<ScanResult> history;
  final Skill? selectedSkill;

  const _ScanState({
    this.tempLocalPath,
    this.isAnalyzing = false,
    this.result,
    this.history = const [],
    this.selectedSkill,
  });

  _ScanState copyWith({
    String? tempLocalPath,
    bool? isAnalyzing,
    String? result,
    List<ScanResult>? history,
    Skill? selectedSkill,
    bool clearSkill = false,
  }) =>
      _ScanState(
        tempLocalPath: tempLocalPath ?? this.tempLocalPath,
        isAnalyzing: isAnalyzing ?? this.isAnalyzing,
        result: result ?? this.result,
        history: history ?? this.history,
        selectedSkill: clearSkill ? null : (selectedSkill ?? this.selectedSkill),
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
    state = state.copyWith(history: h.reversed.toList());
  }

  void setImage(String path) {
    state = state.copyWith(
        tempLocalPath: path, isAnalyzing: false, result: null);
  }

  void selectSkill(Skill? skill) {
    state = state.copyWith(selectedSkill: skill, clearSkill: skill == null);
  }

  Future<void> analyze() async {
    if (state.tempLocalPath == null) return;
    state = state.copyWith(isAnalyzing: true, result: null);

    Uint8List bytes;
    if (kIsWeb) {
      final response = await _dio.get(state.tempLocalPath!,
          options: Options(responseType: ResponseType.bytes));
      bytes = Uint8List.fromList(response.data);
    } else {
      bytes = await File(state.tempLocalPath!).readAsBytes();
    }

    const commonPrompt = 'Analyze this image. Minimalist, professional tone.';
    final systemPrompt = state.selectedSkill?.description ?? commonPrompt;

    String finalResult = '';

    if (authState.isOnlineModel && authState.openRouterKey.isNotEmpty) {
      try {
        final base64Image = base64Encode(bytes);
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
              {'role': 'system', 'content': systemPrompt},
              {
                'role': 'user',
                'content': [
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
      finalResult = '### ANALYSIS (LOCAL)\n\n'
          '**System Prompt Applied:** ${state.selectedSkill?.name ?? "Default"}\n\n'
          '*   Structural geometry identified.\n'
          '*   Minimalist composition confirmed.';
    }

    String permanentPath = state.tempLocalPath!;
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      permanentPath = '${appDir.path}/$fileName';
      await File(state.tempLocalPath!).copy(permanentPath);
    }

    final resObj = ScanResult(
      date: DateTime.now().toIso8601String(),
      result: finalResult,
      imagePath: permanentPath,
    );
    await _historyService.saveResult(resObj);
    state = state.copyWith(isAnalyzing: false, result: finalResult);
    _loadHistory();
  }

  Future<void> deleteHistory(String date) async {
    await _historyService.deleteResult(date);
    _loadHistory();
  }

  void reset() =>
      state = state.copyWith(tempLocalPath: null, result: null, isAnalyzing: false, clearSkill: true);
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
      notifier.setImage(picked.path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_scanStateProvider);
    final notifier = ref.read(_scanStateProvider.notifier);
    final modelReady = ref.watch(authProvider).isModelConfigured;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const ArjgoLogo(),
                  const Spacer(),
                  if (state.tempLocalPath != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => notifier.reset(),
                    ),
                ],
              ),
            ),
            Expanded(
              child: state.tempLocalPath != null
                  ? _ActiveScanOverlay(state: state, notifier: notifier)
                  : _HistoryGrid(history: state.history),
            ),
            if (state.tempLocalPath == null)
              _BottomControls(
                onGallery: () => _pickImage(ImageSource.gallery, notifier),
                onCamera: modelReady
                    ? () => _pickImage(ImageSource.camera, notifier)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveScanOverlay extends ConsumerWidget {
  final _ScanState state;
  final _ScanNotifier notifier;
  const _ActiveScanOverlay({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(skillsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: kIsWeb
                  ? Image.network(state.tempLocalPath!,
                      fit: BoxFit.cover, width: double.infinity)
                  : Image.file(File(state.tempLocalPath!),
                      fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 16),

          if (state.result == null && !state.isAnalyzing) ...[
            Text(
              'SELECT SKILL AS SYSTEM PROMPT',
              style: GoogleFonts.dmSans(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.grey,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: skillsAsync.when(
                data: (skills) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: skills.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final s = skills[i];
                    final isSelected = state.selectedSkill?.name == s.name;
                    return GestureDetector(
                      onTap: () => notifier.selectSkill(isSelected ? null : s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent.withOpacity(0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.divider,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          s.name.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.accent
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
              ),
            ),
          ],

          const SizedBox(height: 16),
          if (state.isAnalyzing)
            const Center(child: CircularProgressIndicator(strokeWidth: 1))
          else if (state.result != null)
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: state.result!,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                      p: GoogleFonts.dmSans(fontSize: 13, height: 1.6),
                    ),
                  ),
                ),
              ),
            )
          else
            _Btn(label: 'ANALYZE', onTap: () => notifier.analyze()),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HistoryGrid extends ConsumerWidget {
  final List<ScanResult> history;
  const _HistoryGrid({required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          'CAPTURE TO START',
          style: GoogleFonts.dmSans(
              fontSize: 10, letterSpacing: 2, color: AppColors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final item = history[i];
        return GestureDetector(
          onTap: () => _showDetail(context, item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: item.imagePath != null
                          ? (kIsWeb
                              ? Image.network(item.imagePath!, fit: BoxFit.cover)
                              : Image.file(File(item.imagePath!), fit: BoxFit.cover))
                          : const Center(
                              child: Icon(Icons.image_not_supported_outlined)),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => ref.read(_scanStateProvider.notifier).deleteHistory(item.date),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          color: Theme.of(context).cardColor.withOpacity(0.8),
                          child: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d').format(DateTime.parse(item.date)),
                style: GoogleFonts.dmSans(
                    fontSize: 9, fontWeight: FontWeight.bold),
              ),
              Text(
                item.result,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, ScanResult item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                if (item.imagePath != null)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: kIsWeb
                          ? Image.network(item.imagePath!, fit: BoxFit.contain)
                          : Image.file(File(item.imagePath!),
                              fit: BoxFit.contain),
                    ),
                  ),
                const SizedBox(height: 24),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMMM d, h:mm a')
                              .format(DateTime.parse(item.date)),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        MarkdownBody(
                          data: item.result,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(ctx))
                              .copyWith(
                            p: GoogleFonts.dmSans(fontSize: 14, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback? onCamera;
  const _BottomControls({required this.onGallery, this.onCamera});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconBtn(icon: Icons.photo_library_outlined, onTap: onGallery),
          const SizedBox(width: 40),
          _IconBtn(
              icon: Icons.camera_alt_outlined, onTap: onCamera, large: true),
          const SizedBox(width: 40),
          const SizedBox(width: 48), // Padding symmetry
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool large;
  const _IconBtn({required this.icon, this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 72.0 : 48.0;
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
          child: Icon(icon, color: AppColors.accent, size: large ? 28 : 20),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.onTap});

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
