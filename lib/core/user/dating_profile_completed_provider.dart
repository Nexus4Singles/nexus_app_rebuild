import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
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
    // Check for dating.audio structure (v1 nested format)
    if (_hasAnyList(dating ?? {}, 'audio')) return true;

    // V1 users stored audio URLs in these specific fields
    // Check if they contain URLs (https://, http://, gs://)
    bool _isAudioUrl(dynamic value) {
      if (value is! String) return false;
      final v = value.trim().toLowerCase();
      return v.startsWith('http://') ||
          v.startsWith('https://') ||
          v.startsWith('gs://');
    }

    if (_isAudioUrl(doc['relationshipWithGod']) ||
        _isAudioUrl(doc['relationship_with_god']))
      return true;
    if (_isAudioUrl(doc['roleOfHusband']) ||
        _isAudioUrl(doc['role_of_husband']))
      return true;
    if (_isAudioUrl(doc['bestQualitiesOrTraits']) ||
        _isAudioUrl(doc['bestQualotiesOrTraits']) ||
        _isAudioUrl(doc['best_qualities_or_traits']))
      return true;

    // Some v1 docs may nest under "dating" without profileCompleted.
    if (dating != null) {
      final photos = dating['photos'];
      final audio = dating['audioPrompts'] ?? dating['audio'];
      if (photos is List && photos.isNotEmpty) return true;
      if (audio is List && audio.isNotEmpty) return true;
      final url = dating['profileUrl'];
      if (url is String && url.trim().isNotEmpty) return true;

      // V1: Check for core profile fields
      if (_hasNonEmptyString(dating, 'nationalit')) return true;
      if (_hasNonEmptyString(dating, 'nationality')) return true;
      if (_hasNonEmptyString(dating, 'location')) return true;
      if (_hasNonEmptyString(dating, 'country')) return true;
      if (_hasNonEmptyString(dating, 'educationLevel')) return true;
      if (_hasNonEmptyString(dating, 'profession')) return true;
    }

    // Parse with UserModel to capture additional v1/v2 shapes.
    final parsed = UserModel.fromMap('me', doc.cast<String, dynamic>());
    final hasMedia =
        (parsed.profileUrl?.isNotEmpty ?? false) ||
        (parsed.photos?.isNotEmpty ?? false) ||
        (parsed.audioPrompts?.isNotEmpty ?? false);
    final hasBasics = [
      parsed.city,
      parsed.country,
      parsed.nationality,
      parsed.educationLevel,
      parsed.profession,
      parsed.churchName,
    ].any((v) => v != null && v.trim().isNotEmpty);
    final hasLifestyle =
        (parsed.hobbies?.isNotEmpty ?? false) ||
        (parsed.desiredQualities?.isNotEmpty ?? false);

    if (hasMedia || (hasBasics && hasLifestyle)) return true;

    return false;
  });
});
