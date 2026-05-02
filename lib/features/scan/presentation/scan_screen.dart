import 'dart:io';
import 'package:arjgo/core/models/trait.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/services/trait_engine.dart';
import 'package:arjgo/core/services/trait_storage_service.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/core/providers/trait_provider.dart';
import 'package:arjgo/features/traits/presentation/traits_screen.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// Upgrade 4: Speed Feedback
enum ScanStatus {
  idle,
  queued,
  processing,
  almostDone,
  completed,
  error
}

class ScanTask {
  final String id;
  final String localPath;
  final Trait trait;
  final ScanStatus status;
  final String? result;
  final DateTime createdAt;

  ScanTask({
    required this.id,
    required this.localPath,
    required this.trait,
    this.status = ScanStatus.queued,
    this.result,
    required this.createdAt,
  });

  ScanTask copyWith({ScanStatus? status, String? result}) => ScanTask(
    id: id,
    localPath: localPath,
    trait: trait,
    status: status ?? this.status,
    result: result ?? this.result,
    createdAt: createdAt,
  );
}

class _ScanState {
  final String? tempLocalPath;
  final ScanStatus status;
  final String? result;
  final List<SavedScan> history;
  final List<ScanTask> queue;
  final Trait? selectedTrait;

  const _ScanState({
    this.tempLocalPath,
    this.status = ScanStatus.idle,
    this.result,
    this.history = const [],
    this.queue = const [],
    this.selectedTrait,
  });

  _ScanState copyWith({
    String? tempLocalPath,
    ScanStatus? status,
    String? result,
    List<SavedScan>? history,
    List<ScanTask>? queue,
    Trait? selectedTrait,
    bool clearTrait = false,
    bool clearResult = false,
    bool clearPath = false,
  }) =>
      _ScanState(
        tempLocalPath: clearPath ? null : (tempLocalPath ?? this.tempLocalPath),
        status: status ?? this.status,
        result: clearResult ? null : (result ?? this.result),
        history: history ?? this.history,
        queue: queue ?? this.queue,
        selectedTrait: clearTrait ? null : (selectedTrait ?? this.selectedTrait),
      );

  bool get isLoading => status == ScanStatus.processing || status == ScanStatus.almostDone;
}

class _ScanNotifier extends StateNotifier<_ScanState> {
  final AuthState authState;
  final TraitExecutor _executor = TraitExecutor();
  final TraitStorageService _storageService = TraitStorageService();
  bool _isWorkerRunning = false;

  _ScanNotifier(this.authState) : super(const _ScanState()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await _storageService.getAll();
    state = state.copyWith(history: h);
  }

  void setImage(String path) {
    state = state.copyWith(
        tempLocalPath: path, status: ScanStatus.idle, clearResult: true);
  }

  void selectTrait(Trait? trait) {
    state = state.copyWith(selectedTrait: trait, clearTrait: trait == null);
  }

  Future<void> analyze(List<TraitPipeline<dynamic>> availablePipelines) async {
    if (state.tempLocalPath == null || state.selectedTrait == null) return;
    
    final newTask = ScanTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      localPath: state.tempLocalPath!,
      trait: state.selectedTrait!,
      createdAt: DateTime.now(),
    );

    // Minimize: Clear preview state and add to queue
    state = state.copyWith(
      queue: [...state.queue, newTask],
      clearPath: true,
      clearTrait: true,
      clearResult: true,
      status: ScanStatus.idle,
    );

