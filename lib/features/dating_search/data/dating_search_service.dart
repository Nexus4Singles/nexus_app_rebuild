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

  /// Assumption based on Nexus 1.0: dating profiles live in users collection.
  /// We filter on gender at query-level and apply the rest in-memory safely.
  Future<List<DatingProfile>> search({
    required String genderToShow,
    required DatingSearchFilters filters,
    int limit = 60,
  }) async {
    final q = _fs
        .collection('users')
        .where('gender', isEqualTo: genderToShow)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    final snap = await q.get();

    final results =
        snap.docs
            .map((d) => DatingProfile.fromFirestore(d.id, d.data()))
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
