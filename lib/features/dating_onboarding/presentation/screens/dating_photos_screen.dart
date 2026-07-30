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

    return PopScope(
      canPop: !_busy,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_busy) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for upload to complete'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _busy ? null : () => navigateBackToHome(context),
          ),
          title: Text(
            'Photos',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DatingProfileProgressBar(currentStep: 5, totalSteps: 9),
                  const SizedBox(height: 12),
                  Text(
                    'Add at least 2 different Photos of yourself. We highly recommend uploading your best pictures because first impressions really matter. Profiles with AI-generated or indecent pictures will not be approved.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextMuted(context),
                      height: 1.3,
                    ),
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
                        const SizedBox(height: 12),
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
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Uploading Photos...',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
      final images = await _picker.pickMultiImage(imageQuality: 90);
      if (images.isEmpty) return;
      final remainingSlots = _maxPhotos - _photoPaths.length;
      final imagesToProcess = images.take(remainingSlots).toList();
      for (final img in imagesToProcess) {
        final ok = await _isHumanPhoto(img.path);
        if (!ok) {
          HapticFeedback.mediumImpact();
          _toast(
            "We couldn't detect a human face. Please upload a clear photo of yourself.",
          );
          continue;
        }
        setState(() {
          _photoPaths.add(img.path);
        });
      }
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
    return faces.isNotEmpty;
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths.removeAt(index);
    });
    ref
        .read(datingOnboardingDraftProvider.notifier)
        .setPhotos(List.of(_photoPaths));
  }

  Future<void> _onContinue(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final draft = ref.read(datingOnboardingDraftProvider);
      if (draft.photoUrls.isNotEmpty &&
          draft.photoUrls.length == _photoPaths.length) {
        if (!context.mounted) return;
        setState(() => _busy = false);
        Navigator.of(context).pushNamed('/dating/setup/audio');
        return;
      }
      final storage = ref.read(mediaStorageProvider);
      final List<String> uploadedUrls = [];
      for (var i = 0; i < _photoPaths.length; i++) {
        final path = _photoPaths[i];
        final key =
            'dating/photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final url = await storage.uploadImage(localPath: path, objectKey: key);
        uploadedUrls.add(url);
      }
      ref
          .read(datingOnboardingDraftProvider.notifier)
          .setPhotoUrls(uploadedUrls);
      if (!context.mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pushNamed('/dating/setup/audio');
    } catch (e) {
      _toast('Upload error: $e');
      setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
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
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(File(path), fit: BoxFit.cover),
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
