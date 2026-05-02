import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/features/auth/presentation/login_screen.dart';
import 'package:arjgo/features/auth/presentation/register_screen.dart';
import 'package:arjgo/features/model_download/presentation/model_download_screen.dart';
import 'package:arjgo/features/shell/presentation/main_shell.dart';
import 'package:arjgo/features/home/presentation/home_screen.dart';
import 'package:arjgo/features/settings/presentation/settings_screen.dart';
import 'package:arjgo/features/scan/presentation/scan_screen.dart';
import 'package:arjgo/features/traits/presentation/traits_screen.dart';
import 'package:arjgo/features/chat/presentation/chat_screen.dart';
import 'package:arjgo/features/management/presentation/management_screen.dart';
import 'package:arjgo/features/model_selection/presentation/model_selection_screen.dart';
import 'package:arjgo/features/finance/presentation/finance_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(authProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = notifier.state;
      final isLoggedIn = authState.isLoggedIn;
      final isModelConfigured = authState.isModelConfigured;
      final loc = state.uri.toString();

      debugPrint('ROUTER: [Eval] loc=$loc, isLoggedIn=$isLoggedIn, isModelConfigured=$isModelConfigured');

      if (!isLoggedIn) {
        if (loc != '/login' && loc != '/register') return '/login';
        return null;
      }

      // Root redirect for authenticated users
      if (loc == '/') {
        return isModelConfigured ? '/home' : '/selection';
      }

      if (!isModelConfigured) {
        if (loc != '/selection' && loc != '/download') return '/selection';
        return null;
      }

      // If configured, don't allow auth/setup pages
      if (loc == '/login' || loc == '/register' || loc == '/selection' || loc == '/download') {
        debugPrint('ROUTER: [Configured] Redirecting from $loc to /home');
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/selection', builder: (_, __) => const ModelSelectionScreen()),
      GoRoute(path: '/download', builder: (_, __) => const ModelDownloadScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
          GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          GoRoute(path: '/traits', builder: (_, __) => const TraitsScreen()),
          GoRoute(path: '/finance', builder: (_, __) => const FinanceScreen()),
          GoRoute(path: '/management', builder: (_, __) => const ManagementScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
    ],
  );
});
