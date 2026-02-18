import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';
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

    // Do NOT exclude admin users from searching; only exclude them from appearing in other users' results.
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
  /// - AND registration_progress == 'completed'
  /// - AND compatibility_setted == true (compatibility quiz completed)
  bool _isLegacyV1Eligible(Map<String, dynamic> data) {
    final photos = data['photos'];
    final hasPhotos = photos is List && photos.isNotEmpty;
    if (!hasPhotos) return false;

    final reg =
        (data['registration_progress'] ?? '').toString().toLowerCase().trim();
    final regOk = reg == 'completed';
    if (!regOk) return false;

    // v2 requirement: v1 users must have completed compatibility quiz
    final compatibilitySetted = data['compatibility_setted'] == true;
    if (!compatibilitySetted) return false;

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
      final profileCountry = p.country;
      if (profileCountry == null || profileCountry.isEmpty) return false;

      final options = f.countryOptions ?? const <String>[];
      final countriesInList = <String>{};

      for (final o in options) {
        final on = _normBasic(o);
        if (on.isEmpty) continue;
        if (on == 'others' || on.startsWith('other')) continue;
        countriesInList.add(o); // Store exact value
      }

      // Keep only profiles whose country isn't in the main list.
      return !countriesInList.contains(profileCountry);
    }

    // Exact match (both should be properly capitalized)
    return p.country == selected;
  }

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

  /// Quick check to see if any profiles exist for a country without doing full search
  /// Returns true if at least one profile exists in the country (for any gender)
  Future<bool> countryHasProfiles({required String country}) async {
    if (country.isEmpty) return false;

    // Canonicalize the country name to match stored format
    final canonCountry = _canonCountry(country);
    if (canonCountry.isEmpty) return false;

    final genders = {
      'male',
      'Male',
      'female',
      'Female',
      'man',
      'Man',
      'woman',
      'Woman',
    };

    try {
      // Quick check: look for ANY profile in this country (v2 or v1)
      for (final g in genders) {
        // Check v2 verified profiles
        final v2Snap =
            await _fs
                .collection('users')
                .where('gender', isEqualTo: g)
                .where('dating.verificationStatus', isEqualTo: 'verified')
                .where('dating.countryOfResidence', isEqualTo: canonCountry)
                .limit(1)
                .get();

        if (v2Snap.docs.isNotEmpty) return true;

        // Check v1 legacy profiles
        final v1Snap =
            await _fs
                .collection('users')
                .where('gender', isEqualTo: g)
                .where('registration_progress', isEqualTo: 'completed')
                .where('country', isEqualTo: canonCountry)
                .limit(1)
                .get();

        if (v1Snap.docs.isNotEmpty) return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[DatingSearchService] Error checking country: $e');
      }
      return false;
    }
  }

  /// Assumption based on Nexus 1.0: dating profiles live in users collection.
  /// We filter on gender at query-level and apply the rest in-memory safely.
  ///
  /// [offset]: Number of filtered profiles to skip (for pagination)
  /// [limit]: Number of filtered profiles per page
  ///
  /// IMPORTANT: Offset is applied AFTER all filtering (age, country, distance, etc.),
  /// not at the Firestore query level. This ensures that pagination always returns
  /// profiles that match the saved preferences and age bracket.
  ///
  /// Search strategy:
  /// 1. Query Firestore by gender + country (server-side only)
  /// 2. Apply in-memory filters step-by-step (age → country → distance → marital → kids → genotype)
  /// 3. If results are empty at any step, fall back to age-bracket-only profiles
  /// 4. Apply offset/limit to the fully-filtered results
  /// 5. Return appropriate message for UI to display
  Future<DatingSearchResult> search({
    required String genderToShow,
    required DatingSearchFilters filters,
    int offset = 0,
    int limit = 20,
  }) async {
    final genders = _genderQueryValues(genderToShow);
    if (genders.isEmpty)
      return const DatingSearchResult(items: <DatingProfile>[]);

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[DatingSearchService] SEARCH START: age=${filters.minAge}-${filters.maxAge}, '
        'country=${filters.countryOfResidence}, distance=${filters.longDistance}, '
        'marital=${filters.maritalStatus}, kids=${filters.hasKids}',
      );
    }

    // Optimization: Dynamically set Firestore query limit based on pagination offset
    // This reduces unnecessary re-fetching on subsequent pages
    // Calculate how many profiles we need to fetch to serve offset + limit
    // Add 20% buffer for profiles that will be filtered out by age/preferences
    final fsLimit = ((offset + limit) * 1.2).ceil().clamp(500, 10000).toInt();

    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final g in genders) {
      // Build v2 verified query with server-side filters
      var verifiedQ = _fs
          .collection('users')
          .where('gender', isEqualTo: g)
          .where('dating.verificationStatus', isEqualTo: 'verified');

      // Apply server-side filters before fetching
      if (!_selectedMeansAny(filters.countryOfResidence)) {
        final country =
            filters.countryOfResidence; // Use exact value (already capitalized)
        if (country != null && country.isNotEmpty) {
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              '[DatingSearchService] V2 query filter: country="$country" (exact match)',
            );
          }
          verifiedQ = verifiedQ.where(
            'dating.countryOfResidence',
            isEqualTo: country,
          );
        }
      }

      // IMPORTANT: Don't filter on optional fields (marital, kids, distance, genotype) at server level
      // because v1 profiles may not have these fields, causing Firestore to return 0 results.
      // Filter these in-memory after fetching by country and gender.

      // NOTE: We fetch extra profiles to account for in-memory filtering (age, distance, etc.)
      // offset/limit will be applied AFTER all in-memory filtering is complete
      // NOTE: Removed orderBy to avoid composite index requirement - will sort in-memory instead
      verifiedQ = verifiedQ.limit(fsLimit);

      final regValues = _registrationProgressQueryValues('completed');

      // v2 verified query (with filters applied)
      futures.add(verifiedQ.get());

      // v1 legacy query: only filter by gender, registration_progress, and country
      for (final reg in regValues) {
        var legacyQ = _fs
            .collection('users')
            .where('gender', isEqualTo: g)
            .where('registration_progress', isEqualTo: reg);

        // Apply country filter to legacy profiles
        if (!_selectedMeansAny(filters.countryOfResidence)) {
          final country =
              filters
                  .countryOfResidence; // Use exact value (already capitalized)
          if (country != null && country.isNotEmpty) {
            if (kDebugMode) {
              // ignore: avoid_print
              print(
                '[DatingSearchService] V1 query filter: country="$country" (exact match)',
              );
            }
            // V1 legacy profiles store country in location.country with capitalization
            legacyQ = legacyQ.where('location.country', isEqualTo: country);
          }
        }

        // IMPORTANT: Don't filter on optional fields (marital, kids, distance, genotype) at server level
        // because v1 profiles may not have these fields, causing Firestore to return 0 results.
        // Filter these in-memory after fetching by country and gender.

        // NOTE: We fetch extra profiles to account for in-memory filtering (age, distance, etc.)
        // offset/limit will be applied AFTER all in-memory filtering is complete
        // NOTE: Removed orderBy to avoid composite index requirement - will sort in-memory instead
        legacyQ = legacyQ.limit(fsLimit);
        futures.add(legacyQ.get());
      }
    }

    final snaps = await Future.wait(futures);

    if (kDebugMode) {
      int totalSnapDocs = 0;
      for (final s in snaps) {
        totalSnapDocs += s.docs.length;
      }
      // ignore: avoid_print
      print(
        '[DatingSearchService] Firestore query returned $totalSnapDocs total documents from ${snaps.length} queries',
      );

      // If 0 documents, do a diagnostic query to see if ANY profiles exist
      if (totalSnapDocs == 0) {
        final diagnosticSnap =
            await _fs
                .collection('users')
                .where('gender', isEqualTo: 'female')
                .limit(5)
                .get();
        // ignore: avoid_print
        print(
          '[DatingSearchService] DIAGNOSTIC: Querying users with gender=female found ${diagnosticSnap.docs.length} documents',
        );
        for (int i = 0; i < diagnosticSnap.docs.length && i < 2; i++) {
          final data = diagnosticSnap.docs[i].data();
          final dating = data['dating'];
          final profile = data['profile'];
          // ignore: avoid_print
          print(
            '[DatingSearchService] SAMPLE DOC: uid=${diagnosticSnap.docs[i].id}, '
            'dating.country=${dating is Map ? dating['countryOfResidence'] : 'N/A'}, '
            'profile.country=${profile is Map ? profile['country'] : 'N/A'}, '
            'flat country=${data['country']}, '
            'dating.verif=${dating is Map ? dating['verificationStatus'] : 'N/A'}',
          );
        }
      }
    }

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

        // DEBUG: Log first 3 documents to see actual field structure
        if (seenDocs <= 3 && kDebugMode) {
          final dating = data['dating'];
          final profile = data['profile'];
          // ignore: avoid_print
          print(
            '[DatingSearchService] Doc #$seenDocs structure: '
            'dating.countryOfResidence=${dating is Map ? dating['countryOfResidence'] : 'N/A'}, '
            'profile.country=${profile is Map ? profile['country'] : 'N/A'}, '
            'country=${data['country']}, '
            'uid=${d.id}',
          );
        }

        // Enforce: disabled accounts are NOT visible in search results.
        // Exclude admin profiles from appearing in search results (but allow them to search)
        if (_isDisabledUserDoc(data)) {
          skippedDisabled++;
          continue;
        }
        final isAdmin = data['isAdmin'] == true;
        // Exclude admin profiles from appearing in search results for other users
        // (but allow current admin user to see their own profile if needed)
        // If you want admins to see themselves, remove this check
        if (isAdmin) {
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

    // Sort combined profiles by creation date (most recent first)
    // Three-tier sort:
    // 1. Profiles WITH valid createdAt (v2 + v1 with recent dates), sorted newest first
    // 2. Profiles WITHOUT createdAt (old v1 legacy), appear last
    // Done in-memory instead of at Firestore level to avoid composite index requirement
    final sortedProfiles =
        combined.values.toList()..sort((a, b) {
          // Check if each profile has a valid (non-epoch) creation date
          final aIsEpoch = a.createdAt.millisecondsSinceEpoch == 0;
          final bIsEpoch = b.createdAt.millisecondsSinceEpoch == 0;

          // If one has a real date and the other is epoch, the one with a date comes first
          if (aIsEpoch && !bIsEpoch)
            return 1; // a is old v1, b has date -> b first
          if (!aIsEpoch && bIsEpoch)
            return -1; // a has date, b is old v1 -> a first

          // If both have dates or both are epoch, sort by date descending (newest first)
          return b.createdAt.compareTo(a.createdAt);
        });

    // Age filter first (always applied, even in unlimited mode)
    final afterAge =
        sortedProfiles
            .where((p) => p.age >= filters.minAge && p.age <= filters.maxAge)
            .toList();

    if (kDebugMode && combined.isNotEmpty) {
      // Log creation dates to verify newest profiles are first
      final firstFew = combined.values.take(5).toList();
      final creationDates = firstFew
          .map((p) => '${p.name}(${p.createdAt})')
          .join(', ');
      // ignore: avoid_print
      print(
        '[DatingSearchService] Profile creation order (newest first): $creationDates',
      );
    }

    if (kDebugMode) {
      // Debug: Show age range being filtered
      final agesInCombined = combined.values.map((p) => p.age).toList()..sort();
      final minAgeInCombined =
          agesInCombined.isNotEmpty ? agesInCombined.first : 0;
      final maxAgeInCombined =
          agesInCombined.isNotEmpty ? agesInCombined.last : 0;

      // ignore: avoid_print
      print(
        '[DatingSearchService] AGE FILTER: minAge=${filters.minAge}, maxAge=${filters.maxAge} '
        '| combined has ages: $minAgeInCombined - $maxAgeInCombined | Result: ${afterAge.length} profiles',
      );
      if (afterAge.isNotEmpty) {
        final agesInAfterAge = afterAge.map((p) => p.age).toList()..sort();
        // ignore: avoid_print
        print(
          '[DatingSearchService] afterAge ages: ${agesInAfterAge.first} - ${agesInAfterAge.last}',
        );
      }
      if (afterAge.isNotEmpty && afterAge.length < 20) {
        final sampleAges = afterAge
            .map((p) => '${p.name}(${p.age})')
            .join(', ');
        // ignore: avoid_print
        print(
          '[DatingSearchService] Sample profiles after age filter: $sampleAges',
        );
      }
    }

    // CRITICAL: If no profiles in entire age bracket, stop here - cannot fall back further
    if (afterAge.isEmpty) {
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[DatingSearchService] NO PROFILES IN AGE BRACKET: age range ${filters.minAge}-${filters.maxAge} has no profiles.',
        );
      }
      return DatingSearchResult(
        items: [],
        emptyHint:
            'No profiles found in your selected age bracket (${filters.minAge}-${filters.maxAge}). '
            'Try expanding your age range.',
        noProfilesInCountry: false,
      );
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[DatingSearchService] afterAge=${afterAge.length} '
        'filters: country="${filters.countryOfResidence}", '
        'distance="${filters.longDistance}", marital="${filters.maritalStatus}", '
        'kids="${filters.hasKids}", geno="${filters.genotype}"',
      );
      if (afterAge.isNotEmpty) {
        final p = afterAge.first;
        // ignore: avoid_print
        print(
          '[DatingSearchService] sample: country="${p.country}", '
          'distance="${p.longDistance}", '
          'marital="${p.maritalStatus}", kids="${p.haveKids}", geno="${p.genotype}"',
        );
      }
    }

    // Stepwise filtering (so we can see which filter drops results)
    var current = afterAge;

    // Capture the *first* filter that turns results to zero (non-random UI hint).
    String? emptyHint;
    bool noProfilesInCountry = false;

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
      // If we have 0 results after country filter, no profiles exist in this country
      noProfilesInCountry = true;
      return DatingSearchResult(
        items: current,
        emptyHint: emptyHint,
        noProfilesInCountry: noProfilesInCountry,
      );
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
      // Fallback to age-only when preferences exhausted
      if (afterAge.isNotEmpty) {
        return DatingSearchResult(
          items: afterAge,
          emptyHint:
              'No more profiles matching your preferences. '
              'Showing other profiles in your age bracket.',
          noProfilesInCountry: false,
        );
      }
      // No profiles even in age bracket
      return DatingSearchResult(
        items: current,
        emptyHint: emptyHint,
        noProfilesInCountry: false,
      );
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
      // Fallback to age-only when preferences exhausted
      if (afterAge.isNotEmpty) {
        return DatingSearchResult(
          items: afterAge,
          emptyHint:
              'No more profiles matching your preferences. '
              'Showing other profiles in your age bracket.',
          noProfilesInCountry: false,
        );
      }
      // No profiles even in age bracket
      return DatingSearchResult(
        items: current,
        emptyHint: emptyHint,
        noProfilesInCountry: false,
      );
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
      captureEmptyHint('Kids preference', filters.hasKids);
      // Fallback to age-only when preferences exhausted
      if (afterAge.isNotEmpty) {
        return DatingSearchResult(
          items: afterAge,
          emptyHint:
              'No more profiles matching your preferences. '
              'Showing other profiles in your age bracket.',
          noProfilesInCountry: false,
        );
      }
      // No profiles even in age bracket
      return DatingSearchResult(
        items: current,
        emptyHint: emptyHint,
        noProfilesInCountry: false,
      );
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
      // Diagnostic: show genotype breakdown if filtered to 0
      if (current.isEmpty &&
          afterAge.isNotEmpty &&
          !_selectedMeansAny(filters.genotype)) {
        final genotypeBreakdown = <String, int>{};
        for (final p in afterAge) {
          final g = _canonGenotype(p.genotype);
          genotypeBreakdown[g] = (genotypeBreakdown[g] ?? 0) + 1;
        }
        // ignore: avoid_print
        print(
          '[DatingSearchService] GENOTYPE BREAKDOWN after age filter: $genotypeBreakdown',
        );
        // ignore: avoid_print
        print(
          '[DatingSearchService] Looking for: "${_canonGenotype(filters.genotype)}"',
        );
      }

      // ignore: avoid_print
      print('[DatingSearchService] filtered=${current.length}');
    }

    // If preferences filtering resulted in 0 results, fall back to age-only
    if (current.isEmpty && afterAge.isNotEmpty) {
      // CRITICAL: Only return profiles in the age bracket, nothing else
      // Re-validate that all items in fallback are within age range
      final validatedFallback =
          afterAge
              .where((p) => p.age >= filters.minAge && p.age <= filters.maxAge)
              .toList();

      // Apply offset/limit to age-only fallback results
      final paginatedFallback =
          validatedFallback.skip(offset).take(limit).toList();

      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[DatingSearchService] FALLBACK: Returning age-bracket-only results '
          '(age range: ${filters.minAge}-${filters.maxAge}, offset=$offset, limit=$limit, total available=${validatedFallback.length}, returning=${paginatedFallback.length})',
        );
        if (paginatedFallback.isNotEmpty) {
          final ages = paginatedFallback.map((p) => p.age).join(', ');
          // ignore: avoid_print
          print('[DatingSearchService] FALLBACK ages: $ages');

          // Safety check: validate all returned ages are in range
          final outOfRange =
              paginatedFallback
                  .where(
                    (p) => p.age < filters.minAge || p.age > filters.maxAge,
                  )
                  .toList();
          if (outOfRange.isNotEmpty) {
            // ignore: avoid_print
            print(
              '[DatingSearchService] ERROR: Found out-of-range ages in fallback! ${outOfRange.map((p) => '${p.name}(${p.age})').join(', ')}',
            );
          }
        }
      }

      // Determine hint message based on whether pagination within age bracket is exhausted
      final hint =
          paginatedFallback.isEmpty
              ? 'No more profiles within your age bracket (${filters.minAge}-${filters.maxAge}). '
                  'Expand your search or check back later.'
              : 'No more profiles matching your preferences. '
                  'Showing other profiles in your age bracket.';

      return DatingSearchResult(
        items: paginatedFallback,
        emptyHint: hint,
        noProfilesInCountry: false,
      );
    }

    // Apply offset/limit to the fully-filtered results
    final paginatedResults = current.skip(offset).take(limit).toList();

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[DatingSearchService] FINAL RETURN: (age range: ${filters.minAge}-${filters.maxAge}, offset=$offset, limit=$limit, total available=${current.length}, returning=${paginatedResults.length})',
      );
      if (paginatedResults.isNotEmpty) {
        final ages = paginatedResults.map((p) => p.age).join(', ');
        // ignore: avoid_print
        print('[DatingSearchService] FINAL ages: $ages');

        // Safety check: validate all returned ages are in range
        final outOfRange =
            paginatedResults
                .where((p) => p.age < filters.minAge || p.age > filters.maxAge)
                .toList();
        if (outOfRange.isNotEmpty) {
          // ignore: avoid_print
          print(
            '[DatingSearchService] ERROR: Found out-of-range ages in final results! ${outOfRange.map((p) => '${p.name}(${p.age})').join(', ')}',
          );
        }
      }
    }

    // Return results (either with preferences applied or indication that nothing matches)
    return DatingSearchResult(
      items: paginatedResults,
      emptyHint: emptyHint,
      noProfilesInCountry: false,
    );
  }
}
