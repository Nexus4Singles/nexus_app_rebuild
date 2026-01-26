import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/story_model.dart';
import 'content_cache_service.dart';

/// Fetches stories and polls from Firestore
class RemoteContentService {
  static final RemoteContentService _instance =
      RemoteContentService._internal();
  factory RemoteContentService() => _instance;
  RemoteContentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ContentCacheService _cache = ContentCacheService();

  /// Fetch stories from Firestore, with fallback to cache
  Future<StoriesCatalog?> fetchStories() async {
    try {
      // Try to fetch from Firestore
      final doc = await _firestore.doc('cms/stories').get();

      if (!doc.exists) {
        print('No remote stories found, using cache');
        final cached = _cache.getCachedStories();
        return cached != null
            ? StoriesCatalog.fromJson(jsonDecode(cached))
            : null;
      }

      final data = doc.data() as Map<String, dynamic>;
      final rawV = data['version'];
      final version =
          rawV is int
              ? rawV
              : int.tryParse(
                    rawV == null
                        ? ''
                        : rawV.toString().replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                  1;

      // Cache it
      await _cache.cacheStories(jsonEncode(data), version);

      return StoriesCatalog.fromJson(data);
    } catch (e) {
      print('Error fetching stories: $e, trying cache');
      // Fall back to cache
      final cached = _cache.getCachedStories();
      return cached != null
          ? StoriesCatalog.fromJson(jsonDecode(cached))
          : null;
    }
  }

  /// Fetch polls from Firestore, with fallback to cache
  Future<PollsCatalog?> fetchPolls() async {
    try {
      final doc = await _firestore.doc('cms/polls').get();

      if (!doc.exists) {
        print('No remote polls found, using cache');
        final cached = _cache.getCachedPolls();
        return cached != null
            ? PollsCatalog.fromJson(jsonDecode(cached))
            : null;
      }

      final data = doc.data() as Map<String, dynamic>;
      final rawV = data['version'];
      final version =
          rawV is int
              ? rawV
              : int.tryParse(
                    rawV == null
                        ? ''
                        : rawV.toString().replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                  1;

      await _cache.cachePolls(jsonEncode(data), version);

      return PollsCatalog.fromJson(data);
    } catch (e) {
      print('Error fetching polls: $e, trying cache');
      final cached = _cache.getCachedPolls();
      return cached != null ? PollsCatalog.fromJson(jsonDecode(cached)) : null;
    }
  }

  /// Check if remote content is newer
  Future<bool> isStoriesNewer() async {
    try {
      final remoteVersion = await _getRemoteVersion('stories');
      final localVersion = _cache.getStoriesVersion() ?? 0;
      return remoteVersion > localVersion;
    } catch (e) {
      return false;
    }
  }

  /// Check if remote polls are newer
  Future<bool> isPollsNewer() async {
    try {
      final remoteVersion = await _getRemoteVersion('polls');
      final localVersion = _cache.getPollsVersion() ?? 0;
      return remoteVersion > localVersion;
    } catch (e) {
      return false;
    }
  }

  Future<int> _getRemoteVersion(String type) async {
    final doc = await _firestore.doc('cms/versions').get();
    if (!doc.exists) return 0;

    final data = doc.data() as Map<String, dynamic>?;
    return (data?[type]?['version'] ?? 0) as int;
  }
}
