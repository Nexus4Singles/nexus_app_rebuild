import 'package:flutter/services.dart';
import 'package:nexus_app_min_test/features/stories/domain/poll_models.dart';

class PollRepository {
  static const String _assetPath = 'assets/config/engagement/polls.v1.json';

  const PollRepository();

  Future<List<Poll>> loadPolls() async {
    final raw = await rootBundle.loadString(_assetPath);
    final payload = PollsPayload.fromJsonString(raw);
    return payload.polls;
  }

  Future<Poll?> loadPollById(String id) async {
    final polls = await loadPolls();
    for (final p in polls) {
      if (p.id == id) return p;
    }
    return null;
  }
}
