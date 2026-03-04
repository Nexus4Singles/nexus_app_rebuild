import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

import 'package:nexus_app_v2/core/storage/do_spaces_storage_service.dart';

import '../theme/app_colors.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Service for handling media operations: photos and audio recordings.
/// Migrated to just_audio for world-class stability and performance.
class MediaService {
  final DoSpacesStorageService _spacesStorage = DoSpacesStorageService();

  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ja.AudioPlayer _audioPlayer = ja.AudioPlayer();

  // Audio recording state
  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;

  // Callbacks for recording updates
  Function(Duration)? onRecordingDurationUpdate;
  Function(double)? onRecordingAmplitudeUpdate;

  // Getters
  bool get isRecording => _isRecording;
  Duration get recordingDuration =>
      _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

  // ============================================================================
  // PERMISSIONS
  // ============================================================================

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> requestPhotoLibraryPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  // ============================================================================
  // IMAGE PICKING
  // ============================================================================

  Future<File?> pickImageFromGallery({
    int maxWidth = 1080,
    int maxHeight = 1080,
    int imageQuality = 85,
    bool cropToSquare = true,
  }) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );
      if (pickedFile == null) return null;
      if (cropToSquare) return await _cropImage(pickedFile.path);
      return File(pickedFile.path);
    } catch (e) {
      return null;
    }
  }

  Future<File?> pickImageFromCamera({
    int maxWidth = 1080,
    int maxHeight = 1080,
    int imageQuality = 85,
    bool cropToSquare = true,
  }) async {
    try {
      if (!await requestCameraPermission())
        throw MediaException('Camera permission denied');
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
        preferredCameraDevice: CameraDevice.front,
      );
      if (pickedFile == null) return null;
      if (cropToSquare) return await _cropImage(pickedFile.path);
      return File(pickedFile.path);
    } catch (e) {
      return null;
    }
  }

  Future<File?> pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Photo Library'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ],
              ),
            ),
          ),
    );
    if (source == null) return null;
    return source == ImageSource.camera
        ? await pickImageFromCamera()
        : await pickImageFromGallery();
  }

  // ============================================================================
  // FACE DETECTION & CROPPING
  // ============================================================================

  Future<bool?> hasHumanFace(String filePath) async {
    try {
      final detector = FaceDetector(
        options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
      );
      final faces = await detector.processImage(
        InputImage.fromFilePath(filePath),
      );
      await detector.close();
      return faces.isNotEmpty;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _cropImage(String sourcePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: AppColors.primary,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: true),
        ],
      );
      return croppedFile != null ? File(croppedFile.path) : File(sourcePath);
    } catch (_) {
      return File(sourcePath);
    }
  }

  // ============================================================================
  // AUDIO RECORDING
  // ============================================================================

  Future<bool> startRecording({
    int maxDuration = 90,
    Function(Duration)? onDurationUpdate,
    Function(double)? onAmplitudeUpdate,
  }) async {
    try {
      if (!await requestMicrophonePermission())
        throw MediaException('Microphone permission denied');
      if (_isRecording) await stopRecording();

      final directory = await getTemporaryDirectory();
      _currentRecordingPath = p.join(
        directory.path,
        'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      onRecordingDurationUpdate = onDurationUpdate;
      onRecordingAmplitudeUpdate = onAmplitudeUpdate;

      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        if (duration.inSeconds >= maxDuration) {
          stopRecording();
          return;
        }
        onRecordingDurationUpdate?.call(duration);
      });

      _startAmplitudeStream();
      return true;
    } catch (_) {
      _isRecording = false;
      return false;
    }
  }

  void _startAmplitudeStream() async {
    while (_isRecording) {
      try {
        final amplitude = await _audioRecorder.getAmplitude();
        onRecordingAmplitudeUpdate?.call(
          ((amplitude.current + 60) / 60).clamp(0.0, 1.0),
        );
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {
        break;
      }
    }
  }

  Future<String?> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      if (!_isRecording) return null;
      final path = await _audioRecorder.stop();
      await Future.delayed(const Duration(milliseconds: 500));
      _isRecording = false;
      return path ?? _currentRecordingPath;
    } catch (_) {
      _isRecording = false;
      return null;
    }
  }

  // ============================================================================
  // AUDIO PLAYBACK (just_audio implementation)
  // ============================================================================

  /// Play audio from file path or URL
  /// Handles both local files and remote URLs with Android compatibility
  Future<void> playAudio(String path) async {
    try {
      if (path.startsWith('http')) {
        // For URLs, add caching and error handling for Android
        await _audioPlayer.setUrl(path);
      } else {
        await _audioPlayer.setFilePath(path);
      }
      await _audioPlayer.play();
    } catch (e) {
      throw MediaException('Failed to play audio: $e');
    }
  }

  Future<void> playAudioFromUrl(String url) async => playAudio(url);
  Future<void> pauseAudio() async => await _audioPlayer.pause();
  Future<void> resumeAudio() async => await _audioPlayer.play();
  Future<void> stopAudio() async => await _audioPlayer.stop();
  Future<void> seekAudio(Duration position) async =>
      await _audioPlayer.seek(position);

  /// Get audio duration with validation
  /// Returns capped duration for max 90-second recordings
  /// Returns null if duration cannot be determined
  Future<Duration?> getAudioDuration(String path) async {
    try {
      final duration =
          path.startsWith('http')
              ? await _audioPlayer.setUrl(path)
              : await _audioPlayer.setFilePath(path);

      // Validate duration is reasonable (max 90 seconds for recordings)
      if (duration != null && duration.inSeconds > 90) {
        debugPrint(
          '[MediaService] ⚠️  Audio duration suspicious: ${duration.inSeconds}s, capping to 90s',
        );
        return const Duration(seconds: 90);
      }

      return duration;
    } catch (_) {
      return null;
    }
  }

  Stream<ja.PlayerState> get onPlayerStateChanged =>
      _audioPlayer.playerStateStream;
  Stream<Duration> get onPositionChanged => _audioPlayer.positionStream;

  /// Duration stream with validation to prevent Android duration reporting issues
  /// Filters out unreasonable durations (> 90 seconds for 60s max recordings)
  Stream<Duration?> get onDurationChanged {
    return _audioPlayer.durationStream.map((duration) {
      // Validate and cap the duration to prevent Android reporting bugs
      if (duration != null && duration.inSeconds > 90) {
        debugPrint(
          '[MediaService] ⚠️  Android duration bug detected: ${duration.inSeconds}s, filtering to reasonable max',
        );
        return const Duration(seconds: 90);
      }
      return duration;
    });
  }

  // ============================================================================
  // STORAGE OPERATIONS (Cloud-managed keys)
  // ============================================================================

  Future<String> uploadProfilePhoto(
    String userId,
    File imageFile, {
    int photoIndex = 0,
    Function(double)? onProgress,
  }) async {
    try {
      // Keys are generated by the backend Cloud Function
      return await _spacesStorage.uploadFile(
        localPath: imageFile.path,
        onProgress: onProgress,
      );
    } catch (e) {
      throw MediaException('Failed to upload photo: $e');
    }
  }

  Future<String> uploadAudioRecording(
    String userId,
    String filePath, {
    required int questionIndex,
    Function(double)? onProgress,
  }) async {
    try {
      return await _spacesStorage.uploadFile(
        localPath: filePath,
        onProgress: onProgress,
      );
    } catch (e) {
      throw MediaException('Failed to upload audio: $e');
    }
  }

  Future<String> uploadChatImage({
    required String userId,
    required String chatId,
    required File imageFile,
    Function(double)? onProgress,
  }) async {
    try {
      return await _spacesStorage.uploadFile(
        localPath: imageFile.path,
        onProgress: onProgress,
      );
    } catch (e) {
      throw MediaException('Failed to upload chat image: $e');
    }
  }

  Future<String> uploadChatAudio({
    required String userId,
    required String chatId,
    required String filePath,
    Function(double)? onProgress,
  }) async {
    try {
      return await _spacesStorage.uploadFile(
        localPath: filePath,
        onProgress: onProgress,
      );
    } catch (e) {
      throw MediaException('Failed to upload chat audio: $e');
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}

class MediaException implements Exception {
  final String message;
  MediaException(this.message);
  @override
  String toString() => 'MediaException: $message';
}
