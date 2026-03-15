import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

/// Utility service for capturing widgets as images
class WidgetCaptureService {
  // Private constructor for singleton pattern
  WidgetCaptureService._();

  /// Captures a widget tree from a GlobalKey with RepaintBoundary
  ///
  /// This is the recommended approach for capturing widgets in Flutter.
  /// The widget wrapped in RepaintBoundary must be built in the widget tree first.
  ///
  /// [key] - A GlobalKey of a widget wrapped with RepaintBoundary
  /// [pixelRatio] - The device pixel ratio (2.0 for high quality)
  ///
  /// Returns:
  /// - A File object pointing to the captured PNG image in temp storage
  /// - null if the render object hasn't been rendered yet
  ///
  /// Throws:
  /// - [StateError] if image conversion fails
  /// - [IOException] if file cannot be written
  static Future<File?> captureWidgetFromKey(
    GlobalKey key, {
    double pixelRatio = 2.0,
  }) async {
    try {
      // Wait longer to ensure all paint cycles complete
      await Future.delayed(const Duration(milliseconds: 300));

      final RenderRepaintBoundary? renderBox =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (renderBox == null) {
        debugPrint('Error: RenderRepaintBoundary not found');
        return null;
      }

      if (!renderBox.isRepaintBoundary) {
        debugPrint('Error: Widget is not a repaint boundary');
        return null;
      }

      // Check if widget needs paint - if so, trigger one
      if (renderBox.debugNeedsPaint) {
        debugPrint('Widget needs paint, waiting for next frame...');
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final ui.Image image = await renderBox.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw StateError('Failed to convert image to bytes');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'story_preview_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(pngBytes);

      debugPrint('✓ Story preview captured: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('✗ Error capturing widget: $e');
      rethrow;
    }
  }

  /// Cleans up temporary image files
  ///
  /// Call this after sharing to free up disk space
  static Future<void> cleanupTempImage(File? file) async {
    try {
      if (file != null && await file.exists()) {
        await file.delete();
        debugPrint('✓ Temp image cleaned up');
      }
    } catch (e) {
      debugPrint('Warning: Could not cleanup temp image: $e');
    }
  }
}
