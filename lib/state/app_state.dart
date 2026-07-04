import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/print_order.dart';
import '../models/user.dart';

/// Central mocked app state: auth, orders, billing.
/// No backend — everything lives in memory for this static app.
class AppState extends ChangeNotifier {
  AppUser? user;
  final List<PrintOrder> orders = seedOrders();
  int _nextOrderNumber = 1045;

  bool get isLoggedIn => user != null;

  // ---------------- Auth (mocked) ----------------

  bool login(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) return false;
    final namePart =
        email.split('@').first.replaceAll(RegExp(r'[._\d]+'), ' ').trim();
    final display = namePart.isEmpty
        ? 'Print User'
        : namePart
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
    user = AppUser(name: display, email: email.trim());
    notifyListeners();
    return true;
  }

  bool register(String name, String email, String password) {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      return false;
    }
    user = AppUser(name: name.trim(), email: email.trim());
    notifyListeners();
    return true;
  }

  void logout() {
    user = null;
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

  PrintOrder placeOrder({
    required String fileName,
    required int fileSizeKb,
    required int pages,
    required int copies,
    required PrintSide side,
    DateTime? scheduledAt,
  }) {
    final now = DateTime.now();
    final order = PrintOrder(
      id: 'PS-${_nextOrderNumber++}',
      fileName: fileName,
      fileSizeKb: fileSizeKb,
      pages: pages,
      copies: copies,
      side: side,
      createdAt: now,
      scheduledAt: scheduledAt ?? now,
      scheduledNow: scheduledAt == null,
    );
    orders.insert(0, order);
    notifyListeners();
    return order;
  }

  /// Demo affordance: advance an order to its next status since
  /// there is no real print shop backend driving progress.
  void advanceStatus(PrintOrder order) {
    switch (order.status) {
      case OrderStatus.queued:
        order.status = OrderStatus.printing;
      case OrderStatus.printing:
        order.status = OrderStatus.ready;
      case OrderStatus.ready:
      case OrderStatus.collected:
        return;
    }
    notifyListeners();
  }

  void confirmCollection(PrintOrder order) {
    order.status = OrderStatus.collected;
    notifyListeners();
  }

  // ---------------- Billing ----------------

  List<PrintOrder> get unpaidOrders => orders.where((o) => !o.paid).toList();

  List<PrintOrder> get paidOrders => orders.where((o) => o.paid).toList();

  int get totalDue => unpaidOrders.fold(0, (sum, o) => sum + o.cost);

  int get totalSpent => paidOrders.fold(0, (sum, o) => sum + o.cost);

  void payAllDue() {
    for (final o in unpaidOrders) {
      o.paid = true;
    }
    notifyListeners();
  }
}
