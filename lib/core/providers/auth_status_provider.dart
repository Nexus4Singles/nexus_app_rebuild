import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/dev_flags.dart';
import 'user_provider.dart';

/// TRUE = logged in, FALSE = guest
final isLoggedInProvider = Provider<bool>((ref) {
  if (DEV_AUTH_BYPASS) return true;

  final userAsync = ref.watch(currentUserProvider);
  return userAsync.valueOrNull != null;
});