    _startWorker(availablePipelines);
  }

  Future<void> _startWorker(List<TraitPipeline<dynamic>> pipelines) async {
    if (_isWorkerRunning) return;
    _isWorkerRunning = true;

    while (true) {
      final pending = state.queue.where((t) => t.status == ScanStatus.queued).toList();
      if (pending.isEmpty) break;

      final task = pending.first;
      _updateTaskStatus(task.id, ScanStatus.processing);

      try {
        final imageFile = File(task.localPath);
        if (!await imageFile.exists()) {
          state = state.copyWith(queue: state.queue.where((t) => t.id != task.id).toList());
          continue;
        }

        String resultString;
        dynamic structuredResult;

        final pipeline = pipelines.cast<TraitPipeline?>().firstWhere(
          (p) => p?.id == task.trait.id,
          orElse: () => null,
        );

        if (pipeline != null) {
          structuredResult = await _executor.execute(
            pipeline: pipeline,
            image: imageFile,
            isOnline: authState.isOnlineModel,
            apiKey: authState.openRouterKey,
            isPriority: true,
          );
          resultString = structuredResult.toString();
        } else {
          resultString = await (authState.isOnlineModel 
            ? runCloudInference(task.trait.promptTemplate, imageFile, authState.openRouterKey)
            : runLocalInference(task.trait.promptTemplate, imageFile, isPriority: true));
        }
        
        // Save permanently
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final permanentPath = '${appDir.path}/$fileName';
        await imageFile.copy(permanentPath);

        final savedScan = SavedScan(
          date: DateTime.now().toIso8601String(),
          traitId: task.trait.id,
          traitName: task.trait.name,
          result: resultString,
          imagePath: permanentPath,
          structuredData: structuredResult is! String ? {'type': structuredResult.runtimeType.toString()} : null,
        );

        await _storageService.save(savedScan);
        
        // Success: Refresh history and remove from queue in ONE state update
        final h = await _storageService.getAll();
        state = state.copyWith(
          queue: state.queue.where((t) => t.id != task.id).toList(),
          history: h,
        );
      } catch (e) {
        debugPrint('ScanWorker: Task ${task.id} failed: $e');
        _updateTaskStatus(task.id, ScanStatus.error, result: 'Error: $e');
        await Future.delayed(const Duration(seconds: 3));
        state = state.copyWith(
          queue: state.queue.where((t) => t.id != task.id).toList(),
        );
      }
    }

    _isWorkerRunning = false;
  }

  void _updateTaskStatus(String id, ScanStatus status, {String? result}) {
    state = state.copyWith(
      queue: state.queue.map((t) => t.id == id ? t.copyWith(status: status, result: result) : t).toList(),
    );
  }

  Future<void> deleteHistory(String date) async {
    await _storageService.delete(date);
    _loadHistory();
  }

  void reset() =>
      state = state.copyWith(clearPath: true, clearResult: true, status: ScanStatus.idle, clearTrait: true);
}

