import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../user/current_user_doc_provider.dart';

String? _extractVerificationStatus(Map<String, dynamic>? userDoc) {
  if (userDoc == null) return null;

  final dating = (userDoc['dating'] as Map?)?.cast<String, dynamic>();
  final rawStatus = dating?['verificationStatus']?.toString().trim().toLowerCase();

  if (rawStatus == 'verified' || rawStatus == 'pending' || rawStatus == 'rejected') {
    return rawStatus;
  }

  // Some older or partially-repaired records carry verification metadata
  // (verifiedBy/verifiedAt) but still store an outdated 'unverified' value.
  // Treat those as verified so the app and preferences flow remain consistent.
  final hasVerificationMetadata =
      (dating?['verifiedAt'] != null) ||
      ((dating?['verifiedBy']?.toString().trim().isNotEmpty ?? false));

  if (hasVerificationMetadata) {
    return 'verified';
  }

  return rawStatus;
}

/// Provider that streams the dating profile verification status.
/// This will update automatically when admin approves/rejects a profile.
/// Values: 'pending', 'verified', 'rejected', or null if not set
final datingVerificationStatusProvider = StreamProvider<String?>((ref) async* {
  final userDocAsync = ref.watch(currentUserDocProvider);
  final userDocStream = ref.watch(currentUserDocProvider.stream);

  if (userDocAsync.hasValue) {
    final initialValue = _extractVerificationStatus(userDocAsync.value);
    yield initialValue;
  }

  await for (final userDoc in userDocStream) {
    yield _extractVerificationStatus(userDoc);
  }
});

/// Convenience provider that returns true if profile is verified
final isProfileVerifiedProvider = StreamProvider<bool>((ref) {
  final statusAsync = ref.watch(datingVerificationStatusProvider);

  return statusAsync.when(
    data: (status) {
      final isVerified = status == 'verified';
      print(
        '[isProfileVerifiedProvider] isVerified=$isVerified (status=$status)',
      );
      return Stream.value(isVerified);
    },
    loading: () {
      print('[isProfileVerifiedProvider] ⏳ Loading...');
      return Stream.value(false);
    },
    error: (err, st) {
      print('[isProfileVerifiedProvider] ❌ Error: $err');
      return Stream.value(false);
    },
  );
});
