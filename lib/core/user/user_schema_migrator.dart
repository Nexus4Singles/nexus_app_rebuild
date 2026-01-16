import 'package:cloud_firestore/cloud_firestore.dart';

/// Migrates legacy (v1) user documents into a complete v2-compatible map.
/// - Idempotent
/// - Never returns partial data
/// - No mock UI data
Map<String, dynamic> migrateUserV1ToV2({
  required String uid,
  required Map<String, dynamic> raw,
}) {
  final now = Timestamp.now();

  return {
    // ---- identity ----
    'uid': uid,
    'email': raw['email'],
    'firstName': raw['firstName'] ?? raw['first_name'] ?? '',
    'lastName': raw['lastName'] ?? raw['last_name'] ?? '',

    // ---- relationship ----
    'relationshipStatus':
        raw['relationshipStatus'] ?? raw['relationship_status'] ?? 'single',

    // ---- flags ----
    'isGuest': false,
    'isAdmin': raw['isAdmin'] ?? false,

    // ---- dating (v2 namespace) ----
    'dating': {
      'enabled': raw['dating']?['enabled'] ?? raw['dating_enabled'] ?? false,
      'verificationStatus':
          raw['dating']?['verificationStatus'] ?? 'unverified',
    },

    // ---- metadata ----
    'schemaVersion': 2,
    'createdAt': raw['createdAt'] ?? now,
    'updatedAt': now,
  };
}
