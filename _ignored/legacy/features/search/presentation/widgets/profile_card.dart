import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/models/user_model.dart';

/// Beautiful profile card for search results grid
/// Inspired by modern dating app designs with full-bleed images
class ProfileCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  final bool showSaveButton;
  final bool isSaved;

  const ProfileCard({
    super.key,
    required this.user,
    required this.onTap,
    this.onSave,
    this.showSaveButton = true,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              _buildImage(),

              // Gradient overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Online indicator
              if (user.isOnline == true)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.signalStrong,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.signalStrong.withOpacity(0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Premium/Verified badges
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    if (user.isVerified == true)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    if (user.isPremium) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
                            SizedBox(width: 2),
                            Text(
                              'PRO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // User info at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and age
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${user.username ?? user.name ?? 'User'}, ${user.age ?? '?'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Save/Bookmark button
                          if (showSaveButton && onSave != null)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onSave!();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSaved 
                                      ? AppColors.primary
                                      : Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  boxShadow: isSaved ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ] : null,
                                ),
                                child: Icon(
                                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withOpacity(0.9),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getLocation(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final photoUrl = user.profileUrl ?? 
                     (user.photos?.isNotEmpty == true ? user.photos!.first : null);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppColors.surfaceDark,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    // Generate a nice gradient based on user name
    final colors = _getGradientColors();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    final name = user.username ?? user.name ?? 'U';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  List<Color> _getGradientColors() {
    // Generate consistent colors based on user ID or name
    final hash = (user.uid ?? user.name ?? 'user').hashCode;
    final hue = (hash % 360).abs().toDouble();
    
    return [
      HSLColor.fromAHSL(1, hue, 0.6, 0.5).toColor(),
      HSLColor.fromAHSL(1, (hue + 30) % 360, 0.6, 0.4).toColor(),
    ];
  }

  String _getLocation() {
    if (user.city != null && user.country != null) {
      return '${user.city}, ${user.country}';
    }
    return user.city ?? user.country ?? user.location ?? 'Location unknown';
  }
}

/// Large profile card for featured/highlighted users
class FeaturedProfileCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final String? compatibilityScore;

  const FeaturedProfileCard({
    super.key,
    required this.user,
    required this.onTap,
    this.compatibilityScore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 280,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              _buildImage(),

              // Gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Compatibility badge
              if (compatibilityScore != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$compatibilityScore% Match',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // User info
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.username ?? user.name}, ${user.age}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.white.withOpacity(0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.city ?? user.country ?? 'Unknown',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final photoUrl = user.profileUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.secondary.withOpacity(0.8),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 64, color: Colors.white54),
      ),
    );
  }
}
