import 'package:flutter/foundation.dart';

import '../models/print_order.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/razorpay_service.dart';
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
  Map<String, dynamic>? publicConfig;
  List<dynamic> penalties = [];
  num outstandingDues = 0;
  final List<AppNotification> notifications = [];

  /// One-shot request for the shell to switch bottom-nav tabs (e.g. the
  /// pending-dues popup's "Go to Billing"). The shell consumes it and resets
  /// it to null, so the same tab can be requested again later.
  final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  void requestTab(int index) => tabRequest.value = index;

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

  // ---------------- Business config ----------------

  /// Displayable business rules (penalty rate/free window, scheduling
  /// limits) — read live from the backend so nothing is guessed
  /// client-side. Falls back to safe UI defaults on failure.
  Future<void> loadPublicConfig() async {
    try {
      publicConfig = await ApiClient.getPublicConfig();
      notifyListeners();
    } catch (_) {
      // Non-critical — screens fall back to sane hardcoded defaults.
    }
  }

  int get maxScheduleDaysAhead =>
      (publicConfig?['scheduling']?['maxDaysAhead'] as num?)?.toInt() ?? 30;

  // ---------------- Session ----------------

  /// Called on app start: restores a saved session, if any.
  Future<bool> restoreSession() async {
    final token = await SessionStore.token;
    final userId = await SessionStore.userId;
    if (token == null || userId == null) return false;
    // Only auto-restore when the user opted to stay signed in. Otherwise drop
    // the stored session so this launch requires a fresh login.
    if (!await SessionStore.rememberMe) {
      await SessionStore.clear();
      return false;
    }
    try {
      await _loadUser(userId);
      await refreshOrders();
      await loadLocations();
      await loadPublicConfig();
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
      await loadPublicConfig();
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
  ///
  /// The College ID is sent fully upper-cased (the backend also enforces this
  /// in Phase B); [role] is one of 'STUDENT' / 'FACULTY'.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String collegeId,
    required String phone,
    required String role,
  }) async {
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.isEmpty ||
        collegeId.trim().isEmpty ||
        phone.trim().isEmpty) {
      return 'Fill in all fields to register';
    }
    try {
      await ApiClient.registerUser(
        collegeId: collegeId.trim().toUpperCase(),
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        password: password,
        role: role,
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
          OrderStatus.awaitingStack => (
              'Printed',
              '${order.fileName} is printed and waiting for a pickup slot.'
            ),
          OrderStatus.ready => ('Ready to collect!', '${order.fileName} is ready — come collect it.'),
          OrderStatus.collected => ('Collected', '${order.fileName} was collected. Thanks!'),
          // Only the SCHEDULED→QUEUED promotion is notable — a normal
          // PENDING→QUEUED right after payment doesn't need its own alert.
          OrderStatus.queued when previous == OrderStatus.scheduled => (
              'Scheduled print queued',
              '${order.fileName} is now in the print queue.'
            ),
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
    List<int>? selectedPages,
    DateTime? scheduledFor,
  }) async {
    if (user == null) throw ApiException('You are not signed in');

    final created = await ApiClient.createJob(
      userId: user!.id,
      fileId: fileId,
      printSide: side.backendValue,
      copies: copies,
      totalPagesToPrint: pages,
      locationId: selectedLocationId,
      selectedPages: selectedPages,
      scheduleType: scheduledFor != null ? 'SCHEDULED' : 'NOW',
      scheduledFor: scheduledFor,
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

  /// Verifies the collection OTP and returns the name of the stack the
  /// material was sitting in, so the UI can tell the user where to look.
  Future<String> confirmCollection(PrintOrder order, String otp) async {
    final stackName = await ApiClient.verifyCollect(order.jobId, otp);
    await refreshOrders();
    return stackName;
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

  // ---------------- Penalties / outstanding dues ----------------

  /// Loads the user's outstanding penalty ledger — the auditable list
  /// backing the Billing tab's "Outstanding dues" card. Always reads
  /// from the backend; never trusts a locally-cached total.
  Future<void> loadPenalties() async {
    if (user == null) return;
    try {
      final result = await ApiClient.getUserPenalties(user!.id);
      penalties = result.penalties;
      outstandingDues = result.totalOutstanding;
      notifyListeners();
    } catch (_) {
      // Non-critical — the dues card just shows nothing until retried.
    }
  }

  /// Pays off all outstanding dues directly (independent of any print
  /// job) via Razorpay. Returns the paid amount on success.
  Future<num> payOutstandingDues() async {
    if (user == null) throw ApiException('You are not signed in');
    final created = await ApiClient.createPenaltyOrder(user!.id);
    final result = await RazorpayService.checkout(
      keyId: created['keyId'].toString(),
      orderId: created['orderId'].toString(),
      amountInPaise: (created['amountInPaise'] as num).toInt(),
      name: user?.name ?? 'PrintEase User',
      description: 'Outstanding dues',
      userEmail: user?.email,
      userPhone: user?.phone,
    );
    await ApiClient.verifyPayment(
      razorpayOrderId: result.orderId,
      razorpayPaymentId: result.paymentId,
      razorpaySignature: result.signature,
    );
    final paidAmount = (created['amount'] as num?) ?? 0;
    await _loadUser(user!.id);
    await loadPenalties();
    notifyListeners();
    return paidAmount;
  }
}
