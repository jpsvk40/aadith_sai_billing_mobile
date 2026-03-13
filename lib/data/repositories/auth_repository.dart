import '../network/api_client.dart';
import '../models/auth_user_model.dart';
import '../local/secure_storage.dart';
import '../../core/constants/api_constants.dart';

class AuthRepository {
  final ApiClient _client;
  AuthRepository(this._client);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _client.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
    final token = data['token'] as String;
    await SecureStorage.saveToken(token);
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    return {'token': token, 'user': user};
  }

  Future<AuthUser> getMe() async {
    final data = await _client.get(ApiConstants.me);
    return AuthUser.fromJson(data['user'] ?? data);
  }

  Future<void> forgotPassword(String email) async {
    await _client.post(ApiConstants.forgotPassword, data: {'email': email});
  }

  Future<void> resetPassword(String token, String password) async {
    await _client.post(ApiConstants.resetPassword, data: {
      'token': token,
      'password': password,
    });
  }

  Future<void> logout() async {
    await SecureStorage.deleteToken();
  }
}
