import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'guest_session.dart';
import 'guest_session_service.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be overridden in bootstrap.',
  );
});

final guestSessionServiceProvider = Provider<GuestSessionService>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return GuestSessionService(prefs);
});

final guestSessionProvider =
    StateNotifierProvider<GuestSessionNotifier, GuestSession?>((ref) {
      final service = ref.watch(guestSessionServiceProvider);
      return GuestSessionNotifier(service)..load();
    });

class GuestSessionNotifier extends StateNotifier<GuestSession?> {
  final GuestSessionService _service;

  GuestSessionNotifier(this._service) : super(null);

  void load() {
    state = _service.load();
  }

  Future<void> setRelationshipStatus(RelationshipStatus status) async {
    final next =
        (state == null)
            ? GuestSession(relationshipStatus: status)
            : state!.copyWith(relationshipStatus: status);
    state = next;
    await _service.save(next);
  }

  Future<void> setGender(String? gender) async {
    if (state == null) return;
    final next = state!.copyWith(gender: gender);
    state = next;
    await _service.save(next);
  }

  Future<void> setGoals(List<String> goals) async {
    if (state == null) return;
    final next = state!.copyWith(goals: goals);
    state = next;
    await _service.save(next);
  }

  Future<void> clear() async {
    state = null;
    await _service.clear();
  }
}
