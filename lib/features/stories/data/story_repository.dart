import 'package:flutter/services.dart';
import 'package:nexus_app_min_test/core/services/config_loader_service.dart';
import 'package:nexus_app_min_test/features/stories/domain/story_models.dart';
import 'package:nexus_app_min_test/core/models/story_model.dart' as remote;

class StoryRepository {
  static const String _assetPath = 'assets/config/engagement/stories.v1.json';

  const StoryRepository();

  Future<List<Story>> loadStories() async {
    // Try remote first
    try {
      final catalog = await ConfigLoaderService().loadStoriesCatalog();
      return catalog.stories.map(_mapRemoteStory).toList();
    } catch (_) {
      // fall through to asset
    }

    // Fallback to bundled asset
    final raw = await rootBundle.loadString(_assetPath);
    final payload = StoriesPayload.fromJsonString(raw);
    return payload.stories;
  }

  Future<Story?> loadStoryById(String id) async {
    final stories = await loadStories();
    for (final s in stories) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// v1: One story per week. We treat the "current" story as:
  /// - story with id == 'story_of_the_week' if present, else
  /// - the first story in the JSON list.
  Future<Story?> loadCurrentStory() async {
    try {
      final catalog = await ConfigLoaderService().loadStoriesCatalog();
      final remoteStory = catalog.currentStoryOfWeek;
      if (remoteStory != null) return _mapRemoteStory(remoteStory);
    } catch (_) {}

    // Fallback to asset selection logic
    final stories = await loadStories();
    for (final s in stories) {
      if (s.id == 'story_of_the_week') return s;
    }
    if (stories.isEmpty) return null;
    return stories.first;
  }

  Story _mapRemoteStory(remote.Story s) {
    final contentText =
        s.contentText ??
        s.contentBlocks
            .where((b) => b.text != null)
            .map((b) => b.text!)
            .join('\n\n');

    // Keep FULL content together as one block, no splitting into sections
    final intro = contentText.trim();

    final hero = s.heroImage ?? s.imageUrl;
    final takeaways = s.keyLessons;

    return Story(
      id: s.storyId,
      title: s.title,
      category: s.tags.isNotEmpty ? s.tags.first : 'Story',
      readTimeMins: s.readingTimeMins,
      heroImageAsset: hero ?? '',
      excerpt: intro,
      intro: intro,
      sections: [], // Empty — full content displays in intro card
      takeawayTitle: 'Key Lessons',
      takeaways: takeaways,
      reflectionPrompt: '',
      pollId: s.pollId,
      pollCtaText: 'Open poll',
    );
  }
}
