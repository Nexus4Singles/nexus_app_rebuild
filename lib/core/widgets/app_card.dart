import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppCardVariant { elevated, outlined, filled }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool showShadow;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.elevated,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderRadius,
    this.showShadow = true,
  });

  /// Elevated card with shadow
  const AppCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderRadius,
    this.showShadow = true,
  }) : variant = AppCardVariant.elevated;

  /// Outlined card with border
  const AppCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderRadius,
  }) : variant = AppCardVariant.outlined, showShadow = false;

  /// Filled card with background color
  const AppCard.filled({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderRadius,
  }) : variant = AppCardVariant.filled, showShadow = false;

  @override
  Widget build(BuildContext context) {
    final defaultPadding = padding ?? const EdgeInsets.all(AppSpacing.base);
    final defaultRadius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd);
    
    BoxDecoration decoration;
    switch (variant) {
      case AppCardVariant.elevated:
        decoration = BoxDecoration(
          color: backgroundColor ?? AppColors.surfaceLight,
          borderRadius: defaultRadius,
          boxShadow: showShadow ? AppSpacing.shadowMd : null,
        );
        break;
      case AppCardVariant.outlined:
        decoration = BoxDecoration(
          color: backgroundColor ?? AppColors.surfaceLight,
          borderRadius: defaultRadius,
          border: Border.all(color: AppColors.border),
        );
        break;
      case AppCardVariant.filled:
        decoration = BoxDecoration(
          color: backgroundColor ?? AppColors.surfaceDark,
          borderRadius: defaultRadius,
        );
        break;
    }

    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: defaultRadius,
        child: Padding(
          padding: defaultPadding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: defaultRadius,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// A card with an image header
class AppImageCard extends StatelessWidget {
  final String? imageUrl;
  final Widget? imagePlaceholder;
  final double imageHeight;
  final Widget child;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AppImageCard({
    super.key,
    this.imageUrl,
    this.imagePlaceholder,
    this.imageHeight = 160,
    required this.child,
    this.contentPadding,
    this.margin,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final defaultRadius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: defaultRadius,
        boxShadow: AppSpacing.shadowMd,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: defaultRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image header
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: defaultRadius.topLeft,
                  topRight: defaultRadius.topRight,
                ),
                child: SizedBox(
                  height: imageHeight,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              imagePlaceholder ?? _defaultPlaceholder(),
                        )
                      : imagePlaceholder ?? _defaultPlaceholder(),
                ),
              ),
              // Content
              Padding(
                padding: contentPadding ?? const EdgeInsets.all(AppSpacing.base),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: AppColors.surfaceDark,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// A card for displaying list items
class AppListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AppCardVariant variant;

  const AppListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.margin,
    this.variant = AppCardVariant.elevated,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: variant,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      margin: margin,
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
