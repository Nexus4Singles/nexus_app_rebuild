import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../session/is_guest_provider.dart';
import 'auth_gate_modal.dart';

class GuestGuard {
  static Future<void> requireSignedIn(
    BuildContext context,
    WidgetRef ref, {
    required VoidCallback onCreateAccount,
    required String title,
    required String message,
    required String primaryText,
    Future<void> Function()? onAllowed,
  }) async {
    final isGuestAsync = ref.read(isGuestProvider);

    final isGuest = isGuestAsync.maybeWhen(data: (v) => v, orElse: () => true);

    if (!isGuest) {
      await onAllowed?.call();
      return;
    }

    await AuthGateModal.show(
      context,
      title: title,
      message: message,
      primaryButtonText: primaryText,
      onPrimary: onCreateAccount,
    );
  }
}
