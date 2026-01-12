import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'guest_session.dart';
import 'guest_session_service.dart';
import 'relationship_status_key.dart';

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
    // Persist for HomeScreen + safe/mock mode (clean swap to Firebase later)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'relationshipStatus',
      relationshipStatusKeyFromEnum(status),
    );
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

    // Also clear persisted relationship selection so presurvey starts fresh.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('relationshipStatus');
    await prefs.remove('activeJourneyId');
    await prefs.remove('active_journey_id');
  }
}
