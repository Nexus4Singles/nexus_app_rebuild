import 'package:flutter_riverpod/flutter_riverpod.dart';

class SafeUser {
  final String firstName;
  final String status;

  const SafeUser({required this.firstName, required this.status});
}

final safeUserProvider = Provider<SafeUser>((ref) {
  return const SafeUser(firstName: 'Ayomide', status: 'Stabilization mode');
});
