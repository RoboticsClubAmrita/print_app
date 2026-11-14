import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/print_order.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/document_prep.dart';
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
/// Outcome of paying for a single print job.
///
/// Carries the amount the server actually charged — not the client's cached
/// estimate — so callers totalling several payments cannot count a rolled-in
/// balance more than once.
/// Where the guided demo has got to. Drives the demo rail's label and
/// progress, so the user can always see what stage they are at and how much
/// is left — the demo used to give no sense of position at all.
enum DemoStage {
  pickDocument('Choose a document', 1),
  configure('Set it up and place the order', 2),
  pay('Pay and you are done', 3);

  const DemoStage(this.label, this.step);

  final String label;
  final int step;

  static const int total = 3;
}

class OrderPaymentResult {
  final num amountPaid;
  final String? uploadProblem;

  const OrderPaymentResult({required this.amountPaid, this.uploadProblem});
}

class AppState extends ChangeNotifier {
  /// Fixed jobId for the local-only onboarding demo order, so it can be
  /// found and removed later without touching any real order.
  static const String kDemoJobId = 'demo-job-001';

  /// Current stage of the guided demo. Reset whenever a demo starts.
  DemoStage demoStage = DemoStage.pickDocument;

  void setDemoStage(DemoStage stage) {
    if (demoStage == stage) return;
    demoStage = stage;
    notifyListeners();
  }
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

