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
  final String? localMMProjPath;

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
    this.localMMProjPath,
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
    String? localMMProjPath,
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
      localMMProjPath: localMMProjPath ?? this.localMMProjPath,
    );
  }
}

class AuthNotifier extends ChangeNotifier {
  AuthState _state = const AuthState();
  AuthState get state => _state;

  AuthNotifier() {
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
        _state = _state.copyWith(isLoggedIn: false, userName: '', userEmail: '');
        notifyListeners();
      }
    });

    _loadLocalFlags();
  }

  Future<void> _loadUser(sb.User user) async {
    final name = user.userMetadata?['full_name'] as String? ?? 'User';
    final email = user.email ?? '';
    final registeredAt = DateTime.tryParse(user.createdAt);

    _state = _state.copyWith(
      isLoggedIn: true,
      userName: name,
      userEmail: email,
      registeredAt: registeredAt,
    );
    notifyListeners();
  }

  Future<void> _loadLocalFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDownloaded = prefs.getBool('isModelDownloaded') ?? false;
      final modelPath = prefs.getString('localModelPath');
      final mmprojPath = prefs.getString('localMMProjPath');
      final isOnline = prefs.getBool('isOnlineModel') ?? false;
      final apiKey = prefs.getString('openRouterKey') ?? '';

      String? actualPath = modelPath;
      String? actualMMPath = mmprojPath;
      bool fileExists = isDownloaded;
      if (!isDownloaded) {
        final modelService = ModelDownloadService();
        fileExists = await modelService.isModelDownloaded();
        actualPath = fileExists ? await modelService.getModelPath() : null;
        actualMMPath = fileExists ? await modelService.getMMProjPath() : null;
      }

      _state = _state.copyWith(
        isModelDownloaded: fileExists,
        localModelPath: actualPath,
        localMMProjPath: actualMMPath,
        isOnlineModel: isOnline,
        openRouterKey: apiKey,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local flags: $e');
    }
  }

  Future<void> setModelOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnlineModel', false);
    _state = _state.copyWith(isOnlineModel: false);
    notifyListeners();
  }

  Future<void> setModelOnline(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnlineModel', true);
    await prefs.setString('openRouterKey', apiKey);
    _state = _state.copyWith(isOnlineModel: true, openRouterKey: apiKey);
    notifyListeners();
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

  Future<void> setModelDownloaded(String path, String mmPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isModelDownloaded', true);
    await prefs.setString('localModelPath', path);
    await prefs.setString('localMMProjPath', mmPath);
    _state = _state.copyWith(
      isModelDownloaded: true, 
      localModelPath: path,
      localMMProjPath: mmPath,
    );
    notifyListeners();
  }

  void updateDownloadProgress(double progress) {
    // Only notify listeners when progress changes by ≥1% to avoid
    // triggering hundreds of GoRouter redirect evaluations per second.
    if ((progress - _state.downloadProgress).abs() >= 0.01 || progress >= 1.0) {
      _state = _state.copyWith(downloadProgress: progress);
      notifyListeners();
    }
  }

  Future<void> updateProfile({required String name, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    _state = _state.copyWith(userName: name, userEmail: email);
    notifyListeners();
  }

  Future<void> logout() async {
    await sb.Supabase.instance.client.auth.signOut();
  }
}

final authProvider = ChangeNotifierProvider<AuthNotifier>(
  (ref) => AuthNotifier(),
);
