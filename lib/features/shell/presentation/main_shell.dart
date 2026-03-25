import 'package:arjgo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _shellIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _routes = ['/home', '/scan', '/skills'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_shellIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) {
            ref.read(_shellIndexProvider.notifier).state = i;
            context.go(_routes[i]);
          },
          items: const [
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.home_outlined),
              activeIcon: _NavIcon(icon: Icons.home, isActive: true),
              label: 'HOME',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.radio_button_unchecked_outlined),
              activeIcon: _NavIcon(icon: Icons.radio_button_unchecked_outlined, isActive: true),
              label: 'SCAN',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.segment_outlined),
              activeIcon: _NavIcon(icon: Icons.segment, isActive: true),
              label: 'SKILLS',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  const _NavIcon({required this.icon, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 20, color: isActive ? AppColors.accent : AppColors.grey);
  }
}
