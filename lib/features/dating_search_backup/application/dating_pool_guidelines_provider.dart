import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'package:nexus_app_v2/core/services/firestore_service.dart';
import 'package:nexus_app_v2/core/providers/firestore_service_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

const String _GUIDELINES_SHOWN_KEY_PREFIX = 'dating_pool_guidelines_shown_';

/// Get user-specific SharedPreferences key for guidelines
String _getUserGuidelinesKey(String userId) =>
    '$_GUIDELINES_SHOWN_KEY_PREFIX$userId';

/// Synchronously check if current user has seen guidelines (fastest check first)
Future<bool> hasUserSeenGuidelinesSync() async {
  // This function needs userId but doesn't have it in this context
  // Fall back to checking without user-specific key for backward compatibility
  final prefs = await SharedPreferences.getInstance();
  // Check for old device-level key first (for migration)
  return prefs.getBool('dating_pool_guidelines_shown') ?? false;
}

/// Notifier to update the hasSeenDatingPoolGuidelines flag
class _MarkGuidelinesSeenNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No-op
  }

  Future<void> markAsRead() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) throw Exception('No user logged in');

    // Mark as shown in session cache with user-specific key (prevents re-showing to this user)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_getUserGuidelinesKey(userId), true);

    final firestoreService = ref.watch(firestoreServiceProvider);

    try {
      // Update the Firestore document using updateNexus2Fields
      // This automatically prefixes the key with 'nexus2.'
      await firestoreService.updateNexus2Fields(userId, {
        'hasSeenDatingPoolGuidelines': true,
      });

      // Invalidate user provider to refresh the data
      ref.invalidate(userStreamProvider);
      ref.invalidate(currentUserProvider);
    } catch (e) {
      print('[DatingPoolGuidelines] Error marking guidelines as seen: $e');
      rethrow;
    }
  }
}

final markGuidelinesSeenProvider =
    AutoDisposeAsyncNotifierProvider<_MarkGuidelinesSeenNotifier, void>(
      () => _MarkGuidelinesSeenNotifier(),
    );
