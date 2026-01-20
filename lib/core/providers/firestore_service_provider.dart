import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../bootstrap/firestore_instance_provider.dart";
import 'package:nexus_app_min_test/core/services/firestore_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(firestore: ref.watch(firestoreInstanceProvider));
});
