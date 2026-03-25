import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final joinDate = auth.registeredAt != null
        ? DateFormat('d MMM yyyy').format(auth.registeredAt!)
        : '—';
    final initials = auth.userName.isNotEmpty
        ? auth.userName
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : 'AR';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ArjgoLogo(),
                  GestureDetector(
                    onTap: () => _showMenu(context, ref),
                    child: Container(
                      width: 32,
                      height: 32,
                      color: AppColors.accent,
                      child: const Icon(
                        Icons.menu,
                        color: AppColors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // User name
              Text(
                auth.userName.isEmpty ? 'Welcome' : auth.userName,
                style: GoogleFonts.dmSans(
                  fontSize: 40,
                  fontWeight: FontWeight.w200,
                  color: AppColors.text,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),

              // Metadata
              Text(
                auth.userEmail.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppColors.grey,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'JOINED ${joinDate.toUpperCase()}',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppColors.grey,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Model status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: auth.isModelConfigured
                    ? AppColors.accent.withOpacity(0.06)
                    : AppColors.grey.withOpacity(0.06),
                child: Text(
                  auth.isModelConfigured 
                      ? (auth.isOnlineModel ? 'MODEL: CLOUD' : 'MODEL: LOCAL')
                      : 'MODEL LOADING…',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: auth.isModelConfigured
                        ? AppColors.accent
                        : AppColors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Avatar footer
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    color: AppColors.accent,
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.userName,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        auth.userEmail,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: AppColors.grey,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MORE',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.grey,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
              child: Text(
                'Settings',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
              child: Text(
                'Sign out',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
