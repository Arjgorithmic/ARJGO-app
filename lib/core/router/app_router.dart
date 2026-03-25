import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/features/auth/presentation/login_screen.dart';
import 'package:arjgo/features/auth/presentation/register_screen.dart';
import 'package:arjgo/features/model_download/presentation/model_download_screen.dart';
import 'package:arjgo/features/shell/presentation/main_shell.dart';
import 'package:arjgo/features/home/presentation/home_screen.dart';
import 'package:arjgo/features/scan/presentation/scan_screen.dart';
import 'package:arjgo/features/skills/presentation/skills_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isModelDownloaded = authState.isModelDownloaded;
      final loc = state.uri.toString();

      if (!isLoggedIn) {
        if (loc != '/login' && loc != '/register') return '/login';
        return null;
      }

      if (!isModelDownloaded) {
        if (loc != '/download') return '/download';
        return null;
      }

      if (loc == '/login' || loc == '/register' || loc == '/download') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/download', builder: (_, __) => const ModelDownloadScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
          GoRoute(path: '/skills', builder: (_, __) => const SkillsScreen()),
        ],
      ),
      GoRoute(path: '/', redirect: (_, __) => '/login'),
    ],
  );
});
