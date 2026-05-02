import 'package:arjgo/core/router/app_router.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


import 'package:arjgo/core/config/supabase_config.dart'; // Kept for SupabaseConfig.url/anonKey
import 'package:arjgo/core/providers/theme_provider.dart';
import 'package:arjgo/core/services/notification_service.dart';
import 'package:arjgo/core/services/activity_log_service.dart';
import 'package:arjgo/core/services/database_service.dart';
import 'package:arjgo/core/services/vector_service.dart';
import 'package:arjgo/core/services/migration_service.dart';
import 'package:arjgo/core/providers/llama_server_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Arjgo starting...');
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  await Hive.initFlutter();
  await Hive.openBox(ActivityLogService.boxName);
  await Hive.openBox('chat_sessions');
  
  // New Intelligence Services
  await DatabaseService().db;
  await VectorService().init();
  await MigrationService.migrate();
  
  await NotificationService().init();
  debugPrint('Supabase, Hive & Notifications initialized.');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    
    // Ensure the Intelligence Engine starts immediately on launch
    ref.watch(llamaServerProvider);

    return MaterialApp.router(
      title: 'ARJGO',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
    );
  }
}
