import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../user/current_user_doc_provider.dart';

/// Provider that checks if a dating profile exists (created but may be pending verification).
/// This is different from `datingProfileStatusProvider` which checks if it's "complete".
/// Returns true if users/{uid}.dating document exists and has any content.
final datingProfileExistsProvider = StreamProvider<bool>((ref) {
  final userDocAsync = ref.watch(currentUserDocProvider);

  return userDocAsync.when(
    data: (userDoc) {
      if (userDoc == null) {
        print('[datingProfileExistsProvider] ℹ️  userDoc is null, profile does not exist');
        return Stream.value(false);
      }

      final dating = (userDoc['dating'] as Map?)?.cast<String, dynamic>();
      final exists = dating != null && dating.isNotEmpty;

      print(
        '[datingProfileExistsProvider] ✅ Profile exists: $exists (dating doc keys: ${dating?.keys.toList() ?? []})',
      );

      return Stream.value(exists);
    },
    loading: () {
      print('[datingProfileExistsProvider] ⏳ Loading...');
      return Stream.value(false);
    },
    error: (err, st) {
      print('[datingProfileExistsProvider] ❌ Error: $err');
      return Stream.value(false);
    },
  );
});
