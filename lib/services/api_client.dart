import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/env.dart';
import 'session_store.dart';

/// Maps a filename extension to the mimetype the backend's multer
/// fileFilter accepts (see print_backend/utils/uploadHelper.js).
MediaType _mimeTypeFor(String filename) {
  final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'pdf' => MediaType('application', 'pdf'),
    'doc' => MediaType('application', 'msword'),
    'docx' => MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
    'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
    'png' => MediaType('image', 'png'),
    _ => MediaType('application', 'octet-stream'),
  };
}

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
  static Uri _u(String path) => Uri.parse('${Env.apiBaseUrl}$path');

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await SessionStore.token;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _unwrap(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (${res.statusCode})');
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
    return body; // { message, token, userId }
  }

  static Future<String> registerUser({
    required String collegeId,
    required String name,
    required String email,
    required String phone,
    required String password,
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
    final res = await http.get(_u('/users/$userId'), headers: await _headers());
    return _unwrap(res) as Map<String, dynamic>;
  }

  // ---------------- Files ----------------

  static Future<Map<String, dynamic>> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String userId,
  }) async {
    final req = http.MultipartRequest('POST', _u('/files/upload'));
    req.headers.addAll(await _headers(json: false));
    req.fields['userId'] = userId;
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: _mimeTypeFor(filename),
    ));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _unwrap(res) as Map<String, dynamic>;
  }

  // ---------------- Jobs ----------------

  static Future<Map<String, dynamic>> createJob({
    required String userId,
    required String fileId,
    required String printSide, // SINGLE | DOUBLE
    required int copies,
    required int totalPagesToPrint,
    String? locationId,
  }) async {
    final res = await http.post(
      _u('/jobs/create'),
      headers: await _headers(),
      body: jsonEncode({
        'userId': userId,
        'fileId': fileId,
        'printSide': printSide,
        'copies': copies,
        'totalPagesToPrint': totalPagesToPrint,
        if (locationId != null) 'locationId': locationId,
      }),
    );
    return _unwrap(res) as Map<String, dynamic>; // { jobId, referenceId }
  }

  static Future<Map<String, dynamic>> getJobById(String jobId) async {
    final res = await http.get(_u('/jobs/$jobId'), headers: await _headers());
    return _unwrap(res) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getJobsByUser(String userId) async {
    final res = await http.get(_u('/jobs/user/$userId?limit=100'), headers: await _headers());
    final data = _unwrap(res) as Map<String, dynamic>;
    return data['jobs'] as List<dynamic>;
  }

  static Future<void> cancelJob(String jobId, {String? reason}) async {
    final res = await http.patch(
      _u('/jobs/cancel'),
      headers: await _headers(),
      body: jsonEncode({'jobId': jobId, if (reason != null) 'reason': reason}),
    );
    _unwrap(res);
  }

  static Future<String> requestCollect(String jobId) async {
    final res = await http.post(
      _u('/jobs/collect/request'),
      headers: await _headers(),
      body: jsonEncode({'jobId': jobId}),
    );
    final data = _unwrap(res) as Map<String, dynamic>;
    return (data['email'] ?? '').toString();
  }

  /// Returns the name of the stack the collected material was sitting in.
  static Future<String> verifyCollect(String jobId, String otp) async {
    final res = await http.post(
      _u('/jobs/collect/verify'),
      headers: await _headers(),
      body: jsonEncode({'jobId': jobId, 'otp': otp}),
    );
    final data = _unwrap(res) as Map<String, dynamic>;
    return (data['stackName'] ?? '').toString();
  }

  // ---------------- Hardware / Locations ----------------

  static Future<List<dynamic>> getLocations() async {
    final res = await http.get(_u('/hardware/locations'), headers: await _headers());
    return _unwrap(res) as List<dynamic>;
  }

  // ---------------- Pricing ----------------

  static Future<num> pricingLookup({
    required String size, // A2 | A3 | A4
    required String type, // colour | bw
    required String side, // single | double
  }) async {
    final res = await http.get(
      _u('/pricing/lookup?size=$size&type=$type&side=$side'),
      headers: await _headers(),
    );
    final data = _unwrap(res) as Map<String, dynamic>;
    return data['price'] as num;
  }

  static Future<List<dynamic>> getAllPricing() async {
    final res = await http.get(_u('/pricing/all'), headers: await _headers());
    final data = _unwrap(res) as Map<String, dynamic>;
    return data['prices'] as List<dynamic>;
  }

  // ---------------- Payments (Razorpay) ----------------

  static Future<Map<String, dynamic>> createPaymentOrder(String jobId) async {
    final res = await http.post(
      _u('/payments/create-order'),
      headers: await _headers(),
      body: jsonEncode({'jobId': jobId}),
    );
    return _unwrap(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await http.post(
      _u('/payments/verify'),
      headers: await _headers(),
      body: jsonEncode({
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      }),
    );
    return _unwrap(res) as Map<String, dynamic>;
  }
}
