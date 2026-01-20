import 'package:flutter_riverpod/flutter_riverpod.dart';

class SafeProfile {
  final String name;
  final String status;

  const SafeProfile({required this.name, required this.status});
}

final safeProfileProvider = Provider<SafeProfile>((ref) {
  return const SafeProfile(name: 'Guest User', status: 'Stabilization mode');
});
