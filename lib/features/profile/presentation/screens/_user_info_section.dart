import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/app_text_styles.dart';
import '../../../../core/models/user_model.dart';

class UserInfoSection extends StatelessWidget {
  final UserModel profile;
  final String locationText;
  final bool isVerified;
  const UserInfoSection({
    Key? key,
    required this.profile,
    required this.locationText,
    this.isVerified = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile.name != null && profile.name!.isNotEmpty
            ? profile.name!
            : (profile.username ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: displayName,
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  children:
                      profile.age != null
                          ? [
                            TextSpan(
                              text: ', ${profile.age}',
                              style: AppTextStyles.headlineLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ]
                          : [],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _VerificationBadge(isVerified: isVerified),
          ],
        ),
        if (locationText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(locationText, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ],
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final bool isVerified;
  const _VerificationBadge({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.error_outline,
            color: isVerified ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? 'Verified' : 'Unverified',
            style: TextStyle(
              color: isVerified ? Colors.green[800] : Colors.red[800],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
