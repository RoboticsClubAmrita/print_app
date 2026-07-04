import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT and user id issued by POST /auth/login so the
/// session survives app restarts.
class SessionStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';

  static Future<void> save({required String token, required String userId}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
  }

  static Future<String?> get token => _storage.read(key: _tokenKey);
  static Future<String?> get userId => _storage.read(key: _userIdKey);

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
  }

  // ---------------- Remember me ----------------

  static const _rememberEmailKey = 'remember_email';
  static const _rememberPasswordKey = 'remember_password';

  static Future<void> saveCredentials({required String email, required String password}) async {
    await _storage.write(key: _rememberEmailKey, value: email);
    await _storage.write(key: _rememberPasswordKey, value: password);
  }

  static Future<String?> get savedEmail => _storage.read(key: _rememberEmailKey);
  static Future<String?> get savedPassword => _storage.read(key: _rememberPasswordKey);

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _rememberEmailKey);
    await _storage.delete(key: _rememberPasswordKey);
  }
}
