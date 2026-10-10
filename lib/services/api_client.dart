import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/env.dart';
import 'session_store.dart';

/// The only content type the backend stores. Everything the user picks is
/// converted to PDF on the device before it is ever offered (see
/// lib/services/document_prep.dart), so there is nothing else to map.
final MediaType _pdfMediaType = MediaType('application', 'pdf');

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper around the print_backend REST API (see print_backend/routes).
/// Every backend envelope is either `{ MESSAGE, DATA }` (most endpoints) or
/// a bespoke shape for /auth/login and /auth/logout.
class ApiClient {
  static VoidCallback? onUnauthorized;

  static Uri _u(String path) => Uri.parse('${Env.apiBaseUrl}$path');

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await SessionStore.token;
    return {
      if (json) 'Content-Type': 'application/json',
      // Tells the backend to hand the refresh token back in the JSON body
      // rather than as a browser cookie, which package:http would discard.
      'X-Client-Type': 'mobile',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// In-flight refresh shared by every request that hit a 401 at once.
  /// Refresh tokens are single-use: rotating the same one twice looks like
  /// theft to the backend, which then revokes the whole session.
  static Future<bool>? _refreshing;

  static const _logoutTimeout = Duration(seconds: 5);

  /// Runs an authenticated request. If the access token has expired (401),
  /// swaps the refresh token for a new pair and replays the request once.
  /// [request] is called again for the replay, so it must build the request
  /// (including `await _headers()`) inside the closure.
  ///
  /// The backend also answers 401 when the caller doesn't own the resource
  /// (requireOwnerOrAdmin), so a 401 that survives a fresh token means
  /// "not yours", not "signed out" — it must not end a working session.
  static Future<http.Response> _send(Future<http.Response> Function() request) async {
    final res = await request();
    if (res.statusCode != 401) return res;
    if (!await _refreshSession()) return res; // session is over: _unwrap signs out
    final replay = await request();
    if (replay.statusCode == 401) {
      throw ApiException('You do not have access to this.');
    }
    return replay;
  }

  static Future<bool> _refreshSession() {
    return _refreshing ??= _rotateTokens().whenComplete(() => _refreshing = null);
  }

  static Future<bool> _rotateTokens() async {
    final refreshToken = await SessionStore.refreshToken;
    if (refreshToken == null) return false;

    final res = await http.post(
      _u('/auth/refresh'),
      headers: {'Content-Type': 'application/json', 'X-Client-Type': 'mobile'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    // Only a 401 means the refresh token is dead. Anything else is the server
    // having a bad moment, which must not cost the user their session.
    if (res.statusCode == 401) return false;
    if (res.statusCode != 200) {
      throw ApiException('Could not reach the server. Please try again.');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final accessToken = body['accessToken'] ?? body['token'];
    final rotated = body['refreshToken'];
    if (accessToken == null || rotated == null) return false;

    // The user logged out while this was in flight: don't resurrect the session.
    if (await SessionStore.refreshToken != refreshToken) return false;

    await SessionStore.saveTokens(token: accessToken.toString(), refreshToken: rotated.toString());
    return true;
  }

  static dynamic _unwrap(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (${res.statusCode})');
    }
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Session expired. Please log in again.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = body['MESSAGE'] ?? body['message'] ?? 'Request failed';
      throw ApiException(msg.toString());
    }
    return body['DATA'] ?? body;
  }

  // ---------------- Auth ----------------

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      _u('/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw ApiException((body['MESSAGE'] ?? body['message'] ?? 'Login failed').toString());
    }
    return body; // { message, accessToken, token, refreshToken, userId }
  }

  /// Ends the session on this device. Local tokens are cleared first so the
  /// user is signed out immediately; the server-side revoke is best-effort —
  /// an unreachable server must not keep someone logged in.
  static Future<void> logout() async {
    final refreshToken = await SessionStore.refreshToken;
    await SessionStore.clear();
    if (refreshToken == null) return;
    try {
      await http
          .post(
            _u('/auth/logout'),
            headers: await _headers(),
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_logoutTimeout);
    } catch (e) {
      debugPrint('Server-side logout failed: $e');
    }
  }

  static Future<String> registerUser({
    required String collegeId,
    required String name,
    required String email,
    required String phone,
    required String password,
    String? role,
  }) async {
    final res = await http.post(
      _u('/users/add'),
      headers: await _headers(),
      body: jsonEncode({
        'collegeId': collegeId,
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        if (role != null) 'role': role,
      }),
    );
    final data = _unwrap(res) as Map<String, dynamic>;
    return data['userId'].toString();
  }

  static Future<void> verifyEmail(String email, String otp) async {
    final res = await http.post(
      _u('/auth/verify-email'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    _unwrap(res);
  }

  static Future<void> resendVerification(String email) async {
    final res = await http.post(
      _u('/auth/resend-verification'),
      headers: await _headers(),
      body: jsonEncode({'email': email}),
    );
    _unwrap(res);
  }

  static Future<void> forgotPassword(String email) async {
    final res = await http.post(
      _u('/auth/forgot-password'),
      headers: await _headers(),
      body: jsonEncode({'email': email}),
    );
    _unwrap(res);
  }

  static Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await http.post(
      _u('/auth/reset-password'),
      headers: await _headers(),
      body: jsonEncode({
        'resetToken': resetToken,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );
    _unwrap(res);
  }

  static Future<Map<String, dynamic>> getUser(String userId) async {
    final res = await _send(
      () async => http.get(_u('/users/$userId'), headers: await _headers()),
    );
    return _unwrap(res) as Map<String, dynamic>;
  }

  // ---------------- Files ----------------
  //
  // A document is declared before payment and handed over after it. The PDF
  // never leaves the device in between — see print_backend/routes/fileRoutes.js
  // for why the two steps are not one.

  /// Declares what we are about to print. No bytes: this is what the order is
  /// priced against while the PDF stays on the phone.
  ///
  /// [totalPages] is counted from the real PDF on this device; the backend
  /// re-counts it from the bytes it eventually receives and rejects a mismatch.
  static Future<Map<String, dynamic>> registerDocument({
    required String userId,
    required String originalName,
    required int fileSize,
    required int totalPages,
    required String checksum,
  }) async {
    final res = await _send(() async => http.post(
        _u('/files/register'),
        headers: await _headers(),
        body: jsonEncode({
          'userId': userId,
          'originalName': originalName,
          'fileSize': fileSize,
          'totalPages': totalPages,
          'checksum': checksum,
        }),
        ));
    return _unwrap(res) as Map<String, dynamic>; // { fileId, metadata }
  }

  /// Hands over the PDF for a registration whose job has been paid for.
  /// Rejected unless the checksum and page count match what was registered.
  static Future<Map<String, dynamic>> uploadDocumentContent({
    required String fileId,
    required Uint8List bytes,
    required String filename,
  }) async {
    // A MultipartRequest can only be sent once, so a replay after a token
    // refresh needs a freshly built one.
    final res = await _send(() async {
      final req = http.MultipartRequest('POST', _u('/files/$fileId/content'));
      req.headers.addAll(await _headers(json: false));
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: _pdfMediaType,
      ));
      return http.Response.fromStream(await req.send());
    });
    return _unwrap(res) as Map<String, dynamic>;
  }

  /// Reads a stored document back. The backend serves it to its owner only,
  /// and only until 24 hours after the printout was collected.
  static Future<Uint8List> fetchDocumentContent(String fileId) async {
    final res = await _send(() async => http.get(
        _u('/files/$fileId/content'),
        headers: await _headers(json: false),
        ));
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Session expired. Please log in again.');
    }
    if (res.statusCode == 410) {
      throw ApiException(
        'This document is no longer available — documents are kept for 24 hours after collection.',
      );
    }
    if (res.statusCode == 403) {
      throw ApiException('This document belongs to another account.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // The error path returns the usual JSON envelope even though the success
      // path is raw PDF bytes.
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        throw ApiException((body['MESSAGE'] ?? 'Could not open the document').toString());
      } on FormatException {
        throw ApiException('Could not open the document (${res.statusCode})');
      }
    }
    return res.bodyBytes;
  }

  // ---------------- Jobs ----------------

  static Future<Map<String, dynamic>> createJob({
    required String userId,
    required String fileId,
    required String printSide, // SINGLE | DOUBLE
    required int copies,
    required int totalPagesToPrint,
    String? locationId,
    List<int>? selectedPages,
    String? scheduleType, // NOW | SCHEDULED
    DateTime? scheduledFor,
    String? idempotencyKey,
  }) async {
    final res = await _send(() async => http.post(
        _u('/jobs/create'),
        headers: await _headers(),
        body: jsonEncode({
          'userId': userId,
          'fileId': fileId,
          'printSide': printSide,
          'copies': copies,
          'totalPagesToPrint': totalPagesToPrint,
          if (locationId != null) 'locationId': locationId,
          if (selectedPages != null) 'selectedPages': selectedPages,
          if (scheduleType != null) 'scheduleType': scheduleType,
          if (scheduledFor != null) 'scheduledFor': scheduledFor.toUtc().toIso8601String(),
          if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        }),
        ));
    return _unwrap(res) as Map<String, dynamic>; // { jobId, referenceId }
  }

  static Future<Map<String, dynamic>> getJobById(String jobId) async {
    final res = await _send(
      () async => http.get(_u('/jobs/$jobId'), headers: await _headers()),
    );
    return _unwrap(res) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getJobsByUser(String userId) async {
    final res = await _send(
      () async => http.get(_u('/jobs/user/$userId?limit=100'), headers: await _headers()),
    );
    final data = _unwrap(res) as Map<String, dynamic>;
    return data['jobs'] as List<dynamic>;
  }

  static Future<void> cancelJob(String jobId, {String? reason}) async {
    final res = await _send(() async => http.patch(
        _u('/jobs/cancel'),
        headers: await _headers(),
        body: jsonEncode({'jobId': jobId, if (reason != null) 'reason': reason}),
        ));
    _unwrap(res);
  }

  static Future<String> requestCollect(String jobId) async {
    final res = await _send(() async => http.post(
        _u('/jobs/collect/request'),
        headers: await _headers(),
        body: jsonEncode({'jobId': jobId}),
        ));
    final data = _unwrap(res) as Map<String, dynamic>;
    return (data['email'] ?? '').toString();
  }

  /// Returns the name of the stack the collected material was sitting in.
  static Future<String> verifyCollect(String jobId, String otp) async {
    final res = await _send(() async => http.post(
        _u('/jobs/collect/verify'),
        headers: await _headers(),
        body: jsonEncode({'jobId': jobId, 'otp': otp}),
        ));
    final data = _unwrap(res) as Map<String, dynamic>;
    return (data['stackName'] ?? '').toString();
  }

  // ---------------- Hardware / Locations ----------------

  static Future<List<dynamic>> getLocations() async {
    final res = await _send(
      () async => http.get(_u('/hardware/locations'), headers: await _headers()),
    );
    return _unwrap(res) as List<dynamic>;
  }

  // ---------------- Pricing ----------------

  static Future<num> pricingLookup({
    required String size, // A2 | A3 | A4
    required String type, // colour | bw
    required String side, // single | double
  }) async {
    final res = await _send(() async => http.get(
        _u('/pricing/lookup?size=$size&type=$type&side=$side'),
        headers: await _headers(),
        ));
    final data = _unwrap(res) as Map<String, dynamic>;
    return data['price'] as num;
  }

  static Future<List<dynamic>> getAllPricing() async {
    final res = await _send(
      () async => http.get(_u('/pricing/all'), headers: await _headers()),
    );
    final data = _unwrap(res) as Map<String, dynamic>;
    return data['prices'] as List<dynamic>;
  }

  // ---------------- Payments (Razorpay) ----------------

  static Future<Map<String, dynamic>> createPaymentOrder(String jobId) async {
    final res = await _send(() async => http.post(
        _u('/payments/create-order'),
        headers: await _headers(),
        body: jsonEncode({'jobId': jobId}),
        ));
    return _unwrap(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await _send(() async => http.post(
        _u('/payments/verify'),
        headers: await _headers(),
        body: jsonEncode({
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        }),
        ));
    return _unwrap(res) as Map<String, dynamic>;
  }

  /// Creates a Razorpay order to pay off outstanding penalties directly,
  /// independent of any print job (Billing tab "Pay Dues").
  static Future<Map<String, dynamic>> createPenaltyOrder(String userId) async {
    final res = await _send(() async => http.post(
        _u('/payments/penalties/create-order'),
        headers: await _headers(),
        body: jsonEncode({'userId': userId}),
        ));
    return _unwrap(res) as Map<String, dynamic>;
  }

  // ---------------- Business Config ----------------

  /// Displayable business rules (penalty rate/free window, scheduling
  /// limits) — read live from the backend so the app never guesses.
  static Future<Map<String, dynamic>> getPublicConfig() async {
    final res = await _send(
      () async => http.get(_u('/config/public'), headers: await _headers()),
    );
    return _unwrap(res) as Map<String, dynamic>;
  }

  // ---------------- Penalties ----------------

  /// Outstanding penalty line items for a user, plus the total owed —
  /// backs the Billing tab's "Outstanding dues" card.
  static Future<({List<dynamic> penalties, num totalOutstanding})> getUserPenalties(
    String userId,
  ) async {
    final res = await _send(
      () async => http.get(_u('/penalties/user/$userId'), headers: await _headers()),
    );
    final data = _unwrap(res) as Map<String, dynamic>;
    return (
      penalties: (data['penalties'] as List<dynamic>?) ?? [],
      totalOutstanding: (data['totalOutstanding'] as num?) ?? 0,
    );
  }

  static Future<void> requestEmailChange({
    required String userId,
    required String newEmail,
  }) async {
    final res = await _send(() async => http.post(
        _u('/users/change-email-request'),
        headers: await _headers(),
        body: jsonEncode({'userId': userId, 'newEmail': newEmail}),
        ));
    _unwrap(res);
  }

  static Future<void> verifyEmailChange({
    required String userId,
    required String otp,
  }) async {
    final res = await _send(() async => http.post(
        _u('/users/change-email-verify'),
        headers: await _headers(),
        body: jsonEncode({'userId': userId, 'otp': otp}),
        ));
    _unwrap(res);
  }

  static Future<void> editUser({
    required String userId,
    String? name,
    String? phone,
  }) async {
    final res = await _send(() async => http.put(
        _u('/users/edit'),
        headers: await _headers(),
        body: jsonEncode({
          'userId': userId,
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
        }),
        ));
    _unwrap(res);
  }
}
