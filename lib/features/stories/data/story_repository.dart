import 'package:flutter/services.dart';
import 'package:nexus_app_min_test/features/stories/domain/story_models.dart';

class StoryRepository {
  static const String _assetPath = 'assets/config/engagement/stories.v1.json';

  const StoryRepository();

  Future<List<Story>> loadStories() async {
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
    final stories = await loadStories();
    for (final s in stories) {
      if (s.id == 'story_of_the_week') return s;
    }
    if (stories.isEmpty) return null;
    return stories.first;
  }
}
