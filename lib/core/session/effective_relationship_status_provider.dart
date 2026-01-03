import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../constants/app_constants.dart';
import '../user/user_status_provider.dart';
import 'guest_session_provider.dart';

final effectiveRelationshipStatusProvider = Provider<RelationshipStatus?>((
  ref,
) {
  final authAsync = ref.watch(authStateProvider);

  final isSignedIn = authAsync.maybeWhen(
    data: (a) => a.isSignedIn,
    orElse: () => false,
  );

  if (isSignedIn) {
    final statusAsync = ref.watch(userRelationshipStatusProvider);
    return statusAsync.maybeWhen(data: (s) => s, orElse: () => null);
  }

  final guest = ref.watch(guestSessionProvider);
  return guest?.relationshipStatus;
});
