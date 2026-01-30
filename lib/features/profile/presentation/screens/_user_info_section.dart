import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';
import 'package:nexus_app_min_test/core/theme/app_text_styles.dart';
import 'package:nexus_app_min_test/core/theme/app_colors.dart';

class UserInfoSection extends StatelessWidget {
  final UserModel profile;
  final String locationText;
  const UserInfoSection({required this.profile, required this.locationText});

  @override
  Widget build(BuildContext context) {
    final name =
        (profile.username ?? '').trim().isNotEmpty
            ? profile.username!.trim()
            : ((profile.name ?? '').trim().isNotEmpty
                ? profile.name!.trim()
                : 'User');
    final age = profile.age;
    final textPrimary = Theme.of(context).colorScheme.onBackground;
    final textSecondary = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                age != null ? '$name, $age' : name,
                style: AppTextStyles.headlineLarge.copyWith(
                  color: textPrimary,
                  fontSize: 28,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            VerificationTag(profile: profile),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on_rounded, color: textSecondary, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                locationText,
                style: AppTextStyles.bodyMedium.copyWith(color: textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class VerificationTag extends StatelessWidget {
  final UserModel profile;
  const VerificationTag({required this.profile});

  @override
  Widget build(BuildContext context) {
    // This logic should match the verification badge logic in the hero card
    // For now, we use a placeholder. Replace with actual verification provider if needed.
    // Use isVerified from UserModel, fallback to unverified if null
    final isVerified = profile.isVerified == true;
    IconData icon;
    String label;
    Color color;
    if (isVerified) {
      icon = Icons.verified_rounded;
      label = 'Verified';
      color = Colors.green;
    } else {
      icon = Icons.block_rounded;
      label = 'Unverified';
      color = Colors.redAccent;
    }
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
