import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nexus_app_min_test/core/storage/providers/media_storage_provider.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProgressHeader(
                  title: 'Add Photos',
                  subtitle:
                      'Add at least 2 Photos of yourself. We highly recommend uploading your best pictures because first impressions really matter. Profiles with \nAI-generated or indecent pictures will not be approved.',
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: _PhotoGrid(
                    photoPaths: _photoPaths,
                    onAdd: (_busy || maxReached) ? null : _pickPhoto,
                    onRemove: _removePhoto,
                  ),
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
          _toast('Skipped ${img.name}: Please upload photos with human faces.');
          continue;
        }

        setState(() {
          _photoPaths.add(img.path);
        });
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
      debugPrint(
        '[Photos] Starting upload for ${_photoPaths.length} photos...',
      );
      debugPrint('[Photos] Uploading ${_photoPaths.length} photos...');
      final storage = ref.read(mediaStorageProvider);
      final uploadedUrls = <String>[];

      for (var i = 0; i < _photoPaths.length; i++) {
        final path = _photoPaths[i];
        final key =
            'dating/photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        try {
          debugPrint('[Photos] Uploading photo ${i + 1}: $path');
          final publicUrl = await storage.uploadImage(
            localPath: path,
            objectKey: key,
          );
          uploadedUrls.add(publicUrl);
          debugPrint(
            '[Photos] Photo ${i + 1} uploaded successfully: $publicUrl',
          );
        } catch (e) {
          _toast('Failed to upload photo ${i + 1}: $e');
          setState(() => _busy = false);
          return;
        }
      }

      debugPrint('[Photos] All photos uploaded successfully');

      // Update draft with new uploaded photo URLs (always overwrite)
      ref
          .read(datingOnboardingDraftProvider.notifier)
          .setPhotos(List.of(_photoPaths));

      // Persist photo URLs to Firestore under users/{uid}.dating.photos
      try {
        final ready = ref.read(firebaseReadyProvider);
        final fs = ref.read(firestoreInstanceProvider);
        final uid = FirebaseAuth.instance.currentUser?.uid;

        debugPrint(
          '[Photos] 🔍 Firebase ready: $ready, Firestore: ${fs != null}, UID: $uid',
        );
        debugPrint('[Photos] 🔍 Uploaded URLs to save: $uploadedUrls');

        if (ready && fs != null && uid != null) {
          final payload = {
            'dating': {
              'photos': uploadedUrls,
              'profile': {
                'profileUrl':
                    uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
              },
            },
          };
          debugPrint('[Photos] 🔍 Firestore payload: $payload');

          await fs
              .collection('users')
              .doc(uid)
              .set(payload, SetOptions(merge: true));
          debugPrint('[Photos] ✅ Saved photo URLs to Firestore for $uid');
        } else {
          debugPrint(
            '[Photos] ❌ Skipped Firestore save - ready: $ready, fs: ${fs != null}, uid: $uid',
          );
        }
      } catch (e, stackTrace) {
        debugPrint('[Photos] ❌ Firestore save failed: $e');
        debugPrint('[Photos] Stack trace: $stackTrace');
      }
      if (!context.mounted) return;
      Navigator.of(context).pushNamed('/dating/setup/audio');
    } catch (e) {
      _toast('Upload error: $e');
      setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
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
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
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
    return GridView.builder(
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted),
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
                            color: AppColors.surface,
                            child: Icon(
                              Icons.broken_image,
                              color: AppColors.textMuted,
                            ),
                          ),
                    )
                    : Container(
                      color: AppColors.surface,
                      child: Icon(
                        Icons.broken_image,
                        color: AppColors.textMuted,
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