final _scanStateProvider =
    StateNotifierProvider<_ScanNotifier, _ScanState>((ref) {
  final authState = ref.watch(authProvider).state;
  return _ScanNotifier(authState);
});

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  Future<void> _pickImage(ImageSource source, _ScanNotifier notifier) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      notifier.setImage(picked.path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_scanStateProvider);
    final notifier = ref.read(_scanStateProvider.notifier);
    final isModelConfigured = ref.watch(authProvider).state.isModelConfigured;

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
                  : _HistoryGrid(history: state.history, queue: state.queue),
            ),
            if (state.tempLocalPath == null)
              _BottomControls(
                onGallery: () => _pickImage(ImageSource.gallery, notifier),
                onCamera: isModelConfigured
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
    final traitsAsync = ref.watch(traitsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.file(File(state.tempLocalPath!),
                  fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 16),

          if (state.result == null && !state.isLoading) ...[
            const SizedBox(height: 12),
            Text(
              'SELECT TRAIT',
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
              child: traitsAsync.when(
                data: (traits) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: traits.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final t = traits[i];
                    final isSelected = state.selectedTrait?.id == t.id;
                    return GestureDetector(
                      onTap: () => notifier.selectTrait(isSelected ? null : t),
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
                          t.name.toUpperCase(),
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
            const SizedBox(height: 12),
            _Btn(
              label: 'DISCARD PHOTO', 
              onTap: () => notifier.reset(),
            ),
          ],

          const SizedBox(height: 16),
          if (state.isLoading)
            Column(
              children: [
                const Center(child: CircularProgressIndicator(strokeWidth: 1)),
                const SizedBox(height: 16),
                Text(
                  state.status == ScanStatus.processing ? "Analyzing..." : "Almost done...",
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey,
                    letterSpacing: 1,
                  ),
                ),
              ],
            )
          else if (state.result != null || state.status == ScanStatus.error)
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(
                    color: state.status == ScanStatus.error 
                        ? Colors.red.withOpacity(0.3) 
                        : AppColors.divider
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: state.status == ScanStatus.error
                          ? Column(
                              children: [
                                const SizedBox(height: 32),
                                const Icon(Icons.error_outline, color: Colors.red, size: 24),
                                const SizedBox(height: 16),
                                Text(
                                  'ANALYSIS INTERRUPTED',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  (state.result ?? 'Unknown error').replaceFirst('Error: ', '').replaceFirst('ERROR_INTERNAL: ', ''),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12, 
                                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                GestureDetector(
                                  onTap: () {
                                    final pipelines = ref.read(dynamicTraitsProvider).asData?.value ?? [];
                                    notifier.analyze(pipelines);
                                  },
                                  child: Text(
                                    'TRY AGAIN',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                      letterSpacing: 1.5,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : MarkdownBody(
                              data: state.result!,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                                  .copyWith(
                                p: GoogleFonts.dmSans(fontSize: 13, height: 1.6),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Btn(
                      label: 'BACK TO HISTORY', 
                      onTap: () {
                        debugPrint('ScanScreen: Resetting via button');
                        notifier.reset();
                      }
                    ),
                  ],
                ),
              ),
            )
          else
            _Btn(
              label: 'ANALYZE', 
              onTap: state.selectedTrait == null 
                ? () {} 
                : () {
                    final pipelines = ref.read(dynamicTraitsProvider).asData?.value ?? [];
                    notifier.analyze(pipelines);
                  }
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HistoryGrid extends ConsumerWidget {
  final List<SavedScan> history;
  final List<ScanTask> queue;
  const _HistoryGrid({required this.history, required this.queue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (history.isEmpty && queue.isEmpty) {
      return Center(
        child: Text(
          'CAPTURE TO START',
          style: GoogleFonts.dmSans(
              fontSize: 10, letterSpacing: 2, color: AppColors.grey),
        ),
      );
    }

    final totalCount = history.length + queue.length;

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: totalCount,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, i) {
        if (i < queue.length) {
          return SizedBox(
            height: 200,
            child: _QueueCard(task: queue[i]),
          );
        }
        
        final item = history[i - queue.length];
        return GestureDetector(
          onTap: () => _showDetail(context, item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: AppColors.divider),
                ),
                child: Stack(
                  children: [
                    Image.file(File(item.imagePath), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => ref.read(_scanStateProvider.notifier).deleteHistory(item.date),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor.withOpacity(0.9),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: AppColors.accent.withOpacity(0.9),
                        child: Text(
                          item.traitName.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM d, yyyy • HH:mm').format(DateTime.parse(item.date)),
                    style: GoogleFonts.dmSans(
                        fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _getPreview(item.result),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 13, 
                  height: 1.5, 
                  color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.divider),
            ],
          ),
        );
      },
    );
  }

  String _getPreview(String text) {
    // Strip markdown headers and bullets
    String stripped = text
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'-\s+'), '')
        .replaceAll('\n', ' ')
        .trim();
    
    if (stripped.length > 120) {
      return '${stripped.substring(0, 117)}...';
    }
    return stripped;
  }

  void _showDetail(BuildContext context, SavedScan item) {
    // (Existing _showDetail logic remains same)
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
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Image.file(File(item.imagePath), fit: BoxFit.contain),
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
                          '${item.traitId.toUpperCase()} • ${DateFormat('MMMM d, h:mm a').format(DateTime.parse(item.date))}',
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
                          selectable: true,
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

class _QueueCard extends StatelessWidget {
  final ScanTask task;
  const _QueueCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Stack(
              children: [
                Opacity(
                  opacity: 0.3,
                  child: Image.file(File(task.localPath), fit: BoxFit.cover, width: double.infinity),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 1, color: AppColors.accent),
                      const SizedBox(height: 12),
                      Text(
                        task.status == ScanStatus.queued ? 'QUEUED' : 'ANALYZING',
                        style: GoogleFonts.dmSans(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'JUST NOW',
          style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold),
        ),
        Text(
          task.trait.name.toUpperCase(),
          maxLines: 1,
          style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.grey),
        ),
      ],
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
