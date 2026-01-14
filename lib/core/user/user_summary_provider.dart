import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/firebase_ready_provider.dart';
import '../bootstrap/firestore_instance_provider.dart';

class UserSummary {
  final String uid;
  final String displayName;
  final String? photoUrl;

  const UserSummary({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });
}

String _pickDisplayName(Map<String, dynamic> data, String fallback) {
  final v =
      (data['name'] ?? data['username'] ?? data['displayName'] ?? '')
          .toString()
          .trim();
  return v.isEmpty ? fallback : v;
}

String? _pickPhotoUrl(Map<String, dynamic> data) {
  final v = (data['photoUrl'] ?? data['profileUrl'] ?? '').toString().trim();
  return v.isEmpty ? null : v;
}

/// Streams a minimal user summary from users/{uid}.
final userSummaryProvider = StreamProvider.family<UserSummary?, String>((
  ref,
  uid,
) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ref.watch(firestoreInstanceProvider);
  if (!ready || fs == null) return Stream.value(null);

  return fs.collection('users').doc(uid).snapshots().map((doc) {
    final data = doc.data();
    if (data == null) return null;

    return UserSummary(
      uid: uid,
      displayName: _pickDisplayName(data, 'User ${uid.substring(0, 6)}'),
      photoUrl: _pickPhotoUrl(data),
    );
  });
});
