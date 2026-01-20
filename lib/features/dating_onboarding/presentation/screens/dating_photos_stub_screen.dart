import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nexus_app_min_test/core/storage/providers/media_storage_provider.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';

class DatingPhotosStubScreen extends ConsumerStatefulWidget {
  const DatingPhotosStubScreen({super.key});

  @override
  ConsumerState<DatingPhotosStubScreen> createState() =>
      _DatingPhotosStubScreenState();
}

class _DatingPhotosStubScreenState
    extends ConsumerState<DatingPhotosStubScreen> {
  static const int _minPhotos = 2;

  final _picker = ImagePicker();
  late final FaceDetector _faceDetector;

  bool _busy = false;
  final List<String> _photoPaths = [];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(datingOnboardingDraftProvider);
    _photoPaths.addAll(draft.photoPaths);

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Dating Profile', style: AppTextStyles.titleLarge),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProgressHeader(
                  stepLabel: 'Step 5 of 8',
                  title: 'Add photos',
                  subtitle:
                      'Add at least 2 photos of yourself. We highly recommend uploading your best pictures because first impressions really matter. Profiles with indecent pictures will be deleted.',
                ),
                const SizedBox(height: 16),

                _PhotoGrid(
                  photoPaths: _photoPaths,
                  onAdd: _busy ? null : _pickPhoto,
                  onRemove: _removePhoto,
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (!canContinue || _busy)
                            ? null
                            : () => _onContinue(context),
                    child: Text(
                      canContinue ? 'Continue' : 'Add at least 2 photos',
                    ),
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
      setState(() => _busy = true);

      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (img == null) return;

      final ok = await _isHumanPhoto(img.path);
      if (!ok) {
        HapticFeedback.mediumImpact();
        _toast(
          'Please upload a clear photo of yourself (human face required).',
        );
        return;
      }

      setState(() {
        _photoPaths.add(img.path);
      });
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
  }

  Future<void> _onContinue(BuildContext context) async {
    // Save local paths into draft
    ref
        .read(datingOnboardingDraftProvider.notifier)
        .setPhotos(List.of(_photoPaths));

    // ✅ Stub upload: show we can call storage provider without hardcoding Firebase Storage.
    // (We will do real upload later)
    final storage = ref.read(mediaStorageProvider);

    for (var i = 0; i < _photoPaths.length; i++) {
      final path = _photoPaths[i];
      final key =
          'dating/photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      try {
        await storage.uploadImage(localPath: path, objectKey: key);
      } catch (_) {
        // ignore upload errors for now; will wire real handling later
      }
    }

    Navigator.of(context).pushNamed('/dating/setup/audio');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ProgressHeader extends StatelessWidget {
  final String stepLabel;
  final String title;
  final String subtitle;

  const _ProgressHeader({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stepLabel, style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Text(title, style: AppTextStyles.headlineLarge),
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
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    color: AppColors.surface,
                    child: Icon(Icons.broken_image, color: AppColors.textMuted),
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
