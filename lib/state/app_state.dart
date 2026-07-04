import 'package:flutter/foundation.dart';

import '../models/print_order.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/session_store.dart';

/// A single entry in the in-app notification history (shown when the
/// bell icon on Home is tapped).
class AppNotification {
  final String title;
  final String body;
  final DateTime time;

  AppNotification({required this.title, required this.body, required this.time});
}

/// Central app state backed by the print_backend REST API.
class AppState extends ChangeNotifier {
  AppUser? user;
  List<PrintOrder> orders = [];
  List<Map<String, dynamic>> locations = [];
  String? selectedLocationId;
  String? selectedLocationName;
  List<Map<String, dynamic>> pricing = [];
  final List<AppNotification> notifications = [];

  final Map<String, OrderStatus> _lastKnownStatus = {};

  bool get isLoggedIn => user != null;

  // ---------------- Locations ----------------

  Future<void> loadLocations() async {
    try {
      final result = await ApiClient.getLocations();
      locations = result.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (_) {
      // Non-critical — the order form falls back to "Choose location".
    }
  }

  void selectLocation(String id, String name) {
    selectedLocationId = id;
    selectedLocationName = name;
    notifyListeners();
  }

  // ---------------- Pricing ----------------

  Future<void> loadPricing() async {
    try {
      final result = await ApiClient.getAllPricing();
      pricing = result.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (_) {
      // Non-critical — the rates sheet just shows nothing.
    }
  }

  // ---------------- Session ----------------

  /// Called on app start: restores a saved session, if any.
  Future<bool> restoreSession() async {
    final token = await SessionStore.token;
    final userId = await SessionStore.userId;
    if (token == null || userId == null) return false;
    try {
      await _loadUser(userId);
      await refreshOrders();
      await loadLocations();
      return true;
    } catch (_) {
      await SessionStore.clear();
      return false;
    }
  }

  Future<void> _loadUser(String userId) async {
    final data = await ApiClient.getUser(userId);
    user = AppUser(
      id: (data['_id'] ?? userId).toString(),
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      phone: data['phone']?.toString(),
      balance: (data['balance'] as num?) ?? 0,
    );
  }

  /// Returns null on success, or an error message.
  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Enter your email and password';
    }
    try {
      final res = await ApiClient.login(email.trim(), password);
      final token = res['token'].toString();
      final userId = res['userId'].toString();
      await SessionStore.save(token: token, userId: userId);
      await _loadUser(userId);
      await refreshOrders();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  /// Returns null on success, or an error message. On success the caller
  /// must still verify the email OTP before the user can log in.
  Future<String?> register(String name, String email, String password) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      return 'Fill in all fields to register';
    }
    try {
      final collegeId = 'GEN-${email.trim().hashCode.toUnsigned(20)}';
      await ApiClient.registerUser(
        collegeId: collegeId,
        name: name.trim(),
        email: email.trim(),
        phone: '',
        password: password,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> verifyEmail(String email, String otp) async {
    try {
      await ApiClient.verifyEmail(email, otp);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<String?> resendVerification(String email) async {
    try {
      await ApiClient.resendVerification(email);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> forgotPassword(String email) async {
    try {
      await ApiClient.forgotPassword(email);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<void> logout() async {
    await SessionStore.clear();
    user = null;
    orders = [];
    notifyListeners();
  }

  // ---------------- Orders ----------------

  List<PrintOrder> get activeOrders =>
      orders.where((o) => o.status != OrderStatus.collected).toList();

  List<PrintOrder> get historyOrders =>
      orders.where((o) => o.status == OrderStatus.collected).toList();

  List<PrintOrder> get todayOrders {
    final now = DateTime.now();
    return orders
        .where((o) =>
            o.createdAt.year == now.year &&
            o.createdAt.month == now.month &&
            o.createdAt.day == now.day)
        .toList();
  }

  Future<void> refreshOrders() async {
    if (user == null) return;
    final jobs = await ApiClient.getJobsByUser(user!.id);
    orders = jobs
        .cast<Map<String, dynamic>>()
        .map(PrintOrder.fromJob)
        .toList();
    await _notifyStatusChanges();
    notifyListeners();
  }

  /// Fires a local notification for any order whose status has moved
  /// forward since the last refresh (printing, ready, or collected).
  Future<void> _notifyStatusChanges() async {
    for (final order in orders) {
      final previous = _lastKnownStatus[order.jobId];
      if (previous != null && previous != order.status) {
        final (title, body) = switch (order.status) {
          OrderStatus.printing => ('Printing now', '${order.fileName} is being printed.'),
          OrderStatus.ready => ('Ready to collect!', '${order.fileName} is ready — come collect it.'),
          OrderStatus.collected => ('Collected', '${order.fileName} was collected. Thanks!'),
          _ => (null, null),
        };
        if (title != null) {
          notifications.insert(
            0,
            AppNotification(title: title, body: body!, time: DateTime.now()),
          );
          await NotificationService.showOrderStatus(
            referenceId: order.id,
            title: title,
            body: body,
          );
        }
      }
      _lastKnownStatus[order.jobId] = order.status;
    }
  }

  /// Uploads a document and returns the backend-detected page count, so the
  /// UI can show the real total cost before the order is placed.
  Future<({String fileId, int pages})> uploadDocument({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    if (user == null) throw ApiException('You are not signed in');
    final uploaded = await ApiClient.uploadFile(
      bytes: fileBytes,
      filename: fileName,
      userId: user!.id,
    );
    final fileId = uploaded['fileId'].toString();
    final metadata = uploaded['metadata'] as Map<String, dynamic>?;
    final pages = (metadata?['totalPages'] as num?)?.toInt() ?? 1;
    return (fileId: fileId, pages: pages);
  }

  Future<PrintOrder> placeOrder({
    required String fileId,
    required int pages,
    required int copies,
    required PrintSide side,
  }) async {
    if (user == null) throw ApiException('You are not signed in');

    final created = await ApiClient.createJob(
      userId: user!.id,
      fileId: fileId,
      printSide: side.backendValue,
      copies: copies,
      totalPagesToPrint: pages,
      locationId: selectedLocationId,
    );
    final job = await ApiClient.getJobById(created['jobId'].toString());
    final order = PrintOrder.fromJob(job);
    orders.insert(0, order);
    notifyListeners();
    return order;
  }

  /// Requests an OTP (emailed to the user) to confirm physical collection.
  Future<String> requestCollection(PrintOrder order) =>
      ApiClient.requestCollect(order.jobId);

  Future<void> confirmCollection(PrintOrder order, String otp) async {
    await ApiClient.verifyCollect(order.jobId, otp);
    await refreshOrders();
  }

  Future<void> cancelOrder(PrintOrder order) async {
    await ApiClient.cancelJob(order.jobId);
    await refreshOrders();
  }

  // ---------------- Billing ----------------

  List<PrintOrder> get unpaidOrders => orders.where((o) => !o.paid).toList();

  List<PrintOrder> get paidOrders => orders.where((o) => o.paid).toList();

  int get totalDue => unpaidOrders.fold(0, (sum, o) => sum + o.cost);

  int get totalSpent => paidOrders.fold(0, (sum, o) => sum + o.cost);
}
