import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import '../domain/dating_profile.dart';
import '../domain/dating_search_filters.dart';
import '../domain/dating_search_result.dart';

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
    final accountStatus =
        (data['accountStatus'] ?? '').toString().toLowerCase();
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
    String cap(String s) =>
        s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

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

  /// Firestore equality on `registration_progress` is case-sensitive + exact-match.
  /// v1 may store variants like "completed" / "Completed".
  Set<String> _registrationProgressQueryValues(String progress) {
    final raw = progress.trim();
    if (raw.isEmpty) return <String>{};

    final lower = raw.toLowerCase();
    String cap(String s) =>
        s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    final values = <String>{raw, lower, lower.toUpperCase(), cap(lower)};
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

    final reg =
        (data['registration_progress'] ?? '').toString().toLowerCase().trim();
    final regOk = reg == 'completed';
    if (!regOk) return false;

    // v1 had profiles that were usable even when is_verified=false.
    // For now, treat (photos + registration_progress=completed) as sufficient.
    return true;
  }

  // ---------------------------------------------------------------------------
  // Normalization + v1-compatible matching helpers (single definitions only)
  // ---------------------------------------------------------------------------

  String _normBasic(String? v) =>
      (v ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _normAlnum(String? v) {
    final s = _normBasic(v);
    return s
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _selectedMeansAny(String? selected) {
    final s = _normBasic(selected);
    if (s.isEmpty) return true;

    const anyTokens = <String>[
      'any',
      'anyone',
      'any level',
      'any status',
      "i don't mind",
      'i dont mind',
      'dont mind',
      'not compulsory',
      'no preference',
      'prefer not to say',
      'rather not say',
      'not specified',
      'select',
      'all',
    ];

    for (final t in anyTokens) {
      if (s == t || s.contains(t)) return true;
    }

    return false;
  }

  String _canonYesNo(String? v) {
    final s = _normAlnum(v);
    if (s.isEmpty) return '';

    if (s == 'yes' || s == 'y' || s == 'true' || s == '1') return 'yes';
    if (s == 'no' || s == 'n' || s == 'false' || s == '0') return 'no';

    if (s.contains('yes')) return 'yes';
    if (s.contains('no')) return 'no';

    return s;
  }

  String _canonCountry(String? v) {
    final s = _normAlnum(v);
    if (s.isEmpty) return '';

    const ukAliases = <String>{
      'uk',
      'u k',
      'united kingdom',
      'great britain',
      'britain',
      'england',
      'scotland',
      'wales',
      'northern ireland',
    };
    if (ukAliases.contains(s)) return 'united kingdom';

    const usAliases = <String>{
      'usa',
      'us',
      'u s',
      'united states',
      'united states of america',
    };
    if (usAliases.contains(s)) return 'united states';

    return s;
  }

  String _canonGenotype(String? v) {
    final s = _normAlnum(v).replaceAll(' ', '');
    if (s.isEmpty) return '';

    // tolerate UI strings like "AA only"
    if (s.contains('aa')) return 'aa';
    if (s.contains('as')) return 'as';
    if (s.contains('ss')) return 'ss';
    if (s.contains('ac')) return 'ac';
    if (s.contains('sc')) return 'sc';

    return _normAlnum(v);
  }

  String _canonMarital(String? v) {
    final s = _normAlnum(v);
    if (s.isEmpty) return '';

    // v1 commonly stored this string; treat it as single.
    if (s.contains('never') && s.contains('married')) return 'single';

    if (s.contains('single')) return 'single';
    if (s.contains('married')) return 'married';
    if (s.contains('divorc')) return 'divorced';
    if (s.contains('widow')) return 'widowed';
    if (s.contains('separat')) return 'separated';

    return s;
  }

  String _canonKids(String? v) {
    final s = _normAlnum(v);
    if (s.isEmpty) return '';

    // Let the existing "Any" logic short-circuit at the matcher level,
    // but still normalize common label variants here.
    if (s == 'no kids' || s == 'no kid' || s == 'no children' || s == 'none')
      return 'no';
    if (s == 'no') return 'no';

    if (s == 'has kids' ||
        s == 'have kids' ||
        s == 'with kids' ||
        s == 'with children' ||
        s == 'yes kids') {
      return 'yes';
    }
    if (s == 'yes') return 'yes';

    return s;
  }

  String _canonEducation(String? v) {
    final s = _normAlnum(v);
    if (s.isEmpty) return '';

    if (s.contains('phd') || s.contains('doctor')) return 'phd';
    if (s.contains('master') || s.contains('msc') || s.contains('mba'))
      return 'masters';
    if (s.contains('postgraduate')) return 'graduate';
    if (s.contains('graduate')) return 'graduate';

    if (s.contains('undergraduate') ||
        s.contains('bsc') ||
        s.contains('ba') ||
        s.contains('beng') ||
        s.contains('b eng') ||
        s.contains('hnd') ||
        s.contains('ond') ||
        s.contains('degree')) {
      return 'undergraduate';
    }

    if (s.contains('secondary') || s.contains('high school'))
      return 'secondary';
    if (s.contains('primary')) return 'primary';

    return s;
  }

  String _canonIncome(String? v) {
    final s = _normAlnum(v);
    if (s.isEmpty) return '';

    if (s.contains('salary') || s.contains('employ')) return 'salary';
    if (s.contains('business')) return 'business';
    if (s.contains('self') && s.contains('employ')) return 'self employed';
    if (s.contains('student')) return 'student';
    if (s == 'none' ||
        s == 'no' ||
        s.contains('no income') ||
        s.contains('unemploy')) {
      return 'none';
    }

    return s;
  }

  bool _eqCanon(
    String? value,
    String? selected,
    String Function(String?) canon,
  ) {
    if (_selectedMeansAny(selected)) return true;
    final a = canon(value);
    final b = canon(selected);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b;
  }

  bool _matchCountry(DatingProfile p, DatingSearchFilters f) {
    final selected = f.countryOfResidence;

    // If user didn't pick a country (or picked "Any"), don't filter by country.
    if (_selectedMeansAny(selected)) return true;

    // Special case: "Others" means "countries NOT in our predefined list".
    final selNorm = _normBasic(selected);
    final isOthers = selNorm == 'others' || selNorm.startsWith('other');

    if (isOthers) {
      final pc = _canonCountry(p.country);
      if (pc.isEmpty) return false;

      final options = f.countryOptions ?? const <String>[];
      final canonSet = <String>{};

      for (final o in options) {
        final on = _normBasic(o);
        if (on.isEmpty) continue;
        if (on == 'others' || on.startsWith('other')) continue;
        final oc = _canonCountry(o);
        if (oc.isNotEmpty) canonSet.add(oc);
      }

      // Keep only profiles whose country isn't in the main list.
      return !canonSet.contains(pc);
    }

    // Normal country match
    return _eqCanon(p.country, selected, _canonCountry);
  }

  bool _matchEducation(DatingProfile p, DatingSearchFilters f) =>
      _eqCanon(p.educationLevel, f.educationLevel, _canonEducation);

  bool _matchIncome(DatingProfile p, DatingSearchFilters f) =>
      _eqCanon(p.regularSourceOfIncome, f.regularSourceOfIncome, _canonIncome);

  bool _matchDistance(DatingProfile p, DatingSearchFilters f) =>
      _eqCanon(p.longDistance, f.longDistance, _canonYesNo);

  bool _matchMarital(DatingProfile p, DatingSearchFilters f) =>
      _eqCanon(p.maritalStatus, f.maritalStatus, _canonMarital);

  bool _matchKids(DatingProfile p, DatingSearchFilters f) =>
      _eqCanon(p.haveKids, f.hasKids, _canonKids);

  bool _matchGenotype(DatingProfile p, DatingSearchFilters f) =>
      _eqCanon(p.genotype, f.genotype, _canonGenotype);

  List<DatingProfile> _step(
    List<DatingProfile> list,
    String label,
    bool Function(DatingProfile) keep, {
    String? selectedRaw,
    String? selectedCanon,
    String Function(DatingProfile)? sampleCanon,
  }) {
    final before = list.length;
    final out = list.where(keep).toList();

    if (kDebugMode) {
      final sr = (selectedRaw ?? '').toString();
      final sc = (selectedCanon ?? '').toString();

      String sampleFrom(List<DatingProfile> xs) {
        if (xs.isEmpty) return '';
        if (sampleCanon == null) return '';
        try {
          return sampleCanon(xs.first);
        } catch (_) {
          return '';
        }
      }

      final sampleBefore = sampleFrom(list);
      final sampleAfter = sampleFrom(out);

      final parts = <String>[
        '[DatingSearchService][Step] $label: $before -> ${out.length}',
      ];
      if (sr.isNotEmpty) parts.add('selected="$sr"');
      if (sc.isNotEmpty) parts.add('canon="$sc"');

      // If this step killed the list, show what the *candidates* looked like BEFORE filtering.
      if (before > 0 && out.isEmpty && sampleBefore.isNotEmpty) {
        parts.add('sampleBefore="$sampleBefore"');
      } else if (out.isNotEmpty && sampleAfter.isNotEmpty) {
        parts.add('sampleAfter="$sampleAfter"');
      }

      // ignore: avoid_print
      print(parts.join(' | '));
    }

    return out;
  }

  /// Assumption based on Nexus 1.0: dating profiles live in users collection.
  /// We filter on gender at query-level and apply the rest in-memory safely.
  Future<DatingSearchResult> search({
    required String genderToShow,
    required DatingSearchFilters filters,
    int limit = kDebugMode ? 1000 : 60,
  }) async {
    final genders = _genderQueryValues(genderToShow);
    if (genders.isEmpty)
      return const DatingSearchResult(items: <DatingProfile>[]);

    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final g in genders) {
      final verifiedQ = _fs
          .collection('users')
          .where('gender', isEqualTo: g)
          .where('dating.verificationStatus', isEqualTo: 'verified')
          .limit(limit);

      final regValues = _registrationProgressQueryValues('completed');

      // v2 verified query (kept as-is)
      futures.add(verifiedQ.get());

      // v1 legacy query: only pull registration_progress == completed (case variants)
      for (final reg in regValues) {
        final legacyQ = _fs
            .collection('users')
            .where('gender', isEqualTo: g)
            .where('registration_progress', isEqualTo: reg)
            .limit(limit);

        futures.add(legacyQ.get());
      }
    }

    final snaps = await Future.wait(futures);

    final combined = <String, DatingProfile>{};
    int seenDocs = 0;
    int skippedDisabled = 0;
    int includedV2Verified = 0;
    int includedLegacyEligible = 0;
    int skippedLegacyIneligible = 0;
    final rejectedSamples = <Map<String, dynamic>>[];

    for (final s in snaps) {
      for (final d in s.docs) {
        final data = d.data();

        seenDocs++;

        // Enforce: disabled accounts are NOT visible in search results.
        if (_isDisabledUserDoc(data)) {
          skippedDisabled++;
          continue;
        }

        final dating = data['dating'];
        final status =
            (dating is Map<String, dynamic>)
                ? (dating['verificationStatus'] ?? '').toString().toLowerCase()
                : '';

        final isV2Verified = status == 'verified';

        // Include legacy v1 users only if their v1 dating profile looks completed.
        if (!isV2Verified) {
          final ok = _isLegacyV1Eligible(data);
          if (!ok) {
            skippedLegacyIneligible++;
            if (rejectedSamples.length < 3) {
              rejectedSamples.add({
                'uid': d.id,
                'hasPhotos':
                    (data['photos'] is List) &&
                    (data['photos'] as List).isNotEmpty,
                'photosLen':
                    (data['photos'] is List)
                        ? (data['photos'] as List).length
                        : null,
                'profile_completed_on': data['profile_completed_on'],
                'registration_progress': data['registration_progress'],
                'compatibility_setted':
                    data['compatibility_setted'] ??
                    data['compatibilitySetted'] ??
                    data['compatibilitysetted'],
                'is_verified': data['is_verified'],
              });
            }
            continue;
          }
          includedLegacyEligible++;
        } else {
          includedV2Verified++;
        }

        combined[d.id] = DatingProfile.fromFirestore(d.id, data);
      }
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('[DatingSearchService] combined=${combined.length} (pre-age)');
      if (combined.isNotEmpty) {
        final p0 = combined.values.first;
        // ignore: avoid_print
        print(
          '[DatingSearchService] pre-age sample: age=${p0.age}, '
          'country="${p0.country}", edu="${p0.educationLevel}", '
          'income="${p0.regularSourceOfIncome}", distance="${p0.longDistance}", '
          'marital="${p0.maritalStatus}", kids="${p0.haveKids}", geno="${p0.genotype}"',
        );
      }
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[DatingSearchService] querySummary: seenDocs=$seenDocs, '
        'combinedUnique=${combined.length}, '
        'skippedDisabled=$skippedDisabled, '
        'v2Verified=$includedV2Verified, '
        'legacyEligible=$includedLegacyEligible, '
        'legacyRejected=$skippedLegacyIneligible',
      );
      if (rejectedSamples.isNotEmpty) {
        // ignore: avoid_print
        print(
          '[DatingSearchService] legacyRejectedSamples=' +
              rejectedSamples.toString(),
        );
      }
    }

    // Age filter first
    final afterAge =
        combined.values
            .where((p) => p.age >= filters.minAge && p.age <= filters.maxAge)
            .toList();

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[DatingSearchService] afterAge=${afterAge.length} '
        'filters: country="${filters.countryOfResidence}", '
        'edu="${filters.educationLevel}", income="${filters.regularSourceOfIncome}", '
        'distance="${filters.longDistance}", marital="${filters.maritalStatus}", '
        'kids="${filters.hasKids}", geno="${filters.genotype}"',
      );
      if (afterAge.isNotEmpty) {
        final p = afterAge.first;
        // ignore: avoid_print
        print(
          '[DatingSearchService] sample: country="${p.country}", '
          'income="${p.regularSourceOfIncome}", distance="${p.longDistance}", '
          'marital="${p.maritalStatus}", kids="${p.haveKids}", geno="${p.genotype}"',
        );
      }
    }

    // Stepwise filtering (so we can see which filter drops results)
    var current = afterAge;

    // Capture the *first* filter that turns results to zero (non-random UI hint).
    String? emptyHint;

    void captureEmptyHint(String label, String? selected) {
      if (emptyHint != null) return;
      if (_selectedMeansAny(selected)) return;
      final s = (selected ?? '').trim();
      if (s.isEmpty) return;
      emptyHint = '$label: $s';
    }

    current = _step(
      current,
      'country',
      (p) => _matchCountry(p, filters),
      selectedRaw: filters.countryOfResidence,
      selectedCanon: _canonCountry(filters.countryOfResidence),
      sampleCanon: (p) => _canonCountry(p.country),
    );
    if (current.isEmpty) {
      captureEmptyHint('Country', filters.countryOfResidence);
      return DatingSearchResult(items: current, emptyHint: emptyHint);
    }

    current = _step(
      current,
      'education',
      (p) => _matchEducation(p, filters),
      selectedRaw: filters.educationLevel,
      selectedCanon: _canonEducation(filters.educationLevel),
      sampleCanon: (p) => _canonEducation(p.educationLevel),
    );
    if (current.isEmpty) {
      captureEmptyHint('Education', filters.educationLevel);
      return DatingSearchResult(items: current, emptyHint: emptyHint);
    }

    current = _step(
      current,
      'income',
      (p) => _matchIncome(p, filters),
      selectedRaw: filters.regularSourceOfIncome,
      selectedCanon: _canonIncome(filters.regularSourceOfIncome),
      sampleCanon: (p) => _canonIncome(p.regularSourceOfIncome),
    );
    if (current.isEmpty) {
      captureEmptyHint('Income', filters.regularSourceOfIncome);
      return DatingSearchResult(items: current, emptyHint: emptyHint);
    }

    current = _step(
      current,
      'distance',
      (p) => _matchDistance(p, filters),
      selectedRaw: filters.longDistance,
      selectedCanon: _canonYesNo(filters.longDistance),
      sampleCanon: (p) => _canonYesNo(p.longDistance),
    );
    if (current.isEmpty) {
      captureEmptyHint('Long distance', filters.longDistance);
      return DatingSearchResult(items: current, emptyHint: emptyHint);
    }

    current = _step(
      current,
      'marital',
      (p) => _matchMarital(p, filters),
      selectedRaw: filters.maritalStatus,
      selectedCanon: _canonMarital(filters.maritalStatus),
      sampleCanon: (p) => _canonMarital(p.maritalStatus),
    );
    if (current.isEmpty) {
      captureEmptyHint('Marital status', filters.maritalStatus);
      return DatingSearchResult(items: current, emptyHint: emptyHint);
    }

    current = _step(
      current,
      'kids',
      (p) => _matchKids(p, filters),
      selectedRaw: filters.hasKids,
      selectedCanon: _canonKids(filters.hasKids),
      sampleCanon: (p) => _canonKids(p.haveKids),
    );
    if (current.isEmpty) {
      captureEmptyHint('Marital status', filters.maritalStatus);
      return DatingSearchResult(items: current, emptyHint: emptyHint);
    }

    current = _step(
      current,
      'genotype',
      (p) => _matchGenotype(p, filters),
      selectedRaw: filters.genotype,
      selectedCanon: _canonGenotype(filters.genotype),
      sampleCanon: (p) => _canonGenotype(p.genotype),
    );

    if (kDebugMode) {
      // ignore: avoid_print
      print('[DatingSearchService] filtered=${current.length}');
    }

    return DatingSearchResult(items: current, emptyHint: emptyHint);
  }
}
