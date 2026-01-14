import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/data/compatibility_quiz_service.dart';

enum CompatibilityStatus { unknown, incomplete, complete }

final compatibilityStatusProvider = FutureProvider<CompatibilityStatus>((
  ref,
) async {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) return CompatibilityStatus.unknown;

  final authAsync = ref.watch(authStateProvider);
  final uid = authAsync.maybeWhen(data: (a) => a.user?.uid, orElse: () => null);
  if (uid == null || uid.isEmpty) return CompatibilityStatus.unknown;

  final service = ref.read(compatibilityQuizServiceProvider);
  try {
    final ok = await service.isQuizComplete(uid);
    return ok ? CompatibilityStatus.complete : CompatibilityStatus.incomplete;
  } catch (_) {
    return CompatibilityStatus.unknown;
  }
});
