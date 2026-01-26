import 'package:shared_preferences/shared_preferences.dart';

/// Simple local caching for stories and polls
class ContentCacheService {
  static final ContentCacheService _instance = ContentCacheService._internal();
  factory ContentCacheService() => _instance;
  ContentCacheService._internal();

  late SharedPreferences _prefs;

  /// Initialize the service (call once on app start)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save stories to cache
  Future<void> cacheStories(String json, int version) async {
    await _prefs.setString('cached_stories', json);
    await _prefs.setInt('stories_version', version);
  }

  /// Get cached stories
  String? getCachedStories() => _prefs.getString('cached_stories');

  /// Get cached version number
  int? getStoriesVersion() => _prefs.getInt('stories_version');

  /// Save polls to cache
  Future<void> cachePolls(String json, int version) async {
    await _prefs.setString('cached_polls', json);
    await _prefs.setInt('polls_version', version);
  }

  /// Get cached polls
  String? getCachedPolls() => _prefs.getString('cached_polls');

  /// Get cached polls version
  int? getPollsVersion() => _prefs.getInt('polls_version');
}
