import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'current_user_doc_provider.dart';

bool _hasAnyList(Map<String, dynamic> doc, String key) {
  final v = doc[key];
  return v is List && v.isNotEmpty;
}

bool _hasNonEmptyString(Map<String, dynamic> doc, String key) {
  final v = doc[key];
  return v is String && v.trim().isNotEmpty;
}

/// v2: users/{uid}.dating.profileCompleted == true
/// Migration fallback (v1):
/// - If profileCompleted is missing, infer completion from common v1 fields.
final datingProfileCompletedProvider = Provider<AsyncValue<bool>>((ref) {
  final docAsync = ref.watch(currentUserDocProvider);

  return docAsync.whenData((doc) {
    if (doc == null) return false;

    final dating = (doc['dating'] as Map?)?.cast<String, dynamic>();
    final v2 = dating?['profileCompleted'];

    if (v2 == true) return true;
    if (v2 == false) return false;

    // --- v1 fallback heuristics ---
    // Consider "complete" if user has any real profile media/fields already.
    if (_hasNonEmptyString(doc, 'profileUrl')) return true;
    if (_hasAnyList(doc, 'photos')) return true;
    if (_hasAnyList(doc, 'audioPrompts')) return true;

    // Some v1 docs may nest under "dating" without profileCompleted.
    if (dating != null) {
      final photos = dating['photos'];
      final audio = dating['audioPrompts'];
      if (photos is List && photos.isNotEmpty) return true;
      if (audio is List && audio.isNotEmpty) return true;
      final url = dating['profileUrl'];
      if (url is String && url.trim().isNotEmpty) return true;
    }

    return false;
  });
});