  AppState() {
    ApiClient.onUnauthorized = () {
      logout();
    };
  }

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
      // A dead session has already been cleared via onUnauthorized. Anything
      // else (offline, server error) keeps the tokens so the next launch can
      // restore them.
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
      return 'Enter your college ID and password';
    }
    try {
      final res = await ApiClient.login(email.trim(), password);
      final token = (res['accessToken'] ?? res['token']).toString();
      final userId = res['userId'].toString();
      await SessionStore.save(
        token: token,
        userId: userId,
        refreshToken: res['refreshToken']?.toString(),
      );
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

  /// Starts signup. Returns `(error, email)`: on success `error` is null and
  /// `email` is the Amrita address the backend derived from the roll number —
  /// the one the OTP was sent to. No account exists until [verifyRegistration].
  Future<({String? error, String? email})> register({
    required String name,
    required String collegeId,
    required String phone,
    required String password,
  }) async {
    if (name.trim().isEmpty ||
        collegeId.trim().isEmpty ||
        phone.trim().isEmpty ||
        password.isEmpty) {
      return (error: 'Fill in all fields to register', email: null);
    }
    try {
      final email = await ApiClient.registerStart(
        collegeId: collegeId.trim().toUpperCase(),
        name: name.trim(),
        phone: phone.trim(),
        password: password,
      );
      return (error: null, email: email);
    } on ApiException catch (e) {
      return (error: e.message, email: null);
    } catch (_) {
      return (error: 'Could not reach the server. Check your connection.', email: null);
    }
  }

  /// Verifies the signup OTP. On success the account now exists and this
  /// device is signed in (a new account stays signed in). Returns null on
  /// success, or an error message.
  Future<String?> verifyRegistration(String collegeId, String otp) async {
    try {
      final res = await ApiClient.registerVerify(
        collegeId: collegeId.trim().toUpperCase(),
        otp: otp,
      );
      final token = (res['accessToken'] ?? res['token'])?.toString();
      final userId = res['userId']?.toString();
      if (token == null || userId == null) return 'Invalid code. Try again.';
      await SessionStore.save(
        token: token,
        userId: userId,
        refreshToken: res['refreshToken']?.toString(),
      );
      await SessionStore.setRemember(remember: true);
      await _loadUser(userId);
      await refreshOrders();
      await loadLocations();
      await loadPublicConfig();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> resendRegistration(String collegeId) async {
    try {
      await ApiClient.registerResend(collegeId.trim().toUpperCase());
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
    // Leave the signed-in UI first; the server-side revoke can be slow.
    user = null;
    orders = [];
    notifyListeners();
    await ApiClient.logout();
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

  /// The refresh currently in flight, shared by every caller — the shell's
  /// poll, app resume, and post-action refreshes would otherwise race and
  /// could apply an older response over a newer one.
  Future<void>? _ordersRefresh;

  Future<void> refreshOrders() =>
      _ordersRefresh ??= _fetchOrders().whenComplete(() => _ordersRefresh = null);

  Future<void> _fetchOrders() async {
    if (user == null) return;
    final jobs = await ApiClient.getJobsByUser(user!.id);
    orders = jobs
        .cast<Map<String, dynamic>>()
        .map(PrintOrder.fromJob)
        .toList();
    await _notifyStatusChanges();
    await loadPenalties();

    // A document is sent only after its order is paid for, which leaves a
    // window where money has moved and the bytes are still here. If that
    // upload was interrupted, finish it now — the backend keeps the job out of
    // the print queue until the document lands, so the order is delayed rather
    // than lost. Best-effort: a refresh must never fail because of it.
    unawaited(retryDocumentUploads().catchError((_) => 0));

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

  /// PDFs that have been registered but not yet handed to the backend, keyed by
  /// file id. The document only goes up after its order is paid for, so it has
  /// to survive that gap — including a failed first attempt.
  final Map<String, ({Uint8List bytes, String fileName})> _heldDocuments = {};

  /// Registers a prepared document: the backend records its name, size, sha256
  /// and page count so the order can be priced, while the PDF itself stays on
  /// this device until payment clears.
  ///
  /// The page count comes from [PreparedDocument], counted off the real PDF
  /// here — the backend re-counts it from the bytes it eventually receives and
  /// rejects the upload if the two disagree.
  Future<String> registerDocument(PreparedDocument document) async {
    if (user == null) throw ApiException('You are not signed in');

    final registered = await ApiClient.registerDocument(
      userId: user!.id,
      originalName: document.fileName,
      fileSize: document.bytes.length,
      totalPages: document.totalPages,
      checksum: document.checksum,
    );

    final fileId = registered['fileId'].toString();
    _heldDocuments[fileId] = (bytes: document.bytes, fileName: document.fileName);
    return fileId;
  }

  /// Registers the document and hands the PDF over straight away, before any
  /// job exists and before anything is charged.
  ///
  /// The upload is what makes the price trustworthy: the backend counts the
  /// real document and answers with the count the order will be billed on, so
  /// the figure this app showed while the user was setting things up can never
  /// be the one they are charged for.
  ///
  /// Throws [ApiException] if the document could not be delivered — there is
  /// no order and no charge in that case, and the PDF is still on this device.
  Future<({String fileId, int totalPages, bool pagesCorrected})> registerAndUploadDocument(
    PreparedDocument document,
  ) async {
    final fileId = await registerDocument(document);

    try {
      final res = await ApiClient.uploadDocumentContent(
        fileId: fileId,
        bytes: document.bytes,
        filename: document.fileName,
      );
      _heldDocuments.remove(fileId);

      final serverPages = res['totalPages'];
      final counted = serverPages is int
          ? serverPages
          : int.tryParse('$serverPages') ?? document.totalPages;

      return (
        fileId: fileId,
        totalPages: counted,
        pagesCorrected: res['pagesCorrected'] == true || counted != document.totalPages,
      );
    } catch (_) {
      // The registration is abandoned — the cleanup job drops a row whose
      // document never arrived. Holding the bytes for a retry would deliver a
      // document no order will ever point at.
      _heldDocuments.remove(fileId);
      rethrow;
    }
  }

  /// Sends a held document now that its order is paid for.
  ///
  /// Returns null on success, or a message explaining why it could not be
  /// delivered. A failure here does not lose the order: the backend keeps the
  /// job out of the print queue until the bytes arrive, and the copy stays
  /// held so [retryDocumentUploads] can finish the job.
  Future<String?> uploadDocumentFor(String fileId) async {
    final held = _heldDocuments[fileId];
    if (held == null) return null; // already delivered, or placed on another device

    try {
      await ApiClient.uploadDocumentContent(
        fileId: fileId,
        bytes: held.bytes,
        filename: held.fileName,
      );
      _heldDocuments.remove(fileId);
      return null;
    } on ApiException catch (e) {
      // The backend judged the document itself (checksum or page-count
      // mismatch) — retrying the same bytes will fail identically, so stop
      // holding them and surface the verdict.
      if (e.message.contains('does not match') || e.message.contains('pages but the order')) {
        _heldDocuments.remove(fileId);
      }
      return e.message;
    } catch (_) {
      return 'Could not reach the print server. Your document is safe on this device and will be sent automatically.';
    }
  }

  /// Finishes any delivery interrupted earlier in the session. Called after a
  /// refresh so a paid order that lost its connection completes on its own.
  Future<int> retryDocumentUploads() async {
    var delivered = 0;
    for (final fileId in _heldDocuments.keys.toList()) {
      if (await uploadDocumentFor(fileId) == null) delivered++;
    }
    return delivered;
  }

  /// The locally held copy of a document, if this device still has it —
  /// the only source for a preview before payment clears.
  Uint8List? heldDocumentBytes(String? fileId) =>
      fileId == null ? null : _heldDocuments[fileId]?.bytes;

  /// The PDF behind an order, wherever it currently lives.
  ///
  /// Before payment that is the copy still on this device; afterwards it comes
  /// back from the print server, which serves it to its owner only and only
  /// until 24 hours after collection.
  Future<Uint8List> documentBytesFor(PrintOrder order) async {
    final held = heldDocumentBytes(order.fileId);
    if (held != null) return held;

    if (order.fileId.isEmpty) {
      throw ApiException('This order has no document attached.');
    }
    if (!order.documentStored) {
      throw ApiException(
        'This document has not been sent to the print server yet. '
        'It will be available once the payment is confirmed.',
      );
    }

    return ApiClient.fetchDocumentContent(order.fileId);
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

  /// Cancels an order. The backend refuses once printing has started; the
  /// list is refreshed either way so the screen shows the real status (and
  /// drops the Cancel button) before the refusal is rethrown.
  Future<void> cancelOrder(PrintOrder order) async {
    try {
      await ApiClient.cancelJob(order.jobId);
    } catch (_) {
      await refreshOrders().catchError((_) {});
      rethrow;
    }
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

  /// Pays for a print job through Razorpay and then delivers its document.
  ///
  /// The two halves belong together: the PDF has been sitting on this device
  /// since the order was placed, and the backend holds the job out of the
  /// print queue until it arrives. Paying without sending would leave a paid
  /// order that can never print, so both live in one place rather than being
  /// repeated across the three screens that offer a Pay button.
  ///
  /// Returns null when everything landed, or a message about the document when
  /// payment succeeded but the upload did not.
  Future<OrderPaymentResult> payForOrder(PrintOrder order) async {
    if (user == null) throw ApiException('You are not signed in');
    // The demo order exists only on this device — it has no job on the server
    // to pay for. Guarding here covers every entry point (order detail, the
    // orders list, billing) rather than trusting each one to check.
    if (order.jobId == kDemoJobId) {
      throw ApiException('This is a demo order — there is nothing to pay for.');
    }

    final created = await ApiClient.createPaymentOrder(order.jobId);
    // What the server actually prices this job at right now. It can be lower
    // than `order.cost`, which is a snapshot from the last orders refresh: any
    // outstanding balance rolled into that snapshot may since have been
    // settled by another payment, and the server re-prices before charging.
    final chargedAmount = (created['amount'] as num?) ?? order.cost;
    final result = await RazorpayService.checkout(
      keyId: created['keyId'].toString(),
      orderId: created['orderId'].toString(),
      amountInPaise: (created['amountInPaise'] as num).toInt(),
      name: user?.name ?? 'PrintEase User',
      description: 'Print job ${order.id}',
      userEmail: user?.email,
      userPhone: user?.phone,
    );
    await ApiClient.verifyPayment(
      razorpayOrderId: result.orderId,
      razorpayPaymentId: result.paymentId,
      razorpaySignature: result.signature,
    );

    // Payment is what unlocks the upload — send the document now.
    final uploadProblem = await uploadDocumentFor(order.fileId);

    await refreshOrders();
    return OrderPaymentResult(amountPaid: chargedAmount, uploadProblem: uploadProblem);
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

  // ---------------- Profile Edit ----------------

  Future<String?> requestEmailChange(String newEmail) async {
    if (user == null) return 'You are not signed in';
    try {
      await ApiClient.requestEmailChange(userId: user!.id, newEmail: newEmail);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<String?> verifyEmailChange(String otp) async {
    if (user == null) return 'You are not signed in';
    try {
      await ApiClient.verifyEmailChange(userId: user!.id, otp: otp);
      await _loadUser(user!.id);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<String?> updateProfile({required String name, required String phone}) async {
    if (user == null) return 'You are not signed in';
    try {
      await ApiClient.editUser(userId: user!.id, name: name, phone: phone);
      await _loadUser(user!.id);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  // ---------------- Onboarding demo (local-only, no network) ----------------

  /// Inserts a fake order for the guided demo. Never touches
  /// the backend — safe to call for any user, any number of times.
  void injectDemoOrder(PrintOrder order) {
    orders.insert(0, order);
    notifyListeners();
  }

  /// Advances the demo order's status locally to simulate a successful
  /// payment, without ever calling Razorpay or the API.
  void markDemoOrderPaid() {
    for (final o in orders) {
      if (o.jobId == kDemoJobId) {
        o.status = OrderStatus.queued;
        break;
      }
    }
    notifyListeners();
  }

  /// Removes the demo order once the guided demo ends.
  void removeDemoOrder() {
    orders.removeWhere((o) => o.jobId == kDemoJobId);
    notifyListeners();
  }
}
