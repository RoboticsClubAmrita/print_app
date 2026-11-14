import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:print_service_app/models/print_order.dart';
import 'package:print_service_app/services/api_client.dart';
import 'package:print_service_app/services/session_store.dart';
import 'package:print_service_app/state/app_state.dart';

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> _job(String status) => {
      '_id': 'job-1',
      'referenceId': 'REF-1',
      'fileId': 'file-1',
      'originalName': 'notes.pdf',
      'totalPagesToPrint': 2,
      'status': status,
      'createdAt': DateTime(2026, 11, 14).toIso8601String(),
    };

/// Fake backend speaking the real pending-until-verified signup contract and
/// refusing cancellation once a job is printing.
class FakeBackend {
  final List<http.Request> requests = [];
  String jobStatus = 'QUEUED';

  bool hit(String path) => requests.any((r) => r.url.path.endsWith(path));

  Future<http.Response> handle(http.Request req) async {
    requests.add(req);
    final path = req.url.path;
    final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map;

    if (path.endsWith('/users/add')) {
      return _json(400, {'MESSAGE': 'Self-registration is not available here.'});
    }
    if (path.endsWith('/auth/register/start')) {
      final roll = (body['collegeId'] as String).toLowerCase();
      return _json(200, {
        'MESSAGE': 'Verification code sent',
        'DATA': {'email': '$roll@cb.students.amrita.edu'},
      });
    }
    if (path.endsWith('/auth/register/verify')) {
      if (body['otp'] != '1234') return _json(400, {'MESSAGE': 'Invalid verification code'});
      return _json(200, {
        'message': 'Registration complete',
        'accessToken': 'access-1',
        'token': 'access-1',
        'refreshToken': 'refresh-1',
        'userId': 'u1',
        'user': {'_id': 'u1'},
      });
    }
    if (path.endsWith('/auth/register/resend')) {
      return _json(200, {'MESSAGE': 'sent', 'DATA': {}});
    }
    if (path.endsWith('/users/u1')) {
      return _json(200, {
        'DATA': {'_id': 'u1', 'name': 'Deepa', 'email': 'cb.sc.u4cse1@cb.students.amrita.edu'},
      });
    }
    if (path.endsWith('/jobs/user/u1')) {
      return _json(200, {
        'DATA': {
          'jobs': [_job(jobStatus)],
        },
      });
    }
    if (path.endsWith('/jobs/cancel')) {
      if (jobStatus != 'QUEUED') {
        return _json(400, {
          'MESSAGE': 'Cannot cancel a job with status "$jobStatus". Printing has already started or finished.',
        });
      }
      jobStatus = 'CANCELLED';
      return _json(200, {'MESSAGE': 'Print job cancelled successfully'});
    }
    if (path.endsWith('/penalties/user/u1')) {
      return _json(200, {'DATA': {'penalties': [], 'totalOutstanding': 0}});
    }
    if (path.endsWith('/hardware/locations')) return _json(200, {'DATA': []});
    if (path.endsWith('/config/public')) return _json(200, {'DATA': {}});
    return _json(404, {'MESSAGE': 'not found: $path'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;
  late MockClient client;

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api');
    FlutterSecureStorage.setMockInitialValues({});
    backend = FakeBackend();
    client = MockClient(backend.handle);
  });

  Future<T> withBackend<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => client);

  group('signup', () {
    test('uses the pending-registration flow and returns the derived email', () async {
      await withBackend(() async {
        final state = AppState();
        final result = await state.register(
          name: 'Deepa',
          collegeId: 'cb.sc.u4cse1',
          phone: '9876543210',
          password: 'pass1',
        );

        expect(result.error, isNull);
        expect(result.email, 'cb.sc.u4cse1@cb.students.amrita.edu');
        expect(backend.hit('/auth/register/start'), isTrue);
        expect(backend.hit('/users/add'), isFalse);

        final start = backend.requests.firstWhere((r) => r.url.path.endsWith('/auth/register/start'));
        expect((jsonDecode(start.body) as Map)['collegeId'], 'CB.SC.U4CSE1');
      });
    });

    test('verifying the OTP signs the device in without a separate login', () async {
      await withBackend(() async {
        final state = AppState();
        final error = await state.verifyRegistration('cb.sc.u4cse1', '1234');

        expect(error, isNull);
        expect(state.user?.id, 'u1');
        expect(await SessionStore.token, 'access-1');
        expect(await SessionStore.refreshToken, 'refresh-1');
        expect(backend.hit('/auth/login'), isFalse);
      });
    });

    test('a wrong OTP reports the backend message and stores no session', () async {
      await withBackend(() async {
        final state = AppState();
        final error = await state.verifyRegistration('cb.sc.u4cse1', '0000');

        expect(error, 'Invalid verification code');
        expect(await SessionStore.token, isNull);
      });
    });
  });

  group('cancel', () {
    Future<AppState> signedIn() async {
      final state = AppState();
      expect(await state.verifyRegistration('cb.sc.u4cse1', '1234'), isNull);
      return state;
    }

    test('cancels a queued order and refreshes to CANCELLED', () async {
      await withBackend(() async {
        final state = await signedIn();
        await state.cancelOrder(state.orders.single);
        expect(state.orders.single.status, OrderStatus.cancelled);
      });
    });

    test('a refused cancel still refreshes, so the screen shows PRINTING', () async {
      await withBackend(() async {
        final state = await signedIn();
        final stale = state.orders.single;
        expect(stale.status, OrderStatus.queued);

        // Printing starts on the print side before the next poll.
        backend.jobStatus = 'PRINTING';

        await expectLater(
          state.cancelOrder(stale),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('PRINTING'))),
        );
        expect(state.orders.single.status, OrderStatus.printing);
      });
    });
  });
}
