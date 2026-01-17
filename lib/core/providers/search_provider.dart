import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';

import '../models/user_model.dart';
import '../models/dating_profile_model.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

// ============================================================================
// SEARCH FILTERS MODEL
// ============================================================================

/// Filter criteria for user search
class SearchFilters {
  final int minAge;
  final int maxAge;
  final String? nationality;
  final String? education;
  final String? church;
  final String? country;
  final String? incomeSource;
  final String? longDistancePreference;
  final String? maritalStatus;
  final String? hasKids;
  final String? genotype;

  const SearchFilters({
    this.minAge = 21,
    this.maxAge = 60,
    this.nationality,
    this.education,
    this.church,
    this.country,
    this.incomeSource,
    this.longDistancePreference,
    this.maritalStatus,
    this.hasKids,
    this.genotype,
  });

  SearchFilters copyWith({
    int? minAge,
    int? maxAge,
    String? nationality,
    String? education,
    String? church,
    String? country,
    String? incomeSource,
    String? longDistancePreference,
    String? maritalStatus,
    String? hasKids,
    String? genotype,
  }) {
    return SearchFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      nationality: nationality ?? this.nationality,
      education: education ?? this.education,
      church: church ?? this.church,
      country: country ?? this.country,
      incomeSource: incomeSource ?? this.incomeSource,
      longDistancePreference:
          longDistancePreference ?? this.longDistancePreference,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      hasKids: hasKids ?? this.hasKids,
      genotype: genotype ?? this.genotype,
    );
  }

  /// Check if any filters are set (beyond default age range)
  bool get hasActiveFilters =>
      nationality != null ||
      education != null ||
      church != null ||
      country != null ||
      incomeSource != null ||
      longDistancePreference != null ||
      maritalStatus != null ||
      hasKids != null ||
      genotype != null ||
      minAge != 21 ||
      maxAge != 60;

  /// Count of active filters
  int get activeFilterCount {
    int count = 0;
    if (nationality != null) count++;
    if (education != null) count++;
    if (church != null) count++;
    if (country != null) count++;
    if (incomeSource != null) count++;
    if (longDistancePreference != null) count++;
    if (maritalStatus != null) count++;
    if (hasKids != null) count++;
    if (genotype != null) count++;
    if (minAge != 21 || maxAge != 60) count++;
    return count;
  }

  /// Check if a user matches these filters
  bool matchesUser(UserModel user) {
    // Education filter
    if (education != null && user.educationLevel != education) return false;

    // Country filter
    if (country != null && user.country != country) return false;

    // Nationality filter - check both nationality and nationalityCode
    if (nationality != null) {
      if (user.nationality != nationality &&
          user.nationalityCode != nationality) {
        return false;
      }
    }

    // Church filter
    if (church != null && user.churchName != church) return false;

    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchFilters &&
          runtimeType == other.runtimeType &&
          minAge == other.minAge &&
          maxAge == other.maxAge &&
          nationality == other.nationality &&
          education == other.education &&
          church == other.church &&
          country == other.country &&
          incomeSource == other.incomeSource &&
          longDistancePreference == other.longDistancePreference &&
          maritalStatus == other.maritalStatus &&
          hasKids == other.hasKids &&
          genotype == other.genotype;

  @override
  int get hashCode =>
      minAge.hashCode ^
      maxAge.hashCode ^
      nationality.hashCode ^
      education.hashCode ^
      church.hashCode ^
      country.hashCode ^
      incomeSource.hashCode ^
      longDistancePreference.hashCode ^
      maritalStatus.hashCode ^
      hasKids.hashCode ^
      genotype.hashCode;
}

// ============================================================================
// SEARCH FILTERS STATE
// ============================================================================

/// Provider for current search filters
final searchFiltersProvider =
    StateNotifierProvider<SearchFiltersNotifier, SearchFilters>((ref) {
      return SearchFiltersNotifier();
    });

class SearchFiltersNotifier extends StateNotifier<SearchFilters> {
  SearchFiltersNotifier() : super(const SearchFilters());

