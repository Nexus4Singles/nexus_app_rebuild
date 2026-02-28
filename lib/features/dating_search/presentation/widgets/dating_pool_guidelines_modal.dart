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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Text(
                      'Dating Profile Guide',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Guidelines content
                    _GuidelineItem(
                      icon: '🎯',
                      title: 'Target Audience',
                      description:
                          'For single, divorced, or widowed Christians, who have a genuine relationship with God.',
                    ),
                    const SizedBox(height: 12),
                    _GuidelineItem(
                      icon: '📝',
                      title: 'Key Profile Requirements',
                      description:
                          'Great Pictures & 3 Audio Recordings\n(Our Admin team will review to filter out fake or AI-generated content)',
                    ),
                    const SizedBox(height: 12),
                    _GuidelineItem(
                      icon: '📸',
                      title: 'Why Great Pictures Matter',
                      description:
                          'The quality of your Pictures will determine whether users will decide to listen to your recordings or not.',
                    ),
                    const SizedBox(height: 12),
                    _GuidelineItem(
                      icon: '🎤',
                      title: 'Why Your Audio Recordings Matter',
                      description:
                          'Your audio recordings reveal your beliefs & thought processes because people want to know who you are beyond your looks.',
                    ),
                    const SizedBox(height: 12),
                    _GuidelineItem(
                      icon: '🔒',
                      title: 'Privacy & Global Reach',
                      description:
                          'Your Profile will be visible to ONLY the opposite gender globally',
                    ),
                    const SizedBox(height: 12),
                    _GuidelineItem(
                      icon: '💎',
                      title: 'Our Mission',
                      description:
                          'An intentional movement to see more kingdom marriages exist by providing you with the visibility to find or to be found;',
                    ),
                    const SizedBox(height: 12),
                    _GuidelineItem(
                      icon: '✨',
                      title: 'Your Journey',
                      description:
                          'Don\'t hesitate to share your love story with us if you get married to someone through this platform! We would love to celebrate with you!',
                    ),
                    const SizedBox(height: 20),

                    // CTA Text (More compact)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          const Text('⚡', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Text(
                            'We wish you GODSPEED!!!',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
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
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.3,
                  fontSize: 11, // Slightly reduced for better fit
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
