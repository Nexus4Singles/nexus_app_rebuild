import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_v2/core/user/current_user_disabled_provider.dart';

/// Backwards-compatible alias.
///
/// Keep older imports working while the codebase migrates to
/// [currentUserDisabledProvider] as the canonical source of truth.
final accountDisabledProvider = Provider<bool>((ref) {
  return ref
      .watch(currentUserDisabledProvider)
      .maybeWhen(data: (v) => v, orElse: () => false);
});
