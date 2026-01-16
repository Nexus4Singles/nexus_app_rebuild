import 'package:cloud_firestore/cloud_firestore.dart';

/// Build a merge-safe PATCH for user documents:
/// - Only fills missing v2 fields
/// - Never overwrites existing values in Firestore
/// - Idempotent
Map<String, dynamic> buildUserV2Patch({
  required String uid,
  required Map<String, dynamic> raw,
  String? fallbackEmail,
  String? fallbackDisplayName,
  String? fallbackPhotoUrl,
}) {
  final patch = <String, dynamic>{};

  // ---------- identity ----------
  if (raw['uid'] == null || (raw['uid']?.toString().trim().isEmpty ?? true)) {
    patch['uid'] = uid;
  }

  final existingEmail = raw['email'];
  if ((existingEmail == null || existingEmail.toString().trim().isEmpty) &&
      (fallbackEmail != null && fallbackEmail.trim().isNotEmpty)) {
    patch['email'] = fallbackEmail.trim();
  }

  // Prefer existing first/last names if present; else derive from displayName.
  final firstName = raw['firstName'] ?? raw['first_name'];
  final lastName = raw['lastName'] ?? raw['last_name'];

  if ((firstName == null || firstName.toString().trim().isEmpty) &&
      (fallbackDisplayName != null && fallbackDisplayName.trim().isNotEmpty)) {
    final parts = fallbackDisplayName.trim().split(RegExp(r'\s+'));
    patch['firstName'] = parts.isNotEmpty ? parts.first : '';
  }

  if ((lastName == null || lastName.toString().trim().isEmpty) &&
      (fallbackDisplayName != null && fallbackDisplayName.trim().isNotEmpty)) {
    final parts = fallbackDisplayName.trim().split(RegExp(r'\s+'));
    patch['lastName'] = parts.length >= 2 ? parts.sublist(1).join(' ') : '';
  }

  // Photo URL (optional)
  if ((raw['profileUrl'] == null ||
          raw['profileUrl'].toString().trim().isEmpty) &&
      (fallbackPhotoUrl != null && fallbackPhotoUrl.trim().isNotEmpty)) {
    patch['profileUrl'] = fallbackPhotoUrl.trim();
  }

  // ---------- flags ----------
  // Never set isGuest for signed-in users unless missing.
  if (raw['isGuest'] == null) patch['isGuest'] = false;

  // isAdmin: preserve existing; set false only if missing.
  if (raw['isAdmin'] == null) patch['isAdmin'] = false;

  // ---------- dating (v2 namespace) ----------
  // Legacy (v1) rule: v1 was a dating-only app, so legacy users should be eligible
  // for dating/search/chat by default in v2 (subject to opposite-gender rule elsewhere).
  final schemaVersionRaw = raw['schemaVersion'];
  final schemaVersionInt =
      (schemaVersionRaw is int)
          ? schemaVersionRaw
          : int.tryParse(schemaVersionRaw?.toString() ?? '');
  final isLegacy = (schemaVersionInt == null || schemaVersionInt < 2);

  final datingRaw = raw['dating'];
  final datingMap =
      (datingRaw is Map)
          ? Map<String, dynamic>.from(datingRaw)
          : <String, dynamic>{};
  final datingPatch = <String, dynamic>{};

  // Enabled:
  // - If legacy user: default ON (unless already explicitly set)
  // - If v2 user: do not force (only fill if missing)
  if (!datingMap.containsKey('enabled')) {
    datingPatch['enabled'] = isLegacy ? true : (raw['dating_enabled'] ?? false);
  }

  // Opt-in (used by datingOptInProvider). Missing field defaults to opted-in,
  // but we set it explicitly for legacy users to make intent clear.
  if (!datingMap.containsKey('optIn') && isLegacy) {
    datingPatch['optIn'] = true;
  }

  // Optional mirror for older codepaths that still read root key.
  if (raw['dating_enabled'] == null && isLegacy) {
    patch['dating_enabled'] = true;
  }

  // Verification status (safe default)
  if (!datingMap.containsKey('verificationStatus')) {
    datingPatch['verificationStatus'] = 'unverified';
  }

  // Discoverability / visibility for search (choose a conservative key that can be used later).
  // Only set for legacy users by default; v2 users can manage via settings later.
  if (isLegacy && !datingMap.containsKey('isDiscoverable')) {
    datingPatch['isDiscoverable'] = true;
  }

  // Chat enabled flag (optional; harmless if unused today).
  if (isLegacy && !datingMap.containsKey('chatEnabled')) {
    datingPatch['chatEnabled'] = true;
  }

  if (datingPatch.isNotEmpty) {
    patch['dating'] = {...datingMap, ...datingPatch};
  }
  // ---------- metadata ----------
  // schemaVersion: only set/upgrade if missing or < 2.
  final sv = raw['schemaVersion'];
  final svInt = (sv is int) ? sv : int.tryParse(sv?.toString() ?? '');
  if (svInt == null || svInt < 2) patch['schemaVersion'] = 2;

  // createdAt: only set if missing
  if (raw['createdAt'] == null)
    patch['createdAt'] = FieldValue.serverTimestamp();

  // updatedAt: always bump (safe; doesn't overwrite user-provided fields)
  patch['updatedAt'] = FieldValue.serverTimestamp();

  return patch;
}
