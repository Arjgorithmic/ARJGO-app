import 'package:arjgo/core/providers/llama_server_provider.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

final _shellIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _routes = ['/home', '/scan', '/chat', '/traits', '/finance'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_shellIndexProvider);
    final serverState = ref.watch(llamaServerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          child,
          if (serverState.isStarting)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 1, color: AppColors.white),
                    const SizedBox(height: 16),
                    Text(
                      'STARTING LOCAL BRAIN...',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (serverState.error != null && !serverState.isRunning)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.withOpacity(0.9),
                child: Text(
                  'BRAIN ERROR: ${serverState.error}',
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _ArjgoBottomNav(
        currentIndex: index,
        onTap: (i) {
          ref.read(_shellIndexProvider.notifier).state = i;
          context.go(_routes[i]);
        },
      ),
    );
  }
}

class _ArjgoBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _ArjgoBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 75 + safeBottom,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              _buildNavItem(context, 0, 'HOME', Icons.home_outlined, Icons.home),
              _buildScanPlaceholder(), // Second position
              _buildNavItem(context, 2, 'CHAT', Icons.chat_bubble_outline, Icons.chat_bubble),
              _buildNavItem(context, 3, 'TRAITS', Icons.auto_awesome_outlined, Icons.auto_awesome),
              _buildNavItem(context, 4, 'FINANCE', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
            ],
          ),
          Positioned(
            top: -20,
            left: MediaQuery.of(context).size.width / 5 * 1,
            width: MediaQuery.of(context).size.width / 5,
            child: _buildScanButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String label, IconData icon, IconData activeIcon) {
    final isActive = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 20,
              color: isActive ? AppColors.accent : (isDark ? AppColors.grey.withOpacity(0.8) : AppColors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 8,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.accent : (isDark ? AppColors.grey.withOpacity(0.8) : AppColors.grey),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanPlaceholder() {
    return const Expanded(child: SizedBox.shrink());
  }

  Widget _buildScanButton(BuildContext context) {
    final isActive = currentIndex == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onTap(1),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Theme.of(context).cardColor,
                width: 4,
              ),
            ),
            child: const Icon(
              Icons.radio_button_unchecked,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SCAN',
            style: GoogleFonts.dmSans(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
