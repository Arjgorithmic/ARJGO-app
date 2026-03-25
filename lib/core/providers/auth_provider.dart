import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isModelDownloaded;
  final String userName;
  final String userEmail;
  final DateTime? registeredAt;

  const AuthState({
    this.isLoggedIn = false,
    this.isModelDownloaded = false,
    this.userName = '',
    this.userEmail = '',
    this.registeredAt,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isModelDownloaded,
    String? userName,
    String? userEmail,
    DateTime? registeredAt,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isModelDownloaded: isModelDownloaded ?? this.isModelDownloaded,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final isModelDownloaded = prefs.getBool('isModelDownloaded') ?? false;
    final userName = prefs.getString('userName') ?? '';
    final userEmail = prefs.getString('userEmail') ?? '';
    final registeredMs = prefs.getInt('registeredAt');

    state = AuthState(
      isLoggedIn: isLoggedIn,
      isModelDownloaded: isModelDownloaded,
      userName: userName,
      userEmail: userEmail,
      registeredAt: registeredMs != null
          ? DateTime.fromMillisecondsSinceEpoch(registeredMs)
          : null,
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    await prefs.setString('userPassword', password);
    await prefs.setInt('registeredAt', now.millisecondsSinceEpoch);

    state = AuthState(
      isLoggedIn: true,
      isModelDownloaded: false,
      userName: name,
      userEmail: email,
      registeredAt: now,
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString('userEmail') ?? '';
    final storedPassword = prefs.getString('userPassword') ?? '';
    final storedName = prefs.getString('userName') ?? '';
    final isModelDownloaded = prefs.getBool('isModelDownloaded') ?? false;
    final registeredMs = prefs.getInt('registeredAt');

    if (storedEmail == email && storedPassword == password) {
      await prefs.setBool('isLoggedIn', true);
      state = AuthState(
        isLoggedIn: true,
        isModelDownloaded: isModelDownloaded,
        userName: storedName,
        userEmail: email,
        registeredAt: registeredMs != null
            ? DateTime.fromMillisecondsSinceEpoch(registeredMs)
            : null,
      );
    } else {
      throw Exception('Invalid credentials. Please check your email and password.');
    }
  }

  Future<void> setModelDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isModelDownloaded', true);
    state = state.copyWith(isModelDownloaded: true);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    state = state.copyWith(isLoggedIn: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
