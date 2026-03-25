import 'package:arjgo/core/router/app_router.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added for Supabase.initialize

import 'package:arjgo/core/config/supabase_config.dart'; // Kept for SupabaseConfig.url/anonKey
import 'package:arjgo/core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Arjgo starting...');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  debugPrint('Supabase initialized.');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'ARJGO',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.white,
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: AppColors.accent),
        dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
        textSelectionTheme:
            const TextSelectionThemeData(cursorColor: AppColors.accent),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: Color(0xFFFFFFFF)),
        dividerTheme: const DividerThemeData(color: Color(0xFF2A2A2A), thickness: 1),
        textSelectionTheme:
            const TextSelectionThemeData(cursorColor: Color(0xFFFFFFFF)),
      ),
    );
  }
}
