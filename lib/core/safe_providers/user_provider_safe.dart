import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafeUser {
  final String firstName;
  final String status;
  final bool isGuest;

  /// Relationship status chosen in presurvey (e.g. never_married / married / divorced / widowed)
  final String relationshipStatus;

  /// Optional category field if you store it separately (fallbacks supported)
  final String category;

  const SafeUser({
    required this.firstName,
    required this.status,
    required this.isGuest,
    required this.relationshipStatus,
    required this.category,
  });

  SafeUser copyWith({
    String? firstName,
    String? status,
    bool? isGuest,
    String? relationshipStatus,
    String? category,
  }) {
    return SafeUser(
      firstName: firstName ?? this.firstName,
      status: status ?? this.status,
      isGuest: isGuest ?? this.isGuest,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      category: category ?? this.category,
    );
  }
}

/// Reads user-ish fields from local prefs (until Firebase is wired).
/// This is the single source of truth for Home copies in the current phase.
final safeUserProvider = FutureProvider<SafeUser>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  String _s(String? v) => (v ?? '').trim();

  // Guest mode: support multiple possible keys so we don’t break when naming changes.
  final isGuest =
      prefs.getBool('isGuest') ??
      prefs.getBool('guestMode') ??
      prefs.getBool('guest_mode') ??
      prefs.getBool('nexus_is_guest') ??
      true; // default true in your current build phase

  // Name: try a few keys; in guest mode we don’t show name anyway.
  final firstName =
      _s(
            prefs.getString('firstName') ??
                prefs.getString('first_name') ??
                prefs.getString('username') ??
                prefs.getString('displayName'),
          ).isEmpty
          ? 'Ayomide'
          : _s(
            prefs.getString('firstName') ??
                prefs.getString('first_name') ??
                prefs.getString('username') ??
                prefs.getString('displayName'),
          );

  // Relationship status (presurvey)
  final relationshipStatus =
      _s(
            prefs.getString('relationshipStatus') ??
                prefs.getString('relationship_status') ??
                prefs.getString('relationship') ??
                prefs.getString('userRelationshipStatus'),
          ).isEmpty
          ? 'singles'
          : _s(
            prefs.getString('relationshipStatus') ??
                prefs.getString('relationship_status') ??
                prefs.getString('relationship') ??
                prefs.getString('userRelationshipStatus'),
          );

  final category =
      _s(
            prefs.getString('category') ??
                prefs.getString('userCategory') ??
                prefs.getString('journeyCategory'),
          ).isEmpty
          ? relationshipStatus
          : _s(
            prefs.getString('category') ??
                prefs.getString('userCategory') ??
                prefs.getString('journeyCategory'),
          );

  return SafeUser(
    firstName: firstName,
    status: 'Stabilization mode',
    isGuest: isGuest,
    relationshipStatus: relationshipStatus,
    category: category,
  );
});
