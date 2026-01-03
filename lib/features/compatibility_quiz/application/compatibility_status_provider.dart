import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/data/compatibility_quiz_service.dart';

enum CompatibilityStatus { unknown, incomplete, complete }

/// TEMP UID provider (until auth module is rebuilt).
/// Replace this later with real auth uid provider.
final tempUidProvider = Provider<String?>((ref) {
  // TODO: wire to authStateProvider.uid when auth module is rebuilt
  return 'demo_user';
});

final compatibilityStatusProvider = FutureProvider<CompatibilityStatus>((
  ref,
) async {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) return CompatibilityStatus.unknown;

  final uid = ref.watch(tempUidProvider);
  if (uid == null || uid.isEmpty) return CompatibilityStatus.unknown;

  final service = ref.read(compatibilityQuizServiceProvider);
  try {
    final ok = await service.isQuizComplete(uid);
    return ok ? CompatibilityStatus.complete : CompatibilityStatus.incomplete;
  } catch (_) {
    return CompatibilityStatus.unknown;
  }
});
