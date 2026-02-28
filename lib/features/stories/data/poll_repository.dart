import 'package:nexus_app_v2/core/models/story_model.dart' as remote;
import 'package:nexus_app_v2/core/services/config_loader_service.dart';
import 'package:nexus_app_v2/features/stories/domain/poll_models.dart';

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
    // Build insights map from per-option insightCopy, falling back to defaultInsightCopy
    final insights = <String, String>{};
    for (final o in p.options) {
      final copy =
          o.insightCopy.isNotEmpty ? o.insightCopy : p.defaultInsightCopy;
      if (copy.isNotEmpty) {
        insights[o.id] = copy;
      }
    }

    // Build seedCounts from per-option vote counts
    final seedCounts = <String, int>{};
    for (final o in p.options) {
      if (o.votes > 0) {
        seedCounts[o.id] = o.votes;
      }
    }

    return Poll(
      id: p.pollId,
      question: p.question,
      options:
          p.options.map((o) => PollOption(id: o.id, text: o.text)).toList(),
      insights: insights,
      seedCounts: seedCounts,
    );
  }
}
