import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/data/compatibility_quiz_service.dart';

enum CompatibilityStatus { unknown, incomplete, complete }

Future<bool> _isLegacyUser(String uid) async {
  final snap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = snap.data();
  final sv = data == null ? null : data['schemaVersion'];
  final svInt =
      (sv is int)
          ? sv
          : (sv is num)
          ? sv.toInt()
          : int.tryParse('${sv ?? ''}');
  return (svInt == null || svInt < 2);
}

final compatibilityStatusProvider = FutureProvider<CompatibilityStatus>((
  ref,
) async {
  final firebaseReady = ref.watch(firebaseReadyProvider);

  if (kDebugMode) {
    // ignore: avoid_print
    print('[CompatStatus] firebaseReady=$firebaseReady');
  }

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (kDebugMode) {
    // ignore: avoid_print
    print('[CompatStatus] uid=$uid');
  }

  if (uid == null || uid.isEmpty) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[CompatStatus] -> unknown (uid null/empty)');
    }
    return CompatibilityStatus.unknown;
  }

  // If Firebase isn't "ready" (or you intentionally gate it), be permissive for legacy v1 users.
  if (!firebaseReady) {
    try {
      final legacy = await _isLegacyUser(uid);
      if (legacy) return CompatibilityStatus.complete;
    } catch (_) {}
    return CompatibilityStatus.unknown;
  }

  final service = ref.read(compatibilityQuizServiceProvider);

  try {
    final ok = await service.isQuizComplete(uid);
    if (ok) return CompatibilityStatus.complete;

    // If not complete, still allow legacy v1 users.
    try {
      final legacy = await _isLegacyUser(uid);
      if (legacy) return CompatibilityStatus.complete;
    } catch (_) {}

    return CompatibilityStatus.incomplete;
  } catch (_) {
    // If the new check failed, still allow legacy users through.
    try {
      final legacy = await _isLegacyUser(uid);
      if (legacy) return CompatibilityStatus.complete;
    } catch (_) {}
    return CompatibilityStatus.unknown;
  }
});
