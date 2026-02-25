import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

class DatingPoolGuidelinesModal extends StatelessWidget {
  final VoidCallback onDismiss;

  const DatingPoolGuidelinesModal({Key? key, required this.onDismiss})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.getBackground(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Text(
                      'Dating Profile Guide',
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Guidelines content
                    _GuidelineItem(
                      icon: '🙏',
                      title: 'Target Audience',
                      description:
                          'For single, divorced, or widowed Christians globally who have a genuine relationship with God.',
                    ),
                    const SizedBox(height: 16),
                    _GuidelineItem(
                      icon: '🎤',
                      title: 'Key Profile Requirements',
                      description:
                          'Great Pictures & 3 Audio Recordings\n(Our Admin team will review to filter out fake or AI-generated content)',
                    ),
                    const SizedBox(height: 16),
                    _GuidelineItem(
                      icon: '👂',
                      title: 'Why Great Pictures Matter',
                      description:
                          'Your Pictures are the entry point to creating a great first impression. Most Opposite Gender Users will not bother to listen to your recordings, if you dont upload nice pictures.',
                    ),
                    const SizedBox(height: 16),
                    _GuidelineItem(
                      icon: '💬',
                      title: 'Why Your Audio Recordings Matter',
                      description:
                          'Your audio recordings reveal your beliefs & thought processes because people want to know who you are beyond your looks. Kindly take these recordings seriously.',
                    ),
                    const SizedBox(height: 16),
                    _GuidelineItem(
                      icon: '🔒',
                      title: 'Privacy & Global Reach',
                      description:
                          'Your Profile will be visible to ONLY the opposite gender globally',
                    ),
                    const SizedBox(height: 16),
                    _GuidelineItem(
                      icon: '💎',
                      title: 'Our Mission',
                      description:
                          'An intentional movement to see more kingdom marriages exist by providing you with the visibility to find or to be found;',
                    ),
                    const SizedBox(height: 16),
                    _GuidelineItem(
                      icon: '✨',
                      title: 'Your Journey',
                      description:
                          'Don\'t hesitate to share your love story with us if you find someone here and get married! We would love to celebrate with you and share your story as a testimony to inspire others.',
                    ),
                    const SizedBox(height: 24),

                    // CTA Text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('⚡', style: AppTextStyles.displaySmall),
                          const SizedBox(width: 12),
                          Text(
                            'We wish you GODSPEED!!!',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Close button (top-right)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: onDismiss,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(context).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _GuidelineItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
