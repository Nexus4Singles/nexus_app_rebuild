import 'package:nexus_app_min_test/core/models/story_model.dart' as remote;
import 'package:nexus_app_min_test/core/services/config_loader_service.dart';
import 'package:nexus_app_min_test/features/stories/domain/poll_models.dart';

class PollRepository {
  const PollRepository();

  Future<List<Poll>> loadPolls() async {
    final catalog = await ConfigLoaderService().loadPollsCatalog();
    return catalog.polls.map(_mapRemotePoll).toList();
  }

  Future<Poll?> loadPollById(String id) async {
    final polls = await loadPolls();
    for (final p in polls) {
      if (p.id == id) return p;
    }
    return null;
  }

  Poll _mapRemotePoll(remote.Poll p) {
    return Poll(
      id: p.pollId,
      question: p.question,
      options:
          p.options.map((o) => PollOption(id: o.id, text: o.text)).toList(),
      insights: const {},
      seedCounts: const {},
    );
  }
}
