import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/user/current_user_doc_provider.dart';

/// Provider that reads user's country of residence from their dating profile
/// This is used to determine pricing for subscriptions and journeys
final userCountryProvider = FutureProvider<String?>((ref) async {
  try {
    final userDocAsync = ref.watch(currentUserDocProvider);

    return userDocAsync.maybeWhen(
      data: (userDoc) {
        if (userDoc == null) return null;

        // Helper to normalize country name to title case
        String normalizeCountry(String country) {
          return country.trim()[0].toUpperCase() +
              country.trim().substring(1).toLowerCase();
        }

        // Try to get country from dating profile first
        final dating = (userDoc['dating'] as Map?)?.cast<String, dynamic>();
        final datingCountry = dating?['profile']?['country'] as String?;
        if (datingCountry != null && datingCountry.trim().isNotEmpty) {
          final normalized = normalizeCountry(datingCountry);
          print(
            '[UserCountryProvider] Country from dating.profile: $datingCountry → $normalized',
          );
          return normalized;
        }

        // Fallback to top-level country field
        final topLevelCountry = userDoc['country'] as String?;
        if (topLevelCountry != null && topLevelCountry.trim().isNotEmpty) {
          final normalized = normalizeCountry(topLevelCountry);
          print(
            '[UserCountryProvider] Country from top-level: $topLevelCountry → $normalized',
          );
          return normalized;
        }

        print('[UserCountryProvider] No country found in user doc');
        return null;
      },
      orElse: () {
        print('[UserCountryProvider] User doc not available');
        return null;
      },
    );
  } catch (e) {
    print('[UserCountryProvider] Error reading country: $e');
    return null;
  }
});