  void setAgeRange(int min, int max) {
    state = state.copyWith(minAge: min, maxAge: max);
  }

  void setNationality(String? value) {
    state = state.copyWith(nationality: value == 'Any' ? null : value);
  }

  void setEducation(String? value) {
    state = state.copyWith(education: value == 'Any' ? null : value);
  }

  void setChurch(String? value) {
    state = state.copyWith(church: value);
  }

  void setCountry(String? value) {
    state = state.copyWith(country: value == 'Any' ? null : value);
  }

  void setIncomeSource(String? value) {
    state = state.copyWith(incomeSource: value == 'Any' ? null : value);
  }

  void setLongDistancePreference(String? value) {
    state = state.copyWith(
      longDistancePreference: value == 'Any' ? null : value,
    );
  }

  void setMaritalStatus(String? value) {
    state = state.copyWith(maritalStatus: value == 'Any' ? null : value);
  }

  void setHasKids(String? value) {
    state = state.copyWith(hasKids: value == 'Any' ? null : value);
  }

  void setGenotype(String? value) {
    state = state.copyWith(genotype: value == 'Any' ? null : value);
  }

  void reset() {
    state = const SearchFilters();
  }
}

// ============================================================================
// SEARCH RESULTS PROVIDER
// ============================================================================

/// Provider for search results
final searchResultsProvider =
    FutureProvider.family<List<UserModel>, SearchFilters>((ref, filters) async {
      final currentUserId = ref.watch(currentUserIdProvider);
      final currentUser = ref.watch(currentUserProvider).valueOrNull;

      if (currentUserId == null || currentUser == null) {
        return [];
      }

      // Get gender from root level (Nexus 1.0) or nexus2 (Nexus 2.0)
      final userGender = currentUser.gender ?? currentUser.nexus2?.gender;

      // Get blocked users list
      final blockedUsers = currentUser.blocked ?? [];

      final searchService = ref.watch(searchServiceProvider);
      return searchService.searchUsers(
        filters: filters,
        currentUserId: currentUserId,
        currentUserGender: userGender,
        blockedUserIds: blockedUsers,
      );
    });

/// Convenience provider that uses current filters
final filteredSearchResultsProvider = FutureProvider<List<UserModel>>((
  ref,
) async {
  final filters = ref.watch(searchFiltersProvider);
  return ref.watch(searchResultsProvider(filters).future);
});

// ============================================================================
// SEARCH SERVICE
// ============================================================================

final searchServiceProvider = Provider<SearchService>((ref) {
  final firestore = ref.watch(firestoreInstanceProvider);
  return SearchService(firestore);
});

class SearchService {
  final FirebaseFirestore? _firestore;

  SearchService(this._firestore);

