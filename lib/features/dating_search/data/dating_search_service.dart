import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import '../domain/dating_profile.dart';
import '../domain/dating_search_filters.dart';

final datingSearchServiceProvider = Provider<DatingSearchService>((ref) {
  final fs = ref.watch(firestoreInstanceProvider);
  return DatingSearchService(fs);
});

class DatingSearchService {
  bool _isDisabledUserDoc(Map<String, dynamic> data) {
    final accountStatus = data['accountStatus']?.toString().toLowerCase();
    if (accountStatus == 'disabled') return true;

    final status = data['status']?.toString().toLowerCase();
    if (status == 'disabled') return true;

    final disabled = data['disabled'];
    if (disabled == true) return true;

    return false;
  }

  final FirebaseFirestore? _firestore;
  DatingSearchService(this._firestore);

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));

  /// Firestore equality on `gender` is case-sensitive + exact-match.
  /// v1/v2 may store different casing (e.g. "Female" vs "female").
  /// Query common variants and merge/dedupe results.
  Set<String> _genderQueryValues(String genderToShow) {
    final raw = genderToShow.trim();
    if (raw.isEmpty) return <String>{};

    final lower = raw.toLowerCase();
    String cap(String s) =>
        s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    final values = <String>{raw, lower, lower.toUpperCase(), cap(lower)};

    // Common aliasing seen in some apps.
    if (lower == 'male') {
      values.addAll({'man', 'Man', 'MAN'});
    } else if (lower == 'female') {
      values.addAll({'woman', 'Woman', 'WOMAN'});
    }

    /// Legacy v1 eligibility heuristic (confirmed keys in production):
    /// - photos must be non-empty
    /// - AND EITHER:
    ///   - profile_completed_on exists
    ///   - OR (compatibility_setted == true AND registration_progress == 'completed')
    values.removeWhere((e) => e.trim().isEmpty);
    return values;
  }

  /// Legacy v1 eligibility heuristic (confirmed keys in production):
  /// - photos must be non-empty
  /// - AND EITHER:
  ///   - profile_completed_on exists
  ///   - OR (compatibility_setted == true AND registration_progress == 'completed')
  bool _isLegacyV1Eligible(Map<String, dynamic> data) {
    final photos = data['photos'];
    final hasPhotos = photos is List && photos.isNotEmpty;
    if (!hasPhotos) return false;

    final hasProfileCompletedOn = data['profile_completed_on'] != null;

    final compatOk = data['compatibility_setted'] == true;

    final reg = data['registration_progress']?.toString().toLowerCase();
    final regOk = reg == 'completed';

    return hasProfileCompletedOn || (compatOk && regOk);
  }

  /// Assumption based on Nexus 1.0: dating profiles live in users collection.
  /// We filter on gender at query-level and apply the rest in-memory safely.
  Future<List<DatingProfile>> search({
    required String genderToShow,
    required DatingSearchFilters filters,
    int limit = 60,
  }) async {
    // v2 rule: only VERIFIED users appear in the dating pool.
    // v1 legacy users may not have dating.verificationStatus yet, so we also include
    // docs where that field is null to avoid breaking existing users.
    // v2 rule: only VERIFIED users appear in the dating pool.
    // v1 legacy users may not have dating.verificationStatus yet, so we also include
    // docs where that field is null to avoid breaking existing users.
    //
    // IMPORTANT: Firestore equality matches are case-sensitive + exact. Query common
    // variants so v2 users can see v1 users even if gender casing differs.
    final genders = _genderQueryValues(genderToShow);
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final g in genders) {
      final verifiedQ = _fs
          .collection('users')
          .where('gender', isEqualTo: g)
          .where('dating.verificationStatus', isEqualTo: 'verified')
          .limit(limit);

      final legacyQ = _fs
          .collection('users')
          .where('gender', isEqualTo: g)
          .limit(limit);
      futures.addAll([verifiedQ.get(), legacyQ.get()]);
    }

    final snaps = await Future.wait(futures);
    final combined = <String, DatingProfile>{};
    for (final s in snaps) {
      for (final d in s.docs) {
        final data = d.data();
        // Enforce: disabled accounts are NOT visible in search results.
        if (_isDisabledUserDoc(data)) continue;
        final dating = data['dating'];
        final status =
            (dating is Map<String, dynamic>)
                ? (dating['verificationStatus'] ?? '').toString().toLowerCase()
                : '';

        final isV2Verified = status == 'verified';

        // A3: include legacy v1 users only if their v1 dating profile looks completed.
        if (!isV2Verified && !_isLegacyV1Eligible(data)) {
          continue;
        }

        combined[d.id] = DatingProfile.fromFirestore(d.id, data);
      }
    }

    final results =
        combined.values
            .where((p) => p.age >= filters.minAge && p.age <= filters.maxAge)
            .toList();

    // Apply remaining filters in-memory (safe + flexible)
    bool ok(String? value, String? selected) {
      if (selected == null || selected.trim().isEmpty) return true;
      if (selected.toLowerCase().contains('any')) return true;
      return (value ?? '').toLowerCase() == selected.toLowerCase();
    }

    return results.where((p) {
      final countryOk = ok(p.country, filters.countryOfResidence);
      final incomeOk = ok(
        p.regularSourceOfIncome,
        filters.regularSourceOfIncome,
      );
      final longOk = ok(p.longDistance, filters.longDistance);
      final maritalOk = ok(p.maritalStatus, filters.maritalStatus);
      final kidsOk = ok(p.haveKids, filters.hasKids);
      final genoOk = ok(p.genotype, filters.genotype);

      return countryOk && incomeOk && longOk && maritalOk && kidsOk && genoOk;
    }).toList();
  }
}
