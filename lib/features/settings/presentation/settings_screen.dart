import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/providers/theme_provider.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _apiKeyCtrl;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _nameCtrl = TextEditingController(text: auth.userName);
    _emailCtrl = TextEditingController(text: auth.userEmail);
    _apiKeyCtrl = TextEditingController(text: auth.openRouterKey);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    ref.read(authProvider.notifier).updateProfile(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
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
                  onTap: () => ref.read(authProvider.notifier).setModelOffline(),
                ),
                const SizedBox(width: 12),
                _PreferenceTab(
                  label: 'CLOUD',
                  isActive: auth.isOnlineModel,
                  onTap: () => ref.read(authProvider.notifier).setModelOnline(auth.openRouterKey),
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
                    ref.read(authProvider.notifier).setModelOnline(_apiKeyCtrl.text);
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
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
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
