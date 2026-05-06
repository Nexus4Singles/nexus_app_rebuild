import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/core/transaction_status.dart';
import 'package:flutterwave_standard/flutterwave.dart';

import '../domain/counselling_models.dart';

/// Result returned by `PaymentService.chargeFlutterwave()`.
class PaymentResult {
  final bool success;
  final String? txRef;
  final String? errorMessage;

  const PaymentResult._({required this.success, this.txRef, this.errorMessage});

  factory PaymentResult.success(String txRef) =>
      PaymentResult._(success: true, txRef: txRef);

  factory PaymentResult.cancelled() =>
      PaymentResult._(success: false, errorMessage: 'Payment was cancelled.');

  factory PaymentResult.failure(String message) =>
      PaymentResult._(success: false, errorMessage: message);
}

class PaymentService {
  // Your Flutterwave PUBLIC key — safe to embed in the app (not the secret key).
  // Set in dart_defines.json before release:
  //   "FLUTTERWAVE_PUBLIC_KEY": "FLWPUBK-xxxxxxxxxxxxxxxx"
  static const _fwPublicKey = String.fromEnvironment(
    'FLUTTERWAVE_PUBLIC_KEY',
    defaultValue: 'FLWPUBK_TEST-REPLACE-WITH-YOUR-KEY',
  );

  /// Opens the Flutterwave in-app payment sheet.
  /// Returns a [PaymentResult] with the txRef on success.
  Future<PaymentResult> chargeFlutterwave({
    required BuildContext context,
    required BookingModel booking,
  }) async {
    // txRef format matches the existing webhook pattern so the webhook also works.
    final txRef =
        'nexus-coaching-${booking.id}-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final flutterwave = Flutterwave(
        publicKey: _fwPublicKey,
        currency: booking.currency,
        amount: booking.totalAmount.toStringAsFixed(2),
        customer: Customer(email: booking.userEmail, name: booking.userName),
        paymentOptions: 'card, banktransfer, ussd, mobilemoney',
        customization: Customization(
          title: 'Nexus Coaching',
          description:
              '${booking.sessionTypeEnum.label} with ${booking.coachName}',
        ),
        txRef: txRef,
        redirectUrl: 'https://nexus-visibility-app.web.app/booking-success',
        isTestMode: false, // set to true during development/testing
      );

      // context is passed to charge(), not the constructor
      final ChargeResponse response = await flutterwave.charge(context);

      final status = response.status ?? '';
      if (status == TransactionStatus.SUCCESSFUL) {
        return PaymentResult.success(txRef);
      }
      if (status == TransactionStatus.CANCELLED) {
        return PaymentResult.cancelled();
      }

      return PaymentResult.failure(
        status.isNotEmpty ? status : 'Payment did not complete.',
      );
    } catch (e) {
      return PaymentResult.failure(e.toString());
    }
  }

  /// Calls the `verifyAndConfirmBookingPayment` Cloud Function to verify the
  /// transaction server-side (against the Flutterwave API using the secret key)
  /// and mark the booking as confirmed in Firestore.
  Future<void> verifyAndConfirmPayment({
    required String bookingId,
    required String txRef,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('verifyAndConfirmBookingPayment');

    final result = await callable.call<Map<String, dynamic>>({
      'bookingId': bookingId,
      'txRef': txRef,
    });

    if (result.data['success'] != true) {
      throw Exception('Payment verification failed on server.');
    }
  }
}
