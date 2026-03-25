import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/services/model_download_service.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() =>
      _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  final ModelDownloadService _downloadService = ModelDownloadService();
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAndStartDownload();
  }

  Future<void> _checkAndStartDownload() async {
    final isDownloaded = await _downloadService.isModelDownloaded();
    if (isDownloaded) {
      final path = await _downloadService.getModelPath();
      if (mounted) {
        ref.read(authProvider.notifier).setModelDownloaded(path);
      }
      return;
    }

    _startRealDownload();
  }

  Future<void> _startRealDownload() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      final path = await _downloadService.downloadModel(
        onProgress: (progress) {
          if (mounted) {
            ref.read(authProvider.notifier).updateDownloadProgress(progress);
          }
        },
      );
      if (mounted) {
        ref.read(authProvider.notifier).setModelDownloaded(path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Download failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final progress = authState.downloadProgress;
    final percentage = (progress * 100).round();
    final isDone = authState.isModelDownloaded;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Logotype DL/OA/D style
              _DlLogotype(),

              const Spacer(),

              // Main label
              Text(
                'Preparing your\nmodel',
                style: GoogleFonts.dmSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w200,
                  color: AppColors.text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'QWEN3-VL-2B-INSTRUCT',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 40),

              // Progress track
              LayoutBuilder(builder: (context, constraints) {
                return Stack(
                  children: [
                    // Background track
                    Container(
                      height: 1,
                      width: constraints.maxWidth,
                      color: AppColors.divider,
                    ),
                    // Fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      height: 1,
                      width: constraints.maxWidth * progress,
                      color: AppColors.accent,
                    ),
                  ],
                );
              }),

              const SizedBox(height: 20),

              // Percentage
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$percentage',
                    style: GoogleFonts.dmSans(
                      fontSize: 72,
                      fontWeight: FontWeight.w100,
                      color: AppColors.text,
                      height: 1.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '%',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: AppColors.grey,
                      ),
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.red.shade700,
                  ),
                ),
                TextButton(
                  onPressed: _startRealDownload,
                  child: const Text('RETRY'),
                ),
              ],

              if (isDone) ...[
                const SizedBox(height: 8),
                Text(
                  'Model ready.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.accent,
                    letterSpacing: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

class _DlLogotype extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.accent,
      letterSpacing: 2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('DL', style: style),
        Text('OA', style: style),
        Text('D', style: style),
      ],
    );
  }
}
