import 'package:flutter/material.dart';
import '../../features/challenges/domain/journey_v1_models.dart';

/// Helper utilities for responsive image handling across different screen sizes
class ImageUtils {
  /// Responsive hero image height that adapts to screen width
  static double getHeroImageHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Maintain a 16:9 aspect ratio for hero images
    return screenWidth * (9 / 16);
  }

  /// Responsive hero image height capped for large screens
  static double getHeroImageHeightCapped(BuildContext context) {
    final height = getHeroImageHeight(context);
    // Cap at 220 pixels for better visual hierarchy on large tablets
    return height.clamp(160.0, 220.0);
  }

  /// Container for cached asset images with proper error handling
  static Widget cachedAssetImage({
    required String assetPath,
    required BoxFit fit,
    double? maxHeight,
    Color? errorPlaceholderColor,
  }) {
    return Container(
      color: errorPlaceholderColor ?? Colors.grey.withOpacity(0.1),
      child: Image.asset(
        assetPath,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder:
            (context, error, stackTrace) => Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey.withOpacity(0.5),
              ),
            ),
      ),
    );
  }

  /// Constructs image asset path with validation
  static String? validateAssetPath(String? path) {
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return path.trim();
  }

  /// Gets device pixel ratio for image quality optimization
  static double getDevicePixelRatio(BuildContext context) {
    return MediaQuery.of(context).devicePixelRatio;
  }
}

/// Journey-specific image utilities
class JourneyImageUtils {
  /// Get the hero image path for a journey, considering gender if applicable
  ///
  /// For gender-specific journeys, returns the appropriate gender variant.
  /// For gender-neutral journeys, returns the base image regardless of userGender.
  ///
  /// Example paths:
  /// - "assets/images/journeys/journey_1_hero.png" (neutral)
  /// - "assets/images/journeys/journey_12_masculine.png" (gender-specific)
  /// - "assets/images/journeys/journey_12_feminine.png" (gender-specific)
  static String getHeroImagePath(JourneyV1 journey, {String? userGender}) {
    // If journey has no heroImage, return empty
    final basePath = journey.heroImage;
    if (basePath == null || basePath.isEmpty) {
      return '';
    }

    // If no user gender or journey is not gender-specific, return as-is
    if (userGender == null ||
        userGender.isEmpty ||
        journey.allowedGenders.isEmpty) {
      return basePath;
    }

    // For gender-specific journeys, try to load the gender variant
    // e.g., "assets/images/journeys/journey_12_hero.png"
    // becomes "assets/images/journeys/journey_12_masculine.png" for male users
    final normalized = userGender.toLowerCase();
    final genderSuffix =
        normalized.contains('male') || normalized.contains('m')
            ? 'masculine'
            : 'feminine';

    // Replace the filename with gender variant
    if (basePath.contains('_hero.')) {
      return basePath.replaceFirst('_hero.', '_$genderSuffix.');
    }

    // If already a variant, return as-is
    return basePath;
  }

  /// Build the standard journey image path based on journey ID
  ///
  /// Usage:
  /// - buildJourneyImagePath('journey_1') → 'assets/images/journeys/journey_1_hero.png'
  /// - buildJourneyImagePath('journey_12', variant: 'masculine') → 'assets/images/journeys/journey_12_masculine.png'
  static String buildJourneyImagePath(String journeyId, {String? variant}) {
    if (variant != null && variant.isNotEmpty) {
      return 'assets/images/journeys/${journeyId}_$variant.png';
    }
    return 'assets/images/journeys/${journeyId}_hero.png';
  }

  /// Get all image variants for a journey (base + gender variants)
  /// Useful for pre-caching images or checking availability
  static List<String> getJourneyImageVariants(JourneyV1 journey) {
    final variants = <String>[];

    if (journey.heroImage != null && journey.heroImage!.isNotEmpty) {
      variants.add(journey.heroImage!);

      // If gender-specific, also add the gender variants
      if (journey.allowedGenders.isNotEmpty) {
        final base = journey.heroImage!;
        if (base.contains('_hero.')) {
          variants.add(base.replaceFirst('_hero.', '_masculine.'));
          variants.add(base.replaceFirst('_hero.', '_feminine.'));
        }
      }
    }

    return variants;
  }
}
