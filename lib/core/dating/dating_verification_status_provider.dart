import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../user/current_user_doc_provider.dart';

/// Provider that streams the dating profile verification status.
/// This will update automatically when admin approves/rejects a profile.
/// Values: 'pending', 'verified', 'rejected', or null if not set
final datingVerificationStatusProvider = StreamProvider<String?>((ref) {
  final userDocAsync = ref.watch(currentUserDocProvider);

  return userDocAsync.when(
    data: (userDoc) {
      if (userDoc == null) {
        print('[datingVerificationStatusProvider] ℹ️  userDoc is null, returning null');
        return Stream.value(null);
      }

      final dating = (userDoc['dating'] as Map?)?.cast<String, dynamic>();
      final verificationStatus = dating?['verificationStatus']?.toString();

      print(
        '[datingVerificationStatusProvider] ✅ Verification status updated: $verificationStatus',
      );

      return Stream.value(verificationStatus);
    },
    loading: () {
      print('[datingVerificationStatusProvider] ⏳ Loading verification status...');
      return Stream.value(null);
    },
    error: (err, st) {
      print('[datingVerificationStatusProvider] ❌ Error: $err');
      return Stream.value(null);
    },
  );
});

/// Convenience provider that returns true if profile is verified
final isProfileVerifiedProvider = StreamProvider<bool>((ref) {
  final statusAsync = ref.watch(datingVerificationStatusProvider);

  return statusAsync.when(
    data: (status) {
      final isVerified = status == 'verified';
      print('[isProfileVerifiedProvider] isVerified=$isVerified (status=$status)');
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
