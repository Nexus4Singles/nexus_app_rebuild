import '../constants/app_constants.dart';

String relationshipStatusKeyFromEnum(RelationshipStatus status) {
  switch (status) {
    case RelationshipStatus.singleNeverMarried:
      return 'singles';
    case RelationshipStatus.married:
      return 'married';
    case RelationshipStatus.divorced:
      return 'divorced';
    case RelationshipStatus.widowed:
      return 'widowed';
  }
}

String relationshipStatusKeyFromString(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.contains('single') || s.contains('never')) return 'singles';
  if (s.contains('divorc')) return 'divorced';
  if (s.contains('widow') || s.contains('widower')) return 'widowed';
  if (s.contains('married')) return 'married';
  return 'singles';
}
