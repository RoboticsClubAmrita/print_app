import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayResult {
  final String orderId;
  final String paymentId;
  final String signature;
  RazorpayResult(this.orderId, this.paymentId, this.signature);
}

/// Wraps razorpay_flutter's event-based Checkout API in a Future so
/// callers can `await` a single payment attempt.
class RazorpayService {
  static Future<RazorpayResult> checkout({
    required String keyId,
    required String orderId,
    required int amountInPaise,
    required String name,
    required String description,
    String? userEmail,
    String? userPhone,
  }) {
    final completer = Completer<RazorpayResult>();
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!completer.isCompleted) {
        completer.complete(RazorpayResult(
          r.orderId ?? orderId,
          r.paymentId ?? '',
          r.signature ?? '',
        ));
      }
      razorpay.clear();
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!completer.isCompleted) {
        completer.completeError(Exception(r.message ?? 'Payment failed'));
      }
      razorpay.clear();
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Payment cancelled (${r.walletName})'));
      }
      razorpay.clear();
    });

    razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': amountInPaise,
      'name': 'PrintEase',
      'description': description,
      'prefill': {
        if (userEmail != null) 'email': userEmail,
        if (userPhone != null) 'contact': userPhone,
      },
      'theme': {'color': '#000000'},
    });

    return completer.future;
  }
}
