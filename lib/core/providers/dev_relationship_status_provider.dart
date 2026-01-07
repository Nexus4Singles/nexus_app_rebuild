import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// Dev-only fallback for relationship status when user/auth is unavailable.
/// Remove once Firebase auth is fully wired.
final devRelationshipStatusProvider = StateProvider<RelationshipStatus>((ref) {
  // ✅ Default for dev testing (change freely)
  return RelationshipStatus.married;
});
