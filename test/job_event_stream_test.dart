import 'dart:async';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_service_app/services/job_event_stream.dart';

/// Serves `GET /api/events/stream` like the backend: `ready`, then one `job`
/// event, then drops the connection so the client has to reconnect.
Future<HttpServer> _fakeBackend(List<int> connections) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    connections.add(1);
    req.response.headers.contentType = ContentType('text', 'event-stream');
    req.response.write('retry: 3000\n\nevent: ready\ndata: {}\n\n');
    await req.response.flush();
    req.response.write('event: job\ndata: {"jobId":"j1","status":"PRINTING"}\n\n');
    await req.response.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await req.response.close();
  });
  return server;
}

void main() {
  test('a pushed job event triggers onChange, and a dropped stream reconnects', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final connections = <int>[];
    final server = await _fakeBackend(connections);
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://127.0.0.1:${server.port}/api');

    var changes = 0;
    final stream = JobEventStream(onChange: () => changes++);
    stream.start();

    // First connection: the job event fires onChange once.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(changes, greaterThanOrEqualTo(1));

    // The server closed the stream; after the 1 s backoff the client is back,
    // and the reconnect itself also asks for a resync.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    expect(connections.length, greaterThanOrEqualTo(2));
    expect(changes, greaterThanOrEqualTo(2));

    stream.stop();
    final after = changes;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(changes, after, reason: 'no callbacks after stop()');
    await server.close(force: true);
  });
}
