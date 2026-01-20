import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'current_user_doc_provider.dart';

/// Returns whether the signed-in user has opted into the dating experience.
/// Firestore flag (v2): users/{uid}.dating.optIn == true
///
/// Default: true (missing field = opted-in), so we don't accidentally block users.
final datingOptInProvider = StreamProvider<bool>((ref) {
  return ref.watch(currentUserDocProvider.stream).map((doc) {
    final dating = (doc?['dating'] as Map?)?.cast<String, dynamic>();
    final optIn = dating?['optIn'];
    return optIn != false;
  });
});