  CollectionReference<Map<String, dynamic>> _usersQuery() {
    final fs = _firestore;
    if (fs == null) {
      throw StateError('Firestore not ready');
    }
    return fs
        .collection("users")
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );
  }

  /// Get the opposite gender for filtering
  /// Nexus 2.0 uses lowercase: 'male' / 'female'
  /// This function handles any input and returns the correct opposite
  String? _getOppositeGender(String? currentGender) {
    if (currentGender == null || currentGender.isEmpty) return null;

    final normalized = currentGender.toLowerCase();
    // Return opposite gender in same case as input (for Nexus 1.0 compatibility)
    // Nexus 1.0 may use 'Male'/'Female', Nexus 2.0 uses 'male'/'female'
    if (normalized == 'male') {
      // Check if original was capitalized
      return currentGender[0] == 'M' ? 'Female' : 'female';
    }
    if (normalized == 'female') {
      return currentGender[0] == 'F' ? 'Male' : 'male';
    }
    return null;
  }

  /// Search for users matching filters
  /// IMPORTANT: Only shows opposite gender (Male sees Female, Female sees Male)
  /// Results are sorted by newest profiles first
  /// Blocked users are filtered out
  Future<List<UserModel>> searchUsers({
    required SearchFilters filters,
    required String currentUserId,
    String? currentUserGender,
    List<String>? blockedUserIds,
  }) async {
    try {
      // Start with base query
      Query<Map<String, dynamic>> query = _usersQuery();

      // MANDATORY: Filter by opposite gender (Nexus 1.0 requirement)
      final targetGender = _getOppositeGender(currentUserGender);
      if (targetGender != null) {
        query = query.where('gender', isEqualTo: targetGender);
      } else {
        // If we can't determine gender, don't show any results
        // This ensures users complete their profile before searching
        return [];
      }

      // Order by profile creation date (newest first)
      query = query.orderBy('profileCompletionDate', descending: true);

      // Limit results
      query = query.limit(100);

      // Execute query
      final snapshot = await query.get();

      // Convert to UserModel list with additional filtering
      final blockedSet = blockedUserIds?.toSet() ?? <String>{};

      List<UserModel> users =
          snapshot.docs.map((doc) => UserModel.fromDocument(doc)).where((user) {
            // Exclude current user
            if (user.id == currentUserId) return false;

            // Exclude blocked users
            if (blockedSet.contains(user.id)) return false;

            // Exclude users without photos (incomplete profiles)
            if ((user.photos == null || user.photos!.isEmpty) &&
                (user.profileUrl == null || user.profileUrl!.isEmpty)) {
              return false;
            }

            // Apply age filter
            if (user.age != null) {
              if (user.age! < filters.minAge || user.age! > filters.maxAge)
                return false;
            }

            // Apply additional filters client-side
            return filters.matchesUser(user);
          }).toList();

      return users;
    } catch (e) {
      // Fallback: try without ordering if index doesn't exist
      return _searchUsersFallback(
        filters: filters,
        currentUserId: currentUserId,
        currentUserGender: currentUserGender,
        blockedUserIds: blockedUserIds,
      );
    }
  }

  /// Fallback search without ordering (for when Firestore index is not set up)
  Future<List<UserModel>> _searchUsersFallback({
    required SearchFilters filters,
    required String currentUserId,
    String? currentUserGender,
    List<String>? blockedUserIds,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _usersQuery();

      // MANDATORY: Filter by opposite gender
      final targetGender = _getOppositeGender(currentUserGender);
      if (targetGender != null) {
        query = query.where('gender', isEqualTo: targetGender);
      } else {
        return [];
      }

      query = query.limit(100);
      final snapshot = await query.get();

      final blockedSet = blockedUserIds?.toSet() ?? <String>{};

      List<UserModel> users =
          snapshot.docs.map((doc) => UserModel.fromDocument(doc)).where((user) {
            if (user.id == currentUserId) return false;
            if (blockedSet.contains(user.id)) return false;
            if ((user.photos == null || user.photos!.isEmpty) &&
                (user.profileUrl == null || user.profileUrl!.isEmpty)) {
              return false;
            }
            if (user.age != null) {
              if (user.age! < filters.minAge || user.age! > filters.maxAge)
                return false;
            }
            return filters.matchesUser(user);
          }).toList();

      // Sort client-side by profile completion date (newest first)
      users.sort((a, b) {
        final aDate = a.profileCompletionDate ?? DateTime(2000);
        final bDate = b.profileCompletionDate ?? DateTime(2000);
        return bDate.compareTo(aDate); // Descending order
      });

      return users;
    } catch (e) {
      return [];
    }
  }

  /// Get recommended profiles (for home screen)
  /// IMPORTANT: Only shows opposite gender, sorted by newest first
  Future<List<UserModel>> getRecommendedProfiles({
    required String currentUserId,
    String? currentUserGender,
    int limit = 10,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _usersQuery();

      // MANDATORY: Filter by opposite gender
      final targetGender = _getOppositeGender(currentUserGender);
      if (targetGender != null) {
        query = query.where('gender', isEqualTo: targetGender);
      } else {
        return [];
      }

      // Order by newest profiles first
      query = query.orderBy('profileCompletionDate', descending: true);
      query = query.limit(limit * 2);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => UserModel.fromDocument(doc))
          .where((user) {
            if (user.id == currentUserId) return false;
            if ((user.photos == null || user.photos!.isEmpty) &&
                (user.profileUrl == null || user.profileUrl!.isEmpty)) {
              return false;
            }
            return true;
          })
          .take(limit)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user by ID (for profile viewing)
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _usersQuery().doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromDocument(doc);
    } catch (e) {
      return null;
    }
  }
}

