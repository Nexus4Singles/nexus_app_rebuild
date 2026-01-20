import 'package:flutter_riverpod/flutter_riverpod.dart';

class SafeUser {
  final String firstName;
  final String status;
  final bool isGuest;

  const SafeUser({
    required this.firstName,
    required this.status,
    required this.isGuest,
  });
}

// Building phase: default to guest mode unless explicitly disabled.
// Run signed-in style UI with:
// flutter run --dart-define=NEXUS_GUEST=false
const bool _kGuestMode = bool.fromEnvironment(
  'NEXUS_GUEST',
  defaultValue: true,
);

final safeUserProvider = Provider<SafeUser>((ref) {
  return SafeUser(
    firstName: _kGuestMode ? '' : 'Ayomide',
    status: 'Stabilization mode',
    isGuest: _kGuestMode,
  );
});
