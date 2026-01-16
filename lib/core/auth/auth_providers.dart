import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart' as v2;
import 'auth_state.dart';

/// Compatibility layer:
/// Some screens still expect `authStateProvider` to yield `AuthState` (wrapper).
/// The canonical auth state is now in `core/providers/auth_provider.dart`
/// and yields `User?`. We wrap that canonical stream here so the whole app
/// observes ONE auth source of truth.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final stream = ref.watch(v2.authStateStreamProvider);
  return stream.map((u) => AuthState(u));
});
