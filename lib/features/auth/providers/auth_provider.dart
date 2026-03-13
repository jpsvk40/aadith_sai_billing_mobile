import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/network/api_client.dart';
import '../../../data/local/secure_storage.dart';
import '../../../data/local/cache_storage.dart';
import 'dart:convert';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, AuthUser? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  late AuthRepository _repo;

  AuthNotifier() : super(const AuthState()) {
    _initClient();
  }

  void _initClient() {
    final client = ApiClient.getInstance(onUnauthorized: _handleUnauthorized);
    _repo = AuthRepository(client);
  }

  void _handleUnauthorized() {
    logout();
  }

  Future<void> checkSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }
      // Try restoring from cache first
      final cached = CacheStorage.getString('auth_user');
      if (cached != null) {
        final user = AuthUser.fromJson(jsonDecode(cached));
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
      // Then refresh from API
      final user = await _repo.getMe();
      await CacheStorage.setString('auth_user', jsonEncode(user.toJson()));
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      await SecureStorage.deleteToken();
      await CacheStorage.clear();
      state = AuthState(status: AuthStatus.unauthenticated, error: e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _repo.login(email, password);
      final user = result['user'] as AuthUser;
      await CacheStorage.setString('auth_user', jsonEncode(user.toJson()));
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    await CacheStorage.clear();
    ApiClient.reset();
    _initClient();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
