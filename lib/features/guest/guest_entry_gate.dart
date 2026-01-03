import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/session/guest_session_provider.dart';
import 'relationship_status_picker_screen.dart';

class GuestEntryGate extends ConsumerWidget {
  final Widget child;

  const GuestEntryGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(guestSessionProvider);
    final authAsync = ref.watch(authStateProvider);

    // Signed-in users skip guest setup.
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );
    if (isSignedIn) return child;

    // Guest users must select relationship status once.
    if (session != null) return child;

    return const RelationshipStatusPickerScreen();
  }
}
