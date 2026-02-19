import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nexus_app_v2/core/router/safe_nav.dart';
import 'package:nexus_app_v2/core/storage/providers/media_storage_provider.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_v2/features/dating_onboarding/application/dating_onboarding_draft.dart';

class DatingPhotosScreen extends ConsumerStatefulWidget {
  const DatingPhotosScreen({super.key});

  @override
  ConsumerState<DatingPhotosScreen> createState() => _DatingPhotosScreenState();
}

class _DatingPhotosScreenState extends ConsumerState<DatingPhotosScreen> {
  static const int _minPhotos = 2;
  static const int _maxPhotos = 5;

  final _picker = ImagePicker();
  late final FaceDetector _faceDetector;

  bool _busy = false;
  final List<String> _photoPaths = [];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(datingOnboardingDraftProvider);

    // Only load existing paths if the files actually exist
    for (final path in draft.photoPaths) {
      if (File(path).existsSync()) {
        _photoPaths.add(path);
      }
    }

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableTracking: false,
        enableContours: false,
        enableClassification: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _photoPaths.length >= _minPhotos;
    final maxReached = _photoPaths.length >= _maxPhotos;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => navigateBackToHome(context),
        ),
        title: Text(
          'Photos',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProgressHeader(
                  title: 'Add Photos',
                  subtitle:
                      'Add at least 2 Photos of yourself. We highly recommend uploading your best pictures because first impressions really matter. Profiles with AI-generated or indecent pictures will not be approved.',
                ),
                const SizedBox(height: 12),

                _PhotoGrid(
                  photoPaths: _photoPaths,
                  onAdd: (_busy || maxReached) ? null : _pickPhoto,
                  onRemove: _removePhoto,
                ),

                SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              (!canContinue || _busy)
                                  ? null
                                  : () => _onContinue(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            maxReached
                                ? 'Maximum 5 Photos'
                                : canContinue
                                ? 'Continue'
                                : 'Add at least 2 Photos',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      if (_photoPaths.length >= _maxPhotos) {
        _toast('Maximum 5 photos allowed.');
        return;
      }

      setState(() => _busy = true);

      // Enable multi-selection
      final images = await _picker.pickMultiImage(imageQuality: 90);

      if (images.isEmpty) return;

      // Check how many photos we can add
      final remainingSlots = _maxPhotos - _photoPaths.length;
      final imagesToProcess = images.take(remainingSlots).toList();

      if (images.length > remainingSlots) {
        _toast('Only adding $remainingSlots photo(s). Maximum 5 total.');
      }

      // Validate each photo for human face
      for (final img in imagesToProcess) {
        final ok = await _isHumanPhoto(img.path);
        if (!ok) {
          HapticFeedback.mediumImpact();
          _toast(
            "We couldn't detect a human face in that photo. Please upload a clear photo of yourself (good lighting, face visible).",
          );
          continue;
        }

        setState(() {
          _photoPaths.add(img.path);
        });

        // Show success message for accepted photo
        _toast('✅ Photo added successfully!');
      }

      // Auto-save on photo add
      ref
          .read(datingOnboardingDraftProvider.notifier)
          .setPhotos(List.of(_photoPaths));
    } catch (e) {
      _toast('Failed to pick photo: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<bool> _isHumanPhoto(String path) async {
    final input = InputImage.fromFilePath(path);
    final faces = await _faceDetector.processImage(input);

    // ✅ If no face detected -> reject
    return faces.isNotEmpty;
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths.removeAt(index);
    });

    // Auto-save on photo removal
    ref
        .read(datingOnboardingDraftProvider.notifier)
        .setPhotos(List.of(_photoPaths));
  }

  Future<void> _onContinue(BuildContext context) async {
    setState(() => _busy = true);

    try {
      // Check if we already uploaded these exact photos (URLs exist and count matches)
      final draft = ref.read(datingOnboardingDraftProvider);
      final alreadyUploaded =
          draft.photoUrls.isNotEmpty &&
          draft.photoUrls.length == _photoPaths.length;

      // If photos were already uploaded and count matches, skip re-upload
      if (alreadyUploaded) {
        print(
          '[PHOTOS] Skipping upload — ${draft.photoUrls.length} URLs already exist',
        );
        if (!context.mounted) return;
        Navigator.of(context).pushNamed('/dating/setup/audio');
        return;
      }

      print('[PHOTOS] Uploading ${_photoPaths.length} photos to DO Spaces...');
      final storage = ref.read(mediaStorageProvider);
      final List<String> uploadedUrls = [];

      for (var i = 0; i < _photoPaths.length; i++) {
        final path = _photoPaths[i];
        final key =
            'dating/photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        try {
          final publicUrl = await storage.uploadImage(
            localPath: path,
            objectKey: key,
          );
          if (publicUrl.isEmpty) {
            _toast('Upload returned empty URL for photo ${i + 1}');
            setState(() => _busy = false);
            return;
          }
          uploadedUrls.add(publicUrl);
          print(
            '[PHOTOS] ✅ Uploaded photo ${i + 1}/$_photoPaths.length: $publicUrl',
          );
        } catch (e) {
          print('[PHOTOS] ❌ Upload failed for photo ${i + 1}: $e');
          _toast('Failed to upload photo ${i + 1}: $e');
          setState(() => _busy = false);
          return;
        }
      }

      print(
        '[PHOTOS] All uploads complete. Saving ${uploadedUrls.length} URLs to draft...',
      );
      // Save uploaded photo URLs to the draft
      ref
          .read(datingOnboardingDraftProvider.notifier)
          .setPhotoUrls(uploadedUrls);

      // Verify URLs were saved
      final updatedDraft = ref.read(datingOnboardingDraftProvider);
      print(
        '[PHOTOS] Draft updated - photoUrls count: ${updatedDraft.photoUrls.length}',
      );
      print('[PHOTOS] Draft photoUrls: ${updatedDraft.photoUrls}');

      if (!context.mounted) return;
      Navigator.of(context).pushNamed('/dating/setup/audio');
    } catch (e) {
      _toast('Upload error: $e');
      setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    // Clear any existing snackbar before showing new one
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ProgressHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ProgressHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DatingProfileProgressBar(currentStep: 5, totalSteps: 9),
        const SizedBox(height: 18),
        Text(title, style: AppTextStyles.titleLarge),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextMuted(context),
          ),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<String> photoPaths;
  final VoidCallback? onAdd;
  final void Function(int index) onRemove;

  const _PhotoGrid({
    required this.photoPaths,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: photoPaths.length + 1,
        itemBuilder: (context, i) {
          if (i == photoPaths.length) {
            return _AddTile(onTap: onAdd);
          }

          final path = photoPaths[i];
          return _PhotoTile(path: path, onRemove: () => onRemove(i));
        },
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.getBorder(context)),
        ),
        child: Center(
          child: Icon(
            Icons.add_a_photo_outlined,
            color: AppColors.getTextMuted(context),
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _PhotoTile({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final fileExists = file.existsSync();

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child:
                fileExists
                    ? Image.file(
                      file,
                      fit: BoxFit.cover,
                      cacheHeight: 500,
                      cacheWidth: 500,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: AppColors.getSurface(context),
                            child: Icon(
                              Icons.broken_image,
                              color: AppColors.getTextMuted(context),
                            ),
                          ),
                    )
                    : Container(
                      color: AppColors.getSurface(context),
                      child: Icon(
                        Icons.broken_image,
                        color: AppColors.getTextMuted(context),
                      ),
                    ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
