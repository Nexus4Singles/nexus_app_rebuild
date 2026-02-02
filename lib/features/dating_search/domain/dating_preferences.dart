import 'package:equatable/equatable.dart';

/// User's dating search preferences
/// Saved to Firestore, reused for 24 hours
class DatingPreferences extends Equatable {
  final int minAge;
  final int maxAge;
  final String? countryOfResidence;
  final bool? allowLongDistance; // open to connecting outside country
  final bool? openToKids; // open to people with kids
  final bool? openToMarriedBefore; // open to people married before
  final String? genotypePreference; // 'AA', 'AS', 'SS', or null for no preference
  
  // Metadata
  final DateTime? createdAt;
  final DateTime? lastRefreshedAt;

  const DatingPreferences({
    required this.minAge,
    required this.maxAge,
    this.countryOfResidence,
    this.allowLongDistance,
    this.openToKids,
    this.openToMarriedBefore,
    this.genotypePreference,
    this.createdAt,
    this.lastRefreshedAt,
  });

  /// Check if 24 hours have passed since last refresh
  bool needsRefresh() {
    if (lastRefreshedAt == null) return true;
    final now = DateTime.now();
    final diff = now.difference(lastRefreshedAt!);
    return diff.inHours >= 24;
  }

  /// Copy with new values
  DatingPreferences copyWith({
    int? minAge,
    int? maxAge,
    String? countryOfResidence,
    bool? allowLongDistance,
    bool? openToKids,
    bool? openToMarriedBefore,
    String? genotypePreference,
    DateTime? createdAt,
    DateTime? lastRefreshedAt,
  }) {
    return DatingPreferences(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      allowLongDistance: allowLongDistance ?? this.allowLongDistance,
      openToKids: openToKids ?? this.openToKids,
      openToMarriedBefore: openToMarriedBefore ?? this.openToMarriedBefore,
      genotypePreference: genotypePreference ?? this.genotypePreference,
      createdAt: createdAt ?? this.createdAt,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    // Store original values (not canonicalized) since Firestore already uses proper capitalization
    return {
      'minAge': minAge,
      'maxAge': maxAge,
      'countryOfResidence': countryOfResidence, // Store original capitalization
      'allowLongDistance': allowLongDistance,
      'openToKids': openToKids,
      'openToMarriedBefore': openToMarriedBefore,
      'genotypePreference': genotypePreference, // Store original capitalization
      'createdAt': createdAt?.toIso8601String(),
      'lastRefreshedAt': lastRefreshedAt?.toIso8601String(),
    };
  }

  /// Create from Firestore map
  factory DatingPreferences.fromFirestore(Map<String, dynamic> data) {
    return DatingPreferences(
      minAge: data['minAge'] as int? ?? 21,
      maxAge: data['maxAge'] as int? ?? 65,
      countryOfResidence: data['countryOfResidence'] as String?,
      allowLongDistance: data['allowLongDistance'] as bool?,
      openToKids: data['openToKids'] as bool?,
      openToMarriedBefore: data['openToMarriedBefore'] as bool?,
      genotypePreference: data['genotypePreference'] as String?,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : null,
      lastRefreshedAt: data['lastRefreshedAt'] != null
          ? DateTime.parse(data['lastRefreshedAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    minAge,
    maxAge,
    countryOfResidence,
    allowLongDistance,
    openToKids,
    openToMarriedBefore,
    genotypePreference,
    createdAt,
    lastRefreshedAt,
  ];
}
