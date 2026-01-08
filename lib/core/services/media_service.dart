import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Service for handling media operations: photos and audio recordings
class MediaService {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Audio playback coordination (prevents overlapping plays + tap races)
  bool _playerReady = false;
  Future<void> _playQueue = Future.value();

  Future<void> _ensurePlayerReady() async {
    if (_playerReady) return;
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _playerReady = true;
  }

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final next = _playQueue.then((_) => op());
    // Keep the queue alive even if an op throws
    _playQueue = next.then((_) async {}).catchError((_) async {});
    return next;
  }

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

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request photo library permission
  Future<bool> requestPhotoLibraryPermission() async {
    final status = await Permission.photos.request();
    // On some platforms, this might not be needed
    return status.isGranted || status.isLimited;
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  // ============================================================================
  // IMAGE PICKING
  // ============================================================================

  /// Pick image from gallery
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

      if (cropToSquare) {
        return await _cropImage(pickedFile.path);
      }

      return File(pickedFile.path);
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick image from camera
  Future<File?> pickImageFromCamera({
    int maxWidth = 1080,
    int maxHeight = 1080,
    int imageQuality = 85,
    bool cropToSquare = true,
  }) async {
    try {
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        throw MediaException('Camera permission denied');
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile == null) return null;

      if (cropToSquare) {
        return await _cropImage(pickedFile.path);
      }

      return File(pickedFile.path);
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// Show image source picker dialog
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
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Choose Photo Source',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.photo_library,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('Photo Library'),
                    subtitle: const Text('Choose from your gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt, color: AppColors.secondary),
                    ),
                    title: const Text('Camera'),
                    subtitle: const Text('Take a new photo'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
    );

    if (source == null) return null;

    if (source == ImageSource.camera) {
      return await pickImageFromCamera();
    } else {
      return await pickImageFromGallery();
    }
  }

  // ============================================================================
  // FACE DETECTION (ML Kit)
  // ============================================================================
  /// Detect if an image contains at least one human face.
  ///
  /// Returns:
  /// - true: face detected
  /// - false: no face detected
  /// - null: detection failed technically (fail-open behavior)
  Future<bool?> hasHumanFace(String filePath) async {
    try {
      final options = FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
      );

      final detector = FaceDetector(options: options);
      final input = InputImage.fromFilePath(filePath);

      final faces = await detector.processImage(input);
      await detector.close();

      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Face detection failed (fail-open): $e');
      return null;
    }
  }

  /// Crop image to square
  Future<File?> _cropImage(String sourcePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile == null) return null;
      return File(croppedFile.path);
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return File(sourcePath); // Return original if crop fails
    }
  }

  // ============================================================================
  // IMAGE UPLOAD
  // ============================================================================

  /// Upload image to Firebase Storage
  /// Returns the download URL
  Future<String> uploadProfilePhoto(
    String userId,
    File imageFile, {
    int photoIndex = 0,
    Function(double)? onProgress,
  }) async {
    throw MediaException("Upload not wired (DigitalOcean storage pending)");
  }

  /// Delete photo from Firebase Storage
  Future<void> deleteProfilePhoto(String photoUrl) async {
    throw MediaException("Delete not wired (DigitalOcean storage pending)");
  }

  // ============================================================================
  // AUDIO RECORDING
  // ============================================================================

  /// Start recording audio
  /// maxDuration: Maximum recording duration in seconds (default 60)
  Future<bool> startRecording({
    int maxDuration = 60,
    Function(Duration)? onDurationUpdate,
    Function(double)? onAmplitudeUpdate,
  }) async {
    try {
      // Check permission
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw MediaException('Microphone permission denied');
      }

      // Check if already recording
      if (_isRecording) {
        await stopRecording();
      }

      // Get temp directory for recording
      final directory = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = p.join(directory.path, fileName);

      // Configure and start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      onRecordingDurationUpdate = onDurationUpdate;
      onRecordingAmplitudeUpdate = onAmplitudeUpdate;

      // Start duration timer
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        final duration = DateTime.now().difference(_recordingStartTime!);

        // Auto-stop at max duration
        if (duration.inSeconds >= maxDuration) {
          stopRecording();
          return;
        }

        onRecordingDurationUpdate?.call(duration);
      });

      // Start amplitude stream
      _startAmplitudeStream();

      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Start listening to amplitude changes
  void _startAmplitudeStream() async {
    while (_isRecording) {
      try {
        final amplitude = await _audioRecorder.getAmplitude();
        // Normalize amplitude to 0-1 range
        final normalizedAmplitude = (amplitude.current + 60) / 60;
        onRecordingAmplitudeUpdate?.call(normalizedAmplitude.clamp(0.0, 1.0));
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        break;
      }
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (!_isRecording) return null;

      final path = await _audioRecorder.stop();
      _isRecording = false;
      _recordingStartTime = null;
      onRecordingDurationUpdate = null;
      onRecordingAmplitudeUpdate = null;

      return path ?? _currentRecordingPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording and delete the file
  Future<void> cancelRecording() async {
    final path = await stopRecording();
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting cancelled recording: $e');
      }
    }
  }

  /// Check if recording is in progress
  Future<bool> isCurrentlyRecording() async {
    return await _audioRecorder.isRecording();
  }

  // ============================================================================
  // AUDIO PLAYBACK
  // ============================================================================

  /// Play audio from file path (exclusive: stops any current playback first)
  Future<void> playAudio(String path) async {
    return _enqueue(() async {
      try {
        await _ensurePlayerReady();
        await _audioPlayer.stop();

        if (path.startsWith('http')) {
          await _audioPlayer.play(UrlSource(path));
        } else {
          await _audioPlayer.play(DeviceFileSource(path));
        }
      } catch (e) {
        throw MediaException('Failed to play audio: $e');
      }
    });
  }

  /// Play audio from URL (exclusive: stops any current playback first)
  Future<void> playAudioFromUrl(String url) async {
    return _enqueue(() async {
      try {
        await _ensurePlayerReady();
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
      } catch (e) {
        throw MediaException('Failed to play audio from URL: $e');
      }
    });
  }

  /// Pause audio playback
  Future<void> pauseAudio() async {
    return _enqueue(() async {
      await _ensurePlayerReady();
      await _audioPlayer.pause();
    });
  }

  /// Resume audio playback
  Future<void> resumeAudio() async {
    return _enqueue(() async {
      await _ensurePlayerReady();
      await _audioPlayer.resume();
    });
  }

  /// Stop audio playback
  Future<void> stopAudio() async {
    return _enqueue(() async {
      await _ensurePlayerReady();
      await _audioPlayer.stop();
    });
  }

  /// Seek to position
  Future<void> seekAudio(Duration position) async {
    return _enqueue(() async {
      await _ensurePlayerReady();
      await _audioPlayer.seek(position);
    });
  }

  /// Get audio duration (queued; stops playback to avoid source conflicts)
  Future<Duration?> getAudioDuration(String path) async {
    return _enqueue(() async {
      try {
        await _ensurePlayerReady();
        await _audioPlayer.stop();
        await _audioPlayer.setSource(
          path.startsWith('http') ? UrlSource(path) : DeviceFileSource(path),
        );
        return await _audioPlayer.getDuration();
      } catch (_) {
        return null;
      }
    });
  }

  /// Listen to playback state changes
  Stream<PlayerState> get onPlayerStateChanged =>
      _audioPlayer.onPlayerStateChanged;

  /// Listen to playback position changes
  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;

  /// Listen to playback duration changes
  Stream<Duration> get onDurationChanged => _audioPlayer.onDurationChanged;

  // ============================================================================
  // AUDIO UPLOAD
  // ============================================================================

  /// Upload audio recording to Firebase Storage
  /// Returns the download URL
  Future<String> uploadAudioRecording(
    String userId,
    String filePath, {
    required int questionIndex,
    Function(double)? onProgress,
  }) async {
    throw MediaException("Upload not wired (DigitalOcean storage pending)");
  }

  /// Delete audio from Firebase Storage
  Future<void> deleteAudioRecording(String audioUrl) async {
    throw MediaException("Delete not wired (DigitalOcean storage pending)");
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Dispose resources
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}

/// Exception for media operations
class MediaException implements Exception {
  final String message;
  MediaException(this.message);

  @override
  String toString() => 'MediaException: $message';
}
