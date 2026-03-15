import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:nexus_app_v2/features/stories/domain/story_models.dart';

/// Service for handling story sharing via native share sheet
class StoryShareService {
  // Private constructor
  StoryShareService._();

  /// Share a story using the native share sheet
  /// Shows a short snippet of the story with Firebase Dynamic Link
  static Future<void> shareStoryAsPreview({
    required BuildContext context,
    required Story story,
  }) async {
    try {
      // Generate Firebase Dynamic Link
      final dynamicLink = generateDynamicLink(story);

      final String shareMessage = _createShareMessage(story, dynamicLink);

      // Debug: Log the exact message being shared
      debugPrint('📤 SHARE DEBUG INFO:');
      debugPrint('   Story ID: ${story.id}');
      debugPrint(
        '   Story Title: "${story.title}" (length: ${story.title.length})',
      );
      debugPrint(
        '   Story Intro: "${story.intro.substring(0, story.intro.length > 50 ? 50 : story.intro.length)}..." (length: ${story.intro.length})',
      );
      debugPrint('   Dynamic Link: $dynamicLink');
      debugPrint('   Full Share Message:\n---\n$shareMessage\n---');

      // For iPad support, get the center of the screen for share position
      Rect? sharePositionOrigin;
      if (Platform.isIOS) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }

      final result = await Share.share(
        shareMessage,
        subject: story.title,
        sharePositionOrigin: sharePositionOrigin,
      );

      // Log whether share was successful
      if (result.status == ShareResultStatus.success) {
        debugPrint('✓ Story shared successfully: "${story.title}"');
      } else if (result.status == ShareResultStatus.unavailable) {
        debugPrint('⚠ Share unavailable for: "${story.title}"');
        if (context.mounted) {
          _showErrorSnackbar(
            context,
            'No apps available to share. Please install WhatsApp, Instagram, or another app.',
          );
        }
      } else {
        debugPrint('ℹ Share dismissed by user: "${story.title}"');
      }
    } catch (e) {
      debugPrint('✗ Error opening share sheet: $e');

      if (context.mounted) {
        _showErrorSnackbar(context, 'Failed to share story. Please try again.');
      }
    }
  }

  /// Generate a Firebase Dynamic Link for sharing a story
  /// This is a universal link that works for both iOS and Android
  static String generateDynamicLink(Story story) {
    // Firebase Dynamic Link format
    // This link will redirect to app store if app isn't installed
    // or open the app with deeplink if it is installed
    return 'https://nexus.page.link/story?id=${story.id}';
  }

  /// Create a concise share message with title, short snippet, and dynamic link
  static String _createShareMessage(Story story, String dynamicLink) {
    // Get first 100 characters of intro as snippet
    String snippet = story.intro.replaceAll('\n', ' ').trim();
    if (snippet.length > 100) {
      snippet = '${snippet.substring(0, 100)}...';
    }

    // Format message for maximum iOS compatibility
    // Avoid problematic characters that some apps struggle with
    return '${story.title}\n\n$snippet\n\nRead on Nexus: $dynamicLink';
  }

  /// Show error snackbar
  static void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
