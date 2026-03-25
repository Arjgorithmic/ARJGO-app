import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top illustration / logo area
                Expanded(
                  flex: 4,
                  child: Center(
                    child: _SplashIllustration(),
                  ),
                ),

                // Brand & tagline
                Center(child: ArjgoLogoInline(fontSize: 22)),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Your skills, seen clearly.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: AppColors.grey,
                      letterSpacing: 0.3,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Fields
                ArjgoTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                ArjgoTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  obscureText: true,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.red.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Login button
                SizedBox(
                  width: double.infinity,
                  child: _loading
                      ? const Center(child: _MinimalLoader())
                      : GestureDetector(
                          onTap: _login,
                          child: Text(
                            'SIGN IN',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // Register link
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/register'),
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        letterSpacing: 0.3,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.divider,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Minimal botanical illustration (SVG-style drawn in Canvas) ──────────────
class _SplashIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _BotanicalPainter(),
    );
  }
}

class _BotanicalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.text.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.text.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Concentric ellipses — organic leaf shapes
    for (int i = 1; i <= 5; i++) {
      final rx = 20.0 + i * 16;
      final ry = 30.0 + i * 22;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy + 10),
        width: rx * 2,
        height: ry * 2,
      );
      canvas.save();
      canvas.translate(cx, cy + 10);
      canvas.rotate(i * 0.25);
      canvas.translate(-cx, -(cy + 10));
      if (i % 2 == 0) {
        canvas.drawOval(rect, paint);
      }
      canvas.drawOval(rect, strokePaint);
      canvas.restore();
    }

    // Stem line
    final stemPaint = Paint()
      ..color = AppColors.text.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(cx, cy + 80)
      ..cubicTo(cx - 20, cy + 40, cx + 20, cy - 20, cx, cy - 60);
    canvas.drawPath(path, stemPaint);

    // Small circle center
    canvas.drawCircle(
      Offset(cx, cy + 10),
      6,
      Paint()
        ..color = AppColors.accent.withOpacity(0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy + 10),
      6,
      Paint()
        ..color = AppColors.accent.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MinimalLoader extends StatelessWidget {
  const _MinimalLoader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      width: 16,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: AppColors.accent,
      ),
    );
  }
}
