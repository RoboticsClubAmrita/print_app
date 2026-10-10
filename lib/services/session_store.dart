import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session issued by POST /auth/login — the short-lived access
/// token, the rotating refresh token and the user id — so the session
/// survives app restarts, plus the "remember me" preference and the
/// one-time onboarding flag.
class SessionStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _refreshTokenKey = 'refresh_token';

  static Future<void> save({
    required String token,
    required String userId,
    String? refreshToken,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  /// Stores the pair returned by POST /auth/refresh. The old refresh token
  /// is dead the moment the server rotates it, so both are replaced together.
  static Future<void> saveTokens({required String token, required String refreshToken}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<String?> get token => _storage.read(key: _tokenKey);
  static Future<String?> get userId => _storage.read(key: _userIdKey);
  static Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  /// Clears every piece of stored *authentication* data (both tokens, user id
  /// and the remember-me preference). Called on logout and on a failed restore.
  /// The onboarding flag is intentionally left untouched — it is not auth
  /// data and should not reappear after a logout.
  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _refreshTokenKey);
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

  /// Keyed per account, not per device: a shared handset would otherwise let
  /// the first person's walkthrough hide it from everyone who signs in after.
  /// Falls back to the old device-wide key when no user id is supplied.
  static String _tourKey(String tourKey, String? userId) =>
      (userId == null || userId.isEmpty)
          ? 'seen_tour_$tourKey'
          : 'seen_tour_${tourKey}_$userId';

  /// True once this account's first-run coach-mark tour has been shown.
  /// Checked right after the tab becomes visible for the first time — never
  /// re-shown to that account afterwards, even across logouts.
  static Future<bool> seenTour(String tourKey, {String? userId}) async {
    if (await _storage.read(key: _tourKey(tourKey, userId)) == 'true') {
      return true;
    }

    // One-time migration off the old device-wide key: whoever is signed in
    // when this first runs is the person who dismissed it, so credit them
    // and retire the key. Every other account still gets its own first run.
    final legacy = await _storage.read(key: 'seen_tour_$tourKey');
    if (legacy == 'true' && userId != null && userId.isNotEmpty) {
      await _storage.write(key: _tourKey(tourKey, userId), value: 'true');
      await _storage.delete(key: 'seen_tour_$tourKey');
      return true;
    }

    return false;
  }

  static Future<void> markTourSeen(String tourKey, {String? userId}) =>
      _storage.write(key: _tourKey(tourKey, userId), value: 'true');
}