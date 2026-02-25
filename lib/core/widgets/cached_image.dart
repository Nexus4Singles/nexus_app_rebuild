import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:nexus_app_v2/core/theme/app_colors.dart';

// Simple in-memory cache manager that doesn't require sqflite
class _SimpleCacheManager extends CacheManager {
  static final instance = _SimpleCacheManager._();

  _SimpleCacheManager._()
    : super(
        Config(
          'nexus_simple_cache',
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 50,
        ),
      );
}

/// A cached image widget for DO Spaces and other URLs
/// Provides automatic disk caching with 30-day retention
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration cacheDuration;

  const CachedImage(
    this.imageUrl, {
    Key? key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.cacheDuration = const Duration(days: 30),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Guard against empty URLs
    if (imageUrl.isEmpty) {
      print('[CachedImage] Empty URL provided');
      return _buildPlaceholder();
    }

    // DEBUG: Loading image - skipped to reduce log noise

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      cacheKey: imageUrl, // Use URL as cache key for consistency
      // FIXED: Don't specify disk cache dimensions with custom CacheManager
      // A regular CacheManager can't resize images on disk
      // Memory cache is sufficient for our use case
      memCacheWidth: (width?.toInt() ?? 400) * 2, // 2x for high-DPI screens
      memCacheHeight: (height?.toInt() ?? 400) * 2,
      cacheManager: _SimpleCacheManager.instance,
      progressIndicatorBuilder: (context, url, downloadProgress) {
        // DEBUG: Loading progress - skipped to reduce log noise
        return placeholder ?? _buildLoadingPlaceholder();
      },
      errorWidget: (context, url, error) {
        // DEBUG: Error loading image - skipped to reduce log noise
        return errorWidget ?? _buildErrorPlaceholder();
      },
      imageBuilder: (context, imageProvider) {
        // DEBUG: Successfully loaded - skipped to reduce log noise
        return Image(
          image: imageProvider,
          fit: fit,
          width: width,
          height: height,
        );
      },
    );

    // Apply border radius if provided
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: borderRadius,
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.border,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.border,
      child: const Center(child: Icon(Icons.image_not_supported, size: 32)),
    );
  }
}

/// Cached image as DecorationImage for BoxDecoration
/// Useful for Container backgrounds
class CachedDecorationImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Gradient? overlayGradient;
  final Color? overlayColor;
  final Duration cacheDuration;

  const CachedDecorationImage({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.overlayGradient,
    this.overlayColor,
    this.cacheDuration = const Duration(days: 30),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: (width?.toInt() ?? 400) * 2,
      memCacheHeight: (height?.toInt() ?? 400) * 2,
      // FIXED: Don't specify disk cache dimensions with custom CacheManager
      cacheManager: _SimpleCacheManager.instance,
      progressIndicatorBuilder:
          (context, url, progress) => Container(
            width: width,
            height: height,
            color: AppColors.border,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget:
          (context, url, error) => Container(
            width: width,
            height: height,
            color: AppColors.border,
            child: const Center(child: Icon(Icons.image_not_supported)),
          ),
    );
  }
}

/// Avatar image with caching - optimized for small images
class CachedAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String? fallbackInitial;
  final Color? backgroundColor;
  final TextStyle? initialTextStyle;

  const CachedAvatarImage({
    Key? key,
    this.imageUrl,
    this.size = 48,
    this.fallbackInitial,
    this.backgroundColor,
    this.initialTextStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildInitialCircle();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      imageBuilder:
          (context, imageProvider) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
      placeholder:
          (context, url) => CircleAvatar(
            radius: size / 2,
            backgroundColor: AppColors.border,
            child: const Icon(Icons.person, size: 24),
          ),
      errorWidget: (context, url, error) => _buildInitialCircle(),
      memCacheWidth: size.toInt() * 2,
      memCacheHeight: size.toInt() * 2,
      // FIXED: Don't specify disk cache dimensions with custom CacheManager
      cacheManager: _SimpleCacheManager.instance,
    );
  }

  Widget _buildInitialCircle() {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? AppColors.border,
      child:
          fallbackInitial != null
              ? Text(
                fallbackInitial!,
                style:
                    initialTextStyle ??
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textOnPrimary,
                    ),
              )
              : const Icon(Icons.person, size: 24),
    );
  }
}
