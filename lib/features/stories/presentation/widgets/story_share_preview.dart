import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/models/story_model.dart' hide Story;
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/features/stories/domain/story_models.dart';

/// A widget that renders a preview card of a story for sharing.
/// This widget is designed to be captured as an image and shared on social media.
class StorySharePreview extends StatelessWidget {
  final Story story;

  const StorySharePreview({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080, // Instagram-optimized width (9:16 aspect ratio)
      height: 1440,
      color: AppColors.getSurface(context),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Header with app branding
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.auto_stories,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nexus Stories',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Wisdom for your relationship',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main content area with story info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Category and read time chips
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ChipPill(text: story.category),
                        _ChipPill(text: '${story.readTimeMins} min read'),
                        ...(story.tags
                            .take(2)
                            .map((tag) => _ChipPill(text: tag))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Story title
                    Text(
                      story.title,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),

                    // Story excerpt/intro
                    Text(
                      story.intro.replaceAll('\n', ' '),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 15,
                        height: 1.6,
                        color: AppColors.getTextSecondary(context),
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // Footer with CTA
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.getSurface(context).withOpacity(0.0),
                    AppColors.primary.withOpacity(0.08),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Read this story on Nexus',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Download Nexus to explore meaningful stories\nfor your relationship.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String text;

  const _ChipPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
