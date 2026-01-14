import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'current_user_doc_provider.dart';

final isAdminProvider = Provider<bool>((ref) {
  final docAsync = ref.watch(currentUserDocProvider);
  return docAsync.maybeWhen(
    data: (doc) {
      final roles = (doc?['roles'] is Map) ? doc!['roles'] as Map : null;
      return roles?['isAdmin'] == true;
    },
    orElse: () => false,
  );
});
