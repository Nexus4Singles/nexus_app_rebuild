import 'package:flutter/foundation.dart';
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
  final FirebaseFirestore? _firestore;
  DatingSearchService(this._firestore);

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));

  bool _isDisabledUserDoc(Map<String, dynamic> data) {
    final accountStatus = (data['accountStatus'] ?? '').toString().toLowerCase();
    if (accountStatus == 'disabled') return true;

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'disabled') return true;

    final disabled = data['disabled'];
    if (disabled == true) return true;

    return false;
  }

  /// Firestore equality on `gender` is case-sensitive + exact-match.
  /// v1/v2 may store different casing (e.g. "Female" vs "female").
  /// Query common variants and merge/dedupe results.
  Set<String> _genderQueryValues(String genderToShow) {
    final raw = genderToShow.trim();
    if (raw.isEmpty) return <String>{};

    final lower = raw.toLowerCase();
    String cap(String s) => s.isEmpty ? s : '\${s[0].toUpperCase()}\${s.substring(1)}';

    final values = <String>{raw, lower, lower.toUpperCase(), cap(lower)};

    // Common aliasing seen in some apps.
    if (lower == 'male') {
      values.addAll({'man', 'Man', 'MAN'});
    } else if (lower == 'female') {
      values.addAll({'woman', 'Woman', 'WOMAN'});
    }

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

    final compatOk = (data['compatibility_setted'] == true) ||
        (data['compatibilitySetted'] == true) ||
        (data['compatibilitysetted'] == true);

    final reg = (data['registration_progress'] ?? '').toString().toLowerCase();
    final regOk = reg == 'completed';

    return hasProfileCompletedOn || (compatOk && regOk);
  }

  // ---------------------------------------------------------------------------
  // Normalization + matching helpers (single definitions only)
  // ---------------------------------------------------------------------------

  String _norm(String? v) => (v ?? '').trim().toLowerCase();

  bool _selectedMeansAny(String? selected) {
    final s = _norm(selected);
    if (s.isEmpty) return true;

    // "Any ..." options
    if (s == 'any') return true;
    if (s.contains('any level')) return true;
    if (s.contains('any status')) return true;

    // "Others" should not filter-out everything (acts like Any)
    if (s == 'others' || s.contains('other')) return true;

    // v1-friendly phrases that mean "don’t filter"
    if (s.contains("don't mind") || s.contains('dont mind')) return true;
    if (s.contains('not compulsory')) return true;

    return false;
  }

  bool _eq(String? value, String? selected) {
    if (_selectedMeansAny(selected)) return true;
    return _norm(value) == _norm(selected);
  }

  bool _matchCountry(DatingProfile p, DatingSearchFilters f) {
    return _eq(p.country, f.countryOfResidence);
  }

  // NOTE: DatingProfile currently does NOT expose educationLevel in your codebase.
  // We ignore it here to keep this file compiling and avoid returning zero results.
  bool _matchEducation(DatingProfile p, DatingSearchFilters f) {
    if (_selectedMeansAny(f.educationLevel)) return true;
    return true;
  }

  bool _matchIncome(DatingProfile p, DatingSearchFilters f) {
    return _eq(p.regularSourceOfIncome, f.regularSourceOfIncome);
  }

  bool _matchDistance(DatingProfile p, DatingSearchFilters f) {
    return _eq(p.longDistance, f.longDistance);
  }

  bool _matchMarital(DatingProfile p, DatingSearchFilters f) {
    return _eq(p.maritalStatus, f.maritalStatus);
  }

  bool _matchKids(DatingProfile p, DatingSearchFilters f) {
    return _eq(p.haveKids, f.hasKids);
  }

  bool _matchGenotype(DatingProfile p, DatingSearchFilters f) {
    return _eq(p.genotype, f.genotype);
  }

  /// Assumption based on Nexus 1.0: dating profiles live in users collection.
  /// We filter on gender at query-level and apply the rest in-memory safely.
  Future<List<DatingProfile>> search({
    required String genderToShow,
    required DatingSearchFilters filters,
    int limit = 60,
  }) async {
    final genders = _genderQueryValues(genderToShow);
    if (genders.isEmpty) return const <DatingProfile>[];

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
        final status = (dating is Map<String, dynamic>)
            ? (dating['verificationStatus'] ?? '').toString().toLowerCase()
            : '';

        final isV2Verified = status == 'verified';

        // Include legacy v1 users only if their v1 dating profile looks completed.
        if (!isV2Verified && !_isLegacyV1Eligible(data)) {
          continue;
        }

        combined[d.id] = DatingProfile.fromFirestore(d.id, data);
      }
    }

    // Age filter first
    final afterAge = combined.values
        .where((p) => p.age >= filters.minAge && p.age <= filters.maxAge)
        .toList();

    if (kDebugMode) {
      // ignore: avoid_print
      print('[DatingSearchService] afterAge=\${afterAge.length} '
          'filters: country="\${filters.countryOfResidence}", '
          'edu="\${filters.educationLevel}", income="\${filters.regularSourceOfIncome}", '
          'distance="\${filters.longDistance}", marital="\${filters.maritalStatus}", '
          'kids="\${filters.hasKids}", geno="\${filters.genotype}"');
      if (afterAge.isNotEmpty) {
        final p = afterAge.first;
        // ignore: avoid_print
        print('[DatingSearchService] sample: country="\${p.country}", '
            'income="\${p.regularSourceOfIncome}", distance="\${p.longDistance}", '
            'marital="\${p.maritalStatus}", kids="\${p.haveKids}", geno="\${p.genotype}"');
      }
    }

    final filtered = afterAge.where((p) {
      return _matchCountry(p, filters) &&
          _matchEducation(p, filters) &&
          _matchIncome(p, filters) &&
          _matchDistance(p, filters) &&
          _matchMarital(p, filters) &&
          _matchKids(p, filters) &&
          _matchGenotype(p, filters);
    }).toList();

    if (kDebugMode) {
      // ignore: avoid_print
      print('[DatingSearchService] filtered=\${filtered.length}');
    }

    return filtered;
  }
}
