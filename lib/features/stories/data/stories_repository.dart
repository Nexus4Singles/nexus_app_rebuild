import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bootstrap/firebase_ready_provider.dart';
import '../domain/story.dart';

final storiesRepositoryProvider = Provider<StoriesRepository>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ready ? FirebaseFirestore.instance : null;
  return StoriesRepository(fs);
});

class StoriesRepository {
  final FirebaseFirestore? _firestore;

  StoriesRepository(this._firestore);

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));

  Future<List<Story>> fetchStories({required int limit}) async {
    if (_firestore == null) return const [];

    final snap =
        await _fs
            .collection('stories')
            .orderBy('publishedAt', descending: true)
            .limit(limit)
            .get();

    return snap.docs.map((d) => Story.fromMap(d.id, d.data())).toList();
  }
}
