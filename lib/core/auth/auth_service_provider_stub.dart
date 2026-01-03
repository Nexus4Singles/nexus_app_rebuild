import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider((ref) => _AuthServiceStub());

class _AuthServiceStub {
  Future<void> sendPasswordResetEmail(String email) async {}
}
