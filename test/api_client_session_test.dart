import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:print_service_app/services/api_client.dart';
import 'package:print_service_app/services/session_store.dart';

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

/// A fake backend: access token `access-N` is valid only for the latest N,
/// and `/auth/refresh` rotates `refresh-N` → `refresh-(N+1)`.
class FakeBackend {
  int generation = 1;
  bool refreshAllowed = true;

  /// Non-null → /auth/refresh answers with this status (e.g. a 5xx blip).
  int? refreshStatus;

  /// Paths whose owner check fails: the backend answers 401 for these even
  /// with a valid token (requireOwnerOrAdmin → deny).
  final Set<String> foreignPaths = {};

  /// Runs while /auth/refresh is being handled, before it answers.
  Future<void> Function()? onRefresh;
  final List<http.Request> requests = [];

  int countPath(String path) =>
      requests.where((r) => r.url.path.endsWith(path)).length;

  Future<http.Response> handle(http.Request req) async {
    requests.add(req);
    final path = req.url.path;

    if (path.endsWith('/auth/login')) {
      return _json(200, {
        'accessToken': 'access-$generation',
        'token': 'access-$generation',
        'refreshToken': 'refresh-$generation',
        'userId': 'u1',
      });
    }
    if (path.endsWith('/auth/refresh')) {
      if (onRefresh != null) await onRefresh!();
      if (refreshStatus != null) return _json(refreshStatus!, {'MESSAGE': 'boom'});
      final sent = (jsonDecode(req.body) as Map)['refreshToken'];
      if (!refreshAllowed || sent != 'refresh-$generation') {
        return _json(401, {'MESSAGE': 'Unauthorized'});
      }
      generation++;
      return _json(200, {
        'accessToken': 'access-$generation',
        'token': 'access-$generation',
        'refreshToken': 'refresh-$generation',
        'userId': 'u1',
      });
    }
    if (path.endsWith('/auth/logout')) {
      return _json(200, {'message': 'Logged out successfully'});
    }

    if (req.headers['authorization'] != 'Bearer access-$generation' ||
        foreignPaths.any(path.endsWith)) {
      return _json(401, {'MESSAGE': 'Unauthorized'});
    }
    return _json(200, {
      'MESSAGE': 'ok',
      'DATA': {'_id': 'u1', 'name': 'Test'}
    });
  }
}

void main() {
  late FakeBackend backend;
  late MockClient client;

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api');
    FlutterSecureStorage.setMockInitialValues({});
    backend = FakeBackend();
    client = MockClient(backend.handle);
    ApiClient.onUnauthorized = null;
  });

  Future<T> withBackend<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => client);

  test('identifies itself as a mobile client on every request', () async {
    await withBackend(() => ApiClient.login('cb.en.u4cse00000', 'pw'));

    expect(backend.requests.single.headers['x-client-type'], 'mobile');
  });

  test('login response refresh token is persisted to secure storage', () async {
    final res =
        await withBackend(() => ApiClient.login('cb.en.u4cse00000', 'pw'));
    await SessionStore.save(
      token: res['token'].toString(),
      userId: res['userId'].toString(),
      refreshToken: res['refreshToken']?.toString(),
    );

    expect(await SessionStore.refreshToken, 'refresh-1');
  });

  test('an expired access token is refreshed once and the request retried',
      () async {
    // Simulate the 15-minute expiry: the stored access token is rejected,
    // but refresh-1 is still good.
    await SessionStore.save(
        token: 'access-stale', userId: 'u1', refreshToken: 'refresh-1');

    final user = await withBackend(() => ApiClient.getUser('u1'));

    expect(user['name'], 'Test');
    expect(backend.countPath('/auth/refresh'), 1);
    expect(await SessionStore.token, 'access-2');
    expect(await SessionStore.refreshToken, 'refresh-2');
  });

  test('concurrent 401s share a single refresh call', () async {
    await SessionStore.save(
        token: 'access-stale', userId: 'u1', refreshToken: 'refresh-1');

    await withBackend(() => Future.wait([
          ApiClient.getUser('u1'),
          ApiClient.getUser('u1'),
          ApiClient.getUser('u1'),
        ]));

    // A second rotation with the already-used refresh-1 would look like token
    // theft to the backend and revoke the whole session family.
    expect(backend.countPath('/auth/refresh'), 1);
  });

  test('a rejected refresh signs the user out', () async {
    await SessionStore.save(
        token: 'access-stale', userId: 'u1', refreshToken: 'refresh-1');
    backend.refreshAllowed = false;
    var signedOut = false;
    ApiClient.onUnauthorized = () => signedOut = true;

    await expectLater(withBackend(() => ApiClient.getUser('u1')),
        throwsA(isA<ApiException>()));

    expect(signedOut, isTrue);
    expect(backend.countPath('/auth/refresh'), 1);
  });

  test('without a stored refresh token a 401 signs out without calling refresh',
      () async {
    await SessionStore.save(token: 'access-stale', userId: 'u1');
    var signedOut = false;
    ApiClient.onUnauthorized = () => signedOut = true;

    await expectLater(withBackend(() => ApiClient.getUser('u1')),
        throwsA(isA<ApiException>()));

    expect(signedOut, isTrue);
    expect(backend.countPath('/auth/refresh'), 0);
  });

  test('logout revokes the refresh token server-side and clears it locally',
      () async {
    await SessionStore.save(
        token: 'access-1', userId: 'u1', refreshToken: 'refresh-1');

    await withBackend(() => ApiClient.logout());

    final call = backend.requests
        .singleWhere((r) => r.url.path.endsWith('/auth/logout'));
    expect((jsonDecode(call.body) as Map)['refreshToken'], 'refresh-1');
    expect(await SessionStore.refreshToken, isNull);
    expect(await SessionStore.token, isNull);
  });

  test('a 401 that survives a fresh token is an access error, not a sign-out',
      () async {
    await SessionStore.save(
        token: 'access-stale', userId: 'u1', refreshToken: 'refresh-1');
    backend.foreignPaths.add('/jobs/someone-elses-job');
    var signedOut = false;
    ApiClient.onUnauthorized = () => signedOut = true;

    await expectLater(
      withBackend(() => ApiClient.getJobById('someone-elses-job')),
      throwsA(isA<ApiException>()),
    );

    expect(signedOut, isFalse);
    expect(await SessionStore.refreshToken, 'refresh-2');
  });

  test('a server error during refresh keeps the session', () async {
    await SessionStore.save(
        token: 'access-stale', userId: 'u1', refreshToken: 'refresh-1');
    backend.refreshStatus = 503;
    var signedOut = false;
    ApiClient.onUnauthorized = () => signedOut = true;

    await expectLater(
      withBackend(() => ApiClient.getUser('u1')),
      throwsA(isA<ApiException>()),
    );

    expect(signedOut, isFalse);
    expect(await SessionStore.refreshToken, 'refresh-1');
  });

  test('logging out mid-refresh does not bring the session back', () async {
    await SessionStore.save(
        token: 'access-stale', userId: 'u1', refreshToken: 'refresh-1');
    backend.onRefresh = () => SessionStore.clear();

    await expectLater(
      withBackend(() => ApiClient.getUser('u1')),
      throwsA(isA<ApiException>()),
    );

    expect(await SessionStore.token, isNull);
    expect(await SessionStore.refreshToken, isNull);
  });
}