// ============================================================================
// DATING PROFILE COMPLETION PROVIDERS
// ============================================================================

/// Provider for dating profile completion status
final datingProfileCompleteProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  return DatingProfileCompletionService.isComplete(user);
});

/// Provider for dating profile completion percentage
final datingProfileCompletionPercentProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return 0;
  return DatingProfileCompletionService.getCompletionPercentage(user);
});

/// Provider for missing dating profile steps
final missingDatingStepsProvider = Provider<List<DatingProfileStep>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return DatingProfileStep.values.toList();
  return DatingProfileCompletionService.getMissingSteps(user);
});

/// Provider for first missing step
final firstMissingDatingStepProvider = Provider<DatingProfileStep?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return DatingProfileStep.basicInfo;
  return DatingProfileCompletionService.getFirstMissingStep(user);
});

// ============================================================================
// PROFILE VIEW GATING
// ============================================================================

/// Check if current user can view full profiles
final canViewProfilesProvider = Provider<bool>((ref) {
  return ref.watch(datingProfileCompleteProvider);
});

/// Check if current user can send messages
final canSendMessagesProvider = Provider<bool>((ref) {
  return ref.watch(datingProfileCompleteProvider);
});

// ============================================================================
// SAVED PROFILES
// ============================================================================

/// Provider for saved/bookmarked profiles
final savedProfilesProvider =
    StateNotifierProvider<SavedProfilesNotifier, Set<String>>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      final firestore = ref.watch(firestoreInstanceProvider);
      return SavedProfilesNotifier(userId, firestore);
    });

class SavedProfilesNotifier extends StateNotifier<Set<String>> {
  final String? userId;
  final FirebaseFirestore? _firestore;

  SavedProfilesNotifier(this.userId, this._firestore) : super({}) {
    if (userId != null && _firestore != null) _loadSavedProfiles();
  }

  Future<void> _loadSavedProfiles() async {
    if (userId == null) return;
    if (_firestore == null) return;

    try {
      final doc =
          await _firestore
              .collection('users')
              .doc(userId)
              .withConverter<Map<String, dynamic>>(
                fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
                toFirestore: (data, _) => data,
              )
              .get();
      final data = doc.data();
      if (data != null && data['savedProfiles'] != null) {
        final saved = List<String>.from(data['savedProfiles'] as List);
        state = saved.toSet();
      }
    } catch (e) {
      // Silently fail - saved profiles not critical
    }
  }

  Future<void> toggleSave(String profileId) async {
    if (userId == null) return;
    final fs = _firestore;
    if (fs == null) return;
    final newState = Set<String>.from(state);
    if (newState.contains(profileId)) {
      newState.remove(profileId);
    } else {
      newState.add(profileId);
    }
    state = newState;

    // Save to Firestore
    try {
      await fs.collection('users').doc(userId).update({
        'savedProfiles': newState.toList(),
      });
    } catch (e) {
      // Revert on error
      state =
          state.contains(profileId)
              ? (Set<String>.from(state)..remove(profileId))
              : (Set<String>.from(state)..add(profileId));
    }
  }

  bool isSaved(String profileId) => state.contains(profileId);
}

/// Provider to check if a specific profile is saved
final isProfileSavedProvider = Provider.family<bool, String>((ref, profileId) {
  final savedProfiles = ref.watch(savedProfilesProvider);
  return savedProfiles.contains(profileId);
});
