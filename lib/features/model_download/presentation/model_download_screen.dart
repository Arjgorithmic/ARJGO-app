import 'package:arjgo/core/services/notification_service.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/services/model_download_service.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _checkAndStartDownload();
  }

  Future<void> _checkAndStartDownload() async {
    final isDownloaded = await _downloadService.isModelDownloaded();
    if (isDownloaded) {
      final path = await _downloadService.getModelPath();
      final mmPath = await _downloadService.getMMProjPath();
      if (mounted) {
        ref.read(authProvider).setModelDownloaded(path, mmPath);
      }
      return;
    }

    _startRealDownload();
  }

  Future<void> _startRealDownload() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _statusMessage = 'Downloading Core Engine...';
      _error = null;
    });

    try {
      // Phase 1: Binary
      await _downloadService.downloadBinary(
        onProgress: (progress) {
          if (mounted) {
            ref.read(authProvider).updateDownloadProgress(progress / 10); // First 10% for binary
            NotificationService().showDownloadNotification(
              id: 1,
              title: 'Arjgo: Preparing Engine',
              body: '${(progress * 100).toInt()}% complete',
              progress: (progress * 10).toInt(),
            );
          }
        },
      );

      // Phase 2: Model
      setState(() => _statusMessage = 'Downloading Brain (986MB)...');
      final modelPath = await _downloadService.downloadModel(
        onProgress: (progress) {
          if (mounted) {
            // Brain is 10% to 50% of total
            final totalProgress = 0.1 + (progress * 0.4);
            ref.read(authProvider).updateDownloadProgress(totalProgress);
            NotificationService().showDownloadNotification(
              id: 1,
              title: 'Arjgo: Downloading Brain',
              body: '${(progress * 100).toInt()}% complete',
              progress: (totalProgress * 100).toInt(),
            );
          }
        },
      );

      // Phase 3: MMProj (The Eyes)
      setState(() => _statusMessage = 'Downloading Eyes (710MB)...');
      final mmProjPath = await _downloadService.downloadMMProj(
        onProgress: (progress) {
          if (mounted) {
            // Eyes is 50% to 100% of total
            final totalProgress = 0.5 + (progress * 0.5);
            ref.read(authProvider).updateDownloadProgress(totalProgress);
            NotificationService().showDownloadNotification(
              id: 1,
              title: 'Arjgo: Downloading Eyes',
              body: '${(progress * 100).toInt()}% complete',
              progress: (totalProgress * 100).toInt(),
            );
          }
        },
      );

      if (mounted) {
        ref.read(authProvider).setModelDownloaded(modelPath, mmProjPath);
        setState(() => _statusMessage = 'Arjgo is ready.');
        NotificationService().showDownloadNotification(
          id: 1,
          title: 'Arjgo is Ready',
          body: 'Local intelligence engine initialized successfully.',
        );
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

  String _getFriendlyError(String error) {
    if (error.contains('Failed host lookup') || error.contains('SocketException')) {
      return 'NO INTERNET CONNECTION\nCheck your Wi-Fi or Data and try again.';
    }
    if (error.contains('403') || error.contains('Forbidden')) {
      return 'ACCESS DENIED\nHuggingFace may be restricted in your region. Try using a VPN.';
    }
    if (error.contains('404')) {
      return 'FILE NOT FOUND\nThe model link has expired or moved.';
    }
    return 'DOWNLOAD INTERRUPTED\n${error.length > 60 ? error.substring(0, 60) + "..." : error}';
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final progress = authState.downloadProgress;
    final percentageStr = (progress * 100).toStringAsFixed(2);
    final isDone = authState.isModelDownloaded;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Main Logo branding
              const ArjgoLogo(),

              const Spacer(),

              // Main label
              Text(
                'Preparing your\nmodel',
                style: GoogleFonts.dmSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w200,
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.text ,
                  height: 1.15,
                ),
              ),
              Text(
                _statusMessage.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 2.0,
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
                      width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                      color: AppColors.accent,
                    ),
                  ],
                );
              }),

              const SizedBox(height: 20),

              // Percentage with decimals
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    percentageStr,
                    style: GoogleFonts.dmSans(
                      fontSize: 48, // Reduced slightly to fit decimals comfortably
                      fontWeight: FontWeight.w100,
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.text ,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    border: Border.all(color: Colors.red.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'CONNECTION ISSUE',
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getFriendlyError(_error!),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _startRealDownload,
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
                  ),
                ),
              ],

              if (isDone) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(
                      'CONTINUE',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const VibeFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
