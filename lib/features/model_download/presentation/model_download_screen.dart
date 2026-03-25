import 'dart:async';
import 'package:arjgo/core/providers/auth_provider.dart';
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
  double _progress = 0.0;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSimulatedDownload();
  }

  void _startSimulatedDownload() {
    // Simulate a realistic download: fast at start, slower in middle, quick at end
    const totalMs = 12000; // 12s total
    const tickMs = 80;
    final ticks = totalMs ~/ tickMs;
    int currentTick = 0;

    _timer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      currentTick++;
      final frac = currentTick / ticks;
      // Ease-in-out-like curve
      final eased = frac < 0.5
          ? 2 * frac * frac
          : 1 - 2 * (1 - frac) * (1 - frac);

      setState(() => _progress = (eased).clamp(0.0, 1.0));

      if (currentTick >= ticks) {
        t.cancel();
        setState(() { _progress = 1.0; _done = true; });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            ref.read(authProvider.notifier).setModelDownloaded();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (_progress * 100).round();
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
                      width: constraints.maxWidth * _progress,
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

              if (_done) ...[
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
