import 'package:arjgo/core/services/model_download_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthState {
  final bool isLoggedIn;
  final bool isModelDownloaded;
  final bool isOnlineModel;
  final String openRouterKey;
  final String userName;
  final String userEmail;
  final DateTime? registeredAt;
  final double downloadProgress;
  final String? localModelPath;

  const AuthState({
    this.isLoggedIn = false,
    this.isModelDownloaded = false,
    this.isOnlineModel = false,
    this.openRouterKey = '',
    this.userName = '',
    this.userEmail = '',
    this.registeredAt,
    this.downloadProgress = 0.0,
    this.localModelPath,
  });

  bool get isModelConfigured => isModelDownloaded || (isOnlineModel && openRouterKey.isNotEmpty);

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isModelDownloaded,
    bool? isOnlineModel,
    String? openRouterKey,
    String? userName,
    String? userEmail,
    DateTime? registeredAt,
    double? downloadProgress,
    String? localModelPath,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isModelDownloaded: isModelDownloaded ?? this.isModelDownloaded,
      isOnlineModel: isOnlineModel ?? this.isOnlineModel,
      openRouterKey: openRouterKey ?? this.openRouterKey,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      registeredAt: registeredAt ?? this.registeredAt,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localModelPath: localModelPath ?? this.localModelPath,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() {
    final session = sb.Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _loadUser(session.user);
    }

    sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        _loadUser(user);
      } else {
        state = state.copyWith(isLoggedIn: false, userName: '', userEmail: '');
      }
    });

    _loadLocalFlags();
  }

  Future<void> _loadUser(sb.User user) async {
    final name = user.userMetadata?['full_name'] as String? ?? 'User';
    final email = user.email ?? '';
    final registeredAt = DateTime.tryParse(user.createdAt);

    state = state.copyWith(
      isLoggedIn: true,
      userName: name,
      userEmail: email,
      registeredAt: registeredAt,
    );
  }

  Future<void> _loadLocalFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDownloaded = prefs.getBool('isModelDownloaded') ?? false;
      final modelPath = prefs.getString('localModelPath');
      final isOnline = prefs.getBool('isOnlineModel') ?? false;
      final apiKey = prefs.getString('openRouterKey') ?? '';

      // Also check filesystem directly for robustness (only if not already marked downloaded in prefs)
      String? actualPath = modelPath;
      bool fileExists = isDownloaded;
      if (!isDownloaded) {
        final modelService = ModelDownloadService();
        fileExists = await modelService.isModelDownloaded();
        actualPath = fileExists ? await modelService.getModelPath() : null;
      }

      state = state.copyWith(
        isModelDownloaded: fileExists,
        localModelPath: actualPath,
        isOnlineModel: isOnline,
        openRouterKey: apiKey,
      );
    } catch (e) {
      debugPrint('Error loading local flags: $e');
    }
  }

  Future<void> setModelOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnlineModel', false);
    state = state.copyWith(isOnlineModel: false);
  }

  Future<void> setModelOnline(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnlineModel', true);
    await prefs.setString('openRouterKey', apiKey);
    state = state.copyWith(isOnlineModel: true, openRouterKey: apiKey);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await sb.Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await sb.Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> setModelDownloaded(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isModelDownloaded', true);
    await prefs.setString('localModelPath', path);
    state = state.copyWith(isModelDownloaded: true, localModelPath: path);
  }

  void updateDownloadProgress(double progress) {
    state = state.copyWith(downloadProgress: progress);
  }

  Future<void> updateProfile({required String name, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    state = state.copyWith(userName: name, userEmail: email);
  }

  Future<void> logout() async {
    await sb.Supabase.instance.client.auth.signOut();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
