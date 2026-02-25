import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Service to cache media files (audio, images) locally for offline playback
/// Prevents repeated downloads from cloud storage
class MediaCacheService {
  static final instance = MediaCacheService._();

  MediaCacheService._();

  late Directory? _cacheDir;
  bool _initialized = false;

  /// Initialize cache directory
  Future<void> init() async {
    if (_initialized) return;
    try {
      _cacheDir = await getApplicationCacheDirectory();
      final mediaDir = Directory('${_cacheDir!.path}/media_cache');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      print('❌ Failed to init media cache: $e');
      _cacheDir = null;
    }
  }

  /// Generate cache filename from URL hash
  String _getCacheFilename(String url, String extension) {
    final hash = md5.convert(url.codeUnits).toString();
    return '$hash$extension';
  }

  /// Get file extension from URL
  String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      if (path.contains('.')) {
        return '.${path.split('.').last.split('?').first}';
      }
    } catch (_) {}
    return '.tmp'; // Fallback
  }

  /// Get cached file path for URL (doesn't download, just returns path if cached)
  Future<String?> getCachedPath(String url) async {
    try {
      if (!_initialized) await init();
      if (_cacheDir == null) return null;

      final extension = _getExtensionFromUrl(url);
      final filename = _getCacheFilename(url, extension);
      final cachePath = '${_cacheDir!.path}/media_cache/$filename';
      final file = File(cachePath);

      if (await file.exists()) {
        print('✅ Found cached media: $url');
        return cachePath;
      }
      return null;
    } catch (e) {
      print('⚠️ Error checking cache: $e');
      return null;
    }
  }

  /// Download and cache media file
  /// Returns local file path after download
  Future<String> downloadAndCache(String url) async {
    try {
      if (!_initialized) await init();
      if (_cacheDir == null) {
        throw StateError('Media cache not initialized');
      }

      // Check if already cached
      final cached = await getCachedPath(url);
      if (cached != null) {
        return cached;
      }

      print('⬇️ Downloading media to cache: $url');

      final extension = _getExtensionFromUrl(url);
      final filename = _getCacheFilename(url, extension);
      final cachePath = '${_cacheDir!.path}/media_cache/$filename';

      // Download file
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw HttpException('Failed to download media: ${response.statusCode}');
      }

      // Write to cache
      final file = File(cachePath);
      await file.writeAsBytes(response.bodyBytes);

      print('✅ Media cached successfully: $cachePath');
      return cachePath;
    } catch (e) {
      print('❌ Failed to cache media: $e');
      rethrow;
    }
  }

  /// Clear old cache files (older than specified duration)
  Future<void> clearOldCache({
    Duration olderThan = const Duration(days: 7),
  }) async {
    try {
      if (!_initialized) await init();
      if (_cacheDir == null) return;

      final mediaDir = Directory('${_cacheDir!.path}/media_cache');
      if (!await mediaDir.exists()) return;

      final files = mediaDir.listSync();
      final now = DateTime.now();

      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          if (age > olderThan) {
            await entity.delete();
            print('🗑️ Deleted old cached media: ${entity.path}');
          }
        }
      }
    } catch (e) {
      print('⚠️ Error clearing old cache: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      if (!_initialized) await init();
      if (_cacheDir == null) return;

      final mediaDir = Directory('${_cacheDir!.path}/media_cache');
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
        print('🗑️ Cleared all media cache');
      }
    } catch (e) {
      print('⚠️ Error clearing all cache: $e');
    }
  }
}
