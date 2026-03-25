import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';

class ModelSelectionScreen extends ConsumerStatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  ConsumerState<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends ConsumerState<ModelSelectionScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _showApiKeyField = false;

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _selectOffline() {
    ref.read(authProvider.notifier).setModelOffline();
    context.go('/download');
  }

  void _selectOnline() {
    if (_apiKeyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an OpenRouter API key')),
      );
      return;
    }
    ref.read(authProvider.notifier).setModelOnline(_apiKeyCtrl.text.trim());
    // Once configured, the router logic should auto-redirect to /home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              
              Text(
                'Intelligence\nPreference',
                style: GoogleFonts.dmSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w200,
                  color: AppColors.text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'CHOOSE YOUR ENGINE',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey,
                  letterSpacing: 2.5,
                ),
              ),
              
              const Spacer(),

              // Option 1: Offline
              _SelectionCard(
                title: 'OFFLINE',
                subtitle: 'Local Qwen3-VL-2B (4.3GB download)',
                icon: Icons.offline_bolt_outlined,
                onTap: _selectOffline,
              ),
              
              const SizedBox(height: 24),

              // Option 2: Online
              if (!_showApiKeyField) ...[
                _SelectionCard(
                  title: 'CLOUD',
                  subtitle: 'OpenRouter · Qwen3-VL-8B-Instruct',
                  icon: Icons.cloud_outlined,
                  onTap: () => setState(() => _showApiKeyField = true),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPENROUTER ACCESS',
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ArjgoTextField(
                        label: 'API Key',
                        controller: _apiKeyCtrl,
                        obscureText: true,
                        hint: 'sk-or-v1-...',
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showApiKeyField = false),
                            child: Text(
                              'BACK',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _selectOnline,
                            child: Text(
                              'CONNECT',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(icon, color: AppColors.divider, size: 24),
          ],
        ),
      ),
    );
  }
}
