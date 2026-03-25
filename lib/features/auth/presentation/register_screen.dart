import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),
                Text(
                  'Create\naccount.',
                  style: GoogleFonts.dmSans(
                    fontSize: 36,
                    fontWeight: FontWeight.w200,
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.text ,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'JOIN ARJGO',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 48),

                ArjgoTextField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                ArjgoTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ArjgoTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Min 6 characters'
                      : null,
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
                ],

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.accent,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _register,
                          child: Text(
                            'GET STARTED',
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
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text(
                      'Already have an account? Sign in',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.grey,
                        letterSpacing: 0.2,
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
