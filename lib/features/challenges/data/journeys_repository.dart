import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bootstrap/firebase_ready_provider.dart';
import '../domain/journey.dart';

final journeysRepositoryProvider = Provider<JourneysRepository>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ready ? FirebaseFirestore.instance : null;
  return JourneysRepository(fs);
});

class JourneysRepository {
  final FirebaseFirestore? _firestore;

  JourneysRepository(this._firestore);

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));

  Future<List<Journey>> fetchJourneys({required int limit}) async {
    if (_firestore == null) return const [];

    final snap =
        await _fs.collection('journeys').orderBy('title').limit(limit).get();

    return snap.docs.map((d) => Journey.fromMap(d.id, d.data())).toList();
  }
}
