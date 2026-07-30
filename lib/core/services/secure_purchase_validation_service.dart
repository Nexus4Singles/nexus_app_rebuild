import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for securely validating purchases with the backend
///
/// All purchase validation happens server-side to prevent fraud:
/// 1. TransactionID is verified with RevenueCat
/// 2. Payment legitimacy is confirmed
/// 3. Duplicate purchases are prevented
/// 4. Audit logs are maintained
class SecurePurchaseValidationService {
  static final SecurePurchaseValidationService _instance =
      SecurePurchaseValidationService._internal();

  factory SecurePurchaseValidationService() => _instance;
  SecurePurchaseValidationService._internal();

  // Cloud Function URL (matches the project configuration)
  static const String _cloudFunctionUrl =
      'https://us-central1-nexus-visibility-app.cloudfunctions.net/validateAndRecordPurchase';

  static const String _cloudFunctionSubscriptionUrl =
      'https://us-central1-nexus-visibility-app.cloudfunctions.net/validateAndRecordSubscription';

  /// Validates a purchase with the backend
  ///
  /// This calls the secure Cloud Function which:
  /// - Verifies the transaction with RevenueCat
  /// - Checks for fraud and duplicates
  /// - Records the purchase atomically
  /// - Sends notifications
  ///
  /// Returns the validated purchase record or throws an exception
  Future<Map<String, dynamic>> validateAndRecordPurchase({
    required String journeyId,
    required String journeyTitle,
    required String transactionId,
    required String packageId,
    double? pricePaid,
    String? currency,
    String? revenueCatCustomerId,
  }) async {
    try {
      debugPrint(
        '🔐 [SecurePurchaseValidationService] Validating purchase with backend',
      );
      debugPrint('   - journeyId: $journeyId');
      debugPrint('   - transactionId: $transactionId');
      debugPrint('   - pricePaid: $pricePaid, currency: $currency');

      // Get the current user and their ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw PurchaseValidationException(
          message: 'User authentication required. Please sign in.',
          code: 'NOT_AUTHENTICATED',
        );
      }

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'journeyId': journeyId,
          'journeyTitle': journeyTitle,
          'transactionId': transactionId,
          'packageId': packageId,
          if (pricePaid != null) 'pricePaid': pricePaid,
          if (currency != null) 'currency': currency,
          if (revenueCatCustomerId != null && revenueCatCustomerId.isNotEmpty)
            'revenueCatCustomerId': revenueCatCustomerId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          '🟢 [SecurePurchaseValidationService] Purchase validated successfully',
        );
        return data;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint(
          '🔴 [SecurePurchaseValidationService] Validation failed: ${response.body}',
        );
        throw PurchaseValidationException(
          message: 'Purchase validation failed. Please try again.',
          code: '${response.statusCode}',
        );
      } else {
        debugPrint(
          '🔴 [SecurePurchaseValidationService] Server error: ${response.body}',
        );
        throw PurchaseValidationException(
          message: 'Server error during validation',
          code: '${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is PurchaseValidationException) rethrow;
      debugPrint('🔴 [SecurePurchaseValidationService] Unexpected error: $e');
      throw PurchaseValidationException(
        message: 'An error occurred while validating your purchase',
      );
    }
  }

  /// Validates a subscription purchase with the backend
  ///
  /// This calls the secure Cloud Function which:
  /// - Verifies the transaction with RevenueCat
  /// - Validates subscription entitlements
  /// - Records the subscription atomically
  /// - Sends notifications
  ///
  /// Returns the validated subscription record or throws an exception
  Future<Map<String, dynamic>> validateAndRecordSubscription({
    required String packageId,
    required String transactionId,
    required String tier,
    String? revenueCatCustomerId,
  }) async {
    try {
      debugPrint(
        '🔐 [SecurePurchaseValidationService] Validating subscription with backend',
      );
      debugPrint('   - transactionId: $transactionId');
      debugPrint('   - tier: $tier');

      // Get the current user and their ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw PurchaseValidationException(
          message: 'User authentication required. Please sign in.',
          code: 'NOT_AUTHENTICATED',
        );
      }

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(_cloudFunctionSubscriptionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'packageId': packageId,
          'transactionId': transactionId,
          'tier': tier,
          if (revenueCatCustomerId != null && revenueCatCustomerId.isNotEmpty)
            'revenueCatCustomerId': revenueCatCustomerId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          '🟢 [SecurePurchaseValidationService] Subscription validated successfully',
        );
        return data;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint(
          '🔴 [SecurePurchaseValidationService] Validation failed: ${response.body}',
        );
        throw PurchaseValidationException(
          message: 'Subscription validation failed. Please try again.',
          code: '${response.statusCode}',
        );
      } else {
        debugPrint(
          '🔴 [SecurePurchaseValidationService] Server error: ${response.body}',
        );
        throw PurchaseValidationException(
          message: 'Server error during subscription validation',
          code: '${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is PurchaseValidationException) rethrow;
      debugPrint('🔴 [SecurePurchaseValidationService] Unexpected error: $e');
      throw PurchaseValidationException(
        message: 'An error occurred while validating your subscription',
      );
    }
  }
}

/// Exception thrown when purchase validation fails
class PurchaseValidationException implements Exception {
  final String message;
  final String? code;

  PurchaseValidationException({required this.message, this.code});

  @override
  String toString() => 'PurchaseValidationException: $message';
}
