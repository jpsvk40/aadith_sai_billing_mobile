import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'auth_token';

  // In-memory cache of the token. flutter_secure_storage (encryptedSharedPreferences)
  // can hang or intermittently return null on some emulators; if the auth interceptor
  // reads null mid-session the request goes out unauthenticated -> backend 401 ->
  // forced logout (login loop). Caching in memory makes reads fast + reliable for the
  // life of the process; disk is the source of truth across restarts.
  static String? _cachedToken;

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
    } catch (_) {
      _cachedToken = null;
    }
    return _cachedToken;
  }

  static Future<void> deleteToken() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }

  static Future<void> clearAll() async {
    _cachedToken = null;
    await _storage.deleteAll();
  }
}
