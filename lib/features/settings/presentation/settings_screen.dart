import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/providers/theme_provider.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:arjgo/core/services/notification_service.dart';
import 'package:arjgo/core/services/feedback_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _feedbackCtrl;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider).state;
    _nameCtrl = TextEditingController(text: auth.userName);
    _emailCtrl = TextEditingController(text: auth.userEmail);
    _apiKeyCtrl = TextEditingController(text: auth.openRouterKey);
    _feedbackCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _apiKeyCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    ref.read(authProvider).updateProfile(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  Future<void> _submitFeedback() async {
    if (_feedbackCtrl.text.trim().isEmpty) return;

    try {
      final auth = ref.read(authProvider).state;
      await FeedbackService().submitFeedback(
        name: auth.userName.isNotEmpty ? auth.userName : 'Anonymous',
        email: auth.userEmail.isNotEmpty ? auth.userEmail : 'No Email',
        content: _feedbackCtrl.text.trim(),
      );
      _feedbackCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted. Thank you!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).state;
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permissions Section
            _SectionHeader(title: 'SYSTEM PERMISSIONS'),
            _buildPermissionTile(
              context,
              'NOTIFICATIONS',
              'Required for downloads and reminders.',
              () => NotificationService().requestPermissions(),
            ),
            _buildPermissionTile(
              context,
              'FILE SYSTEM',
              'Required for local model storage.',
              () => NotificationService().requestStoragePermission(),
            ),
            const SizedBox(height: 32),

            // Theme Section
            _SectionHeader(title: 'APPEARANCE'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Dark Mode', style: GoogleFonts.dmSans(fontSize: 15)),
              trailing: Switch(
                value: isDark,
                activeColor: AppColors.accent,
                onChanged: (val) {
                  ref.read(themeProvider.notifier).setTheme(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Model Section
            _SectionHeader(title: 'INTELLIGENCE ENGINE'),
            Row(
              children: [
                _PreferenceTab(
                  label: 'OFFLINE',
                  isActive: !auth.isOnlineModel,
                  onTap: () async {
                    if (!auth.isModelDownloaded) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Theme.of(ctx).cardColor,
                          title: Text('DOWNLOAD REQUIRED', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold)),
                          content: Text('The local model (1.7GB) is not downloaded. Start download now?', style: GoogleFonts.dmSans(fontSize: 12)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('CANCEL', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.grey)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('DOWNLOAD', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref.read(authProvider).setModelOffline();
                        if (mounted) context.push('/download');
                      }
                    } else {
                      ref.read(authProvider).setModelOffline();
                    }
                  },
                ),
                const SizedBox(width: 12),
                _PreferenceTab(
                  label: 'CLOUD',
                  isActive: auth.isOnlineModel,
                  onTap: () => ref.read(authProvider).setModelOnline(auth.openRouterKey),
                ),
              ],
            ),
            if (auth.isOnlineModel) ...[
              const SizedBox(height: 24),
              ArjgoTextField(
                label: 'OpenRouter API Key',
                controller: _apiKeyCtrl,
                obscureText: true,
                hint: 'sk-or-v1-...',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ref.read(authProvider).setModelOnline(_apiKeyCtrl.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API Key updated')),
                    );
                  },
                  child: Text('UPDATE KEY', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Profile Section
            _SectionHeader(title: 'PROFILE'),
            ArjgoTextField(label: 'Full Name', controller: _nameCtrl),
            const SizedBox(height: 16),
            ArjgoTextField(label: 'Email Address', controller: _emailCtrl),
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(
                  'SAVE CHANGES',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            const SizedBox(height: 32),

            // Feedback Section
            _SectionHeader(title: 'FEEDBACK'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HELP US IMPROVE',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackCtrl,
                    maxLines: 4,
                    style: GoogleFonts.dmSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts or report a bug...',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.grey, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'SUBMIT FEEDBACK',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
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
            const SizedBox(height: 32),

            // Creator Section
            _SectionHeader(title: 'THE CREATOR'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arjgorithmic',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The developer behind Arjgo. This project is a personal mission to bring high-performance, privacy-first local intelligence to every pocket.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const VibeFooter(),
          ],
        ),
      ),
    );
  }
}

Widget _buildPermissionTile(BuildContext context, String title, String subtitle, VoidCallback onTap) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      border: Border.all(color: AppColors.divider),
    ),
    child: ListTile(
      title: Text(
        title,
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.grey,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _PreferenceTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PreferenceTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : Colors.transparent,
          border: Border.all(color: isActive ? AppColors.accent : AppColors.divider),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? AppColors.white : AppColors.grey,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
