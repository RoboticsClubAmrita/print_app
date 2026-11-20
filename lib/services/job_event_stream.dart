import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import 'api_client.dart';

/// Live print-job change feed: the client half of the backend's
/// `GET /api/events/stream` (Server-Sent Events).
///
/// The backend announces every change to one of this user's jobs (printing,
/// ready to collect, collected…) the moment it commits. Each event is only a
/// doorbell: [onChange] refetches through the normal endpoints, which is what
/// fires the local "printing" notification without waiting for the poll.
///
/// Runs while the app is in the foreground; [ShellScreen] stops it on pause
/// and restarts it on resume. A dropped stream reconnects with capped
/// backoff, and the 20 s poll stays on as a safety net.
class JobEventStream {
  JobEventStream({required this.onChange});

  /// Called once per burst of events (and after a reconnect, since changes
  /// made while the stream was down were never announced).
  final VoidCallback onChange;

  static const _baseDelay = Duration(seconds: 1);
  static const _maxDelay = Duration(seconds: 30);
  static const _coalesce = Duration(milliseconds: 250);

  http.Client? _client;
  StreamSubscription<String>? _sub;
  Timer? _reconnect;
  Timer? _debounce;
  int _attempt = 0;
  bool _running = false;
  bool _connectedBefore = false;

  void start() {
    if (_running) return;
    _running = true;
    _connect();
  }

  void stop() {
    _running = false;
    _connectedBefore = false;
    _attempt = 0;
    _reconnect?.cancel();
    _debounce?.cancel();
    _closeConnection();
  }

  void _closeConnection() {
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
  }

  void _notify() {
    if (_debounce?.isActive ?? false) return;
    _debounce = Timer(_coalesce, () {
      if (_running) onChange();
    });
  }

  void _scheduleReconnect() {
    _closeConnection();
    if (!_running || (_reconnect?.isActive ?? false)) return;
    final ms = _baseDelay.inMilliseconds * (1 << _attempt.clamp(0, 5));
    _attempt++;
    _reconnect = Timer(
      Duration(milliseconds: ms.clamp(0, _maxDelay.inMilliseconds)),
      _connect,
    );
  }

  Future<void> _connect() async {
    if (!_running || _client != null) return;
    final client = http.Client();
    _client = client;
    try {
      final req = http.Request('GET', Uri.parse('${Env.apiBaseUrl}/events/stream'))
        ..headers.addAll(await ApiClient.authHeaders())
        ..headers['Accept'] = 'text/event-stream';
      final res = await client.send(req);
      if (!_running || _client != client) return;

      if (res.statusCode == 401) {
        // Expired access token: rotate it like any other call would. If the
        // session is over, the next API call signs the user out.
        _closeConnection();
        bool ok = false;
        try {
          ok = await ApiClient.refreshSession();
        } catch (_) {}
        if (ok) _scheduleReconnect();
        return;
      }
      if (res.statusCode != 200) {
        _scheduleReconnect();
        return;
      }

      if (_connectedBefore) _notify();
      _connectedBefore = true;

      final buffer = StringBuffer();
      _sub = res.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.isEmpty) {
            _handleBlock(buffer.toString());
            buffer.clear();
          } else {
            buffer.writeln(line);
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Job event stream failed: $e');
      if (_client == client) _scheduleReconnect();
    }
  }

  void _handleBlock(String block) {
    var name = 'message';
    for (final line in const LineSplitter().convert(block)) {
      if (line.startsWith('event:')) name = line.substring(6).trim();
    }
    if (name == 'ready') {
      _attempt = 0; // healthy connection: reset the backoff
    } else if (name == 'job') {
      _notify();
    }
  }
}
