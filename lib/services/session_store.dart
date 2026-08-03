import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT and user id issued by POST /auth/login so the
/// session survives app restarts, plus the "remember me" preference and
/// the one-time onboarding flag.
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

  /// Clears every piece of stored *authentication* data (token, user id and
  /// the remember-me preference). Called on logout and on a failed restore.
  /// The onboarding flag is intentionally left untouched — it is not auth
  /// data and should not reappear after a logout.
  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await clearRemember();
  }

  // ---------------- Remember me ----------------
  //
  // We deliberately do NOT persist the raw password. "Remember me" keeps the
  // secure JWT session alive across restarts (gated by [rememberMe]) and only
  // remembers the email address to pre-fill the login form.

  static const _rememberFlagKey = 'remember_me';
  static const _rememberEmailKey = 'remember_email';

  /// Records the remember-me choice at login time. When [remember] is false
  /// the saved email is cleared so the next launch starts clean.
  static Future<void> setRemember({required bool remember, String? email}) async {
    await _storage.write(key: _rememberFlagKey, value: remember ? 'true' : 'false');
    if (remember && email != null) {
      await _storage.write(key: _rememberEmailKey, value: email);
    } else {
      await _storage.delete(key: _rememberEmailKey);
    }
  }

  static Future<bool> get rememberMe async =>
      (await _storage.read(key: _rememberFlagKey)) == 'true';

  static Future<String?> get savedEmail => _storage.read(key: _rememberEmailKey);

  static Future<void> clearRemember() async {
    await _storage.delete(key: _rememberFlagKey);
    await _storage.delete(key: _rememberEmailKey);
  }

  // ---------------- Feature tours (arrow coach marks), one flag per tab -----

  /// True once the given tab's first-run coach-mark tour has been shown.
  /// Checked from each tab right after it becomes visible for the first
  /// time — never re-shown afterwards, even across logouts.
  static Future<bool> seenTour(String tourKey) async =>
      (await _storage.read(key: 'seen_tour_$tourKey')) == 'true';

  static Future<void> markTourSeen(String tourKey) =>
      _storage.write(key: 'seen_tour_$tourKey', value: 'true');
}