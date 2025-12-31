import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
