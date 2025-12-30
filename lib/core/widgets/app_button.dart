import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outline, text, danger }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isExpanded;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.width,
  });

  /// Primary action button
  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.width,
  }) : variant = AppButtonVariant.primary;

  /// Secondary action button
  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.width,
  }) : variant = AppButtonVariant.secondary;

  /// Outline button
  const AppButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.width,
  }) : variant = AppButtonVariant.outline;

  /// Text button (minimal)
  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.width,
  }) : variant = AppButtonVariant.text;

  /// Danger/destructive action button
  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = false,
    this.width,
  }) : variant = AppButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle(context);
    final textStyle = _getTextStyle();
    final iconSize = _getIconSize();
    final padding = _getPadding();
    final height = _getHeight();

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_getLoadingColor()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: iconSize),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(label, style: textStyle),
        if (trailingIcon != null && !isLoading) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: iconSize),
        ],
      ],
    );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.danger:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle.copyWith(
            padding: WidgetStateProperty.all(padding),
            minimumSize: WidgetStateProperty.all(Size(0, height)),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.outline:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle.copyWith(
            padding: WidgetStateProperty.all(padding),
            minimumSize: WidgetStateProperty.all(Size(0, height)),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle.copyWith(
            padding: WidgetStateProperty.all(padding),
            minimumSize: WidgetStateProperty.all(Size(0, height)),
          ),
          child: child,
        );
        break;
    }

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    return button;
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        );
      case AppButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.secondary.withOpacity(0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        );
      case AppButtonVariant.outline:
        return OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.primary.withOpacity(0.5),
          side: BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        );
      case AppButtonVariant.text:
        return TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        );
      case AppButtonVariant.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.error.withOpacity(0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case AppButtonSize.small:
        return AppTextStyles.buttonSmall;
      case AppButtonSize.medium:
        return AppTextStyles.buttonMedium;
      case AppButtonSize.large:
        return AppTextStyles.buttonLarge;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md);
    }
  }

  double _getHeight() {
    switch (size) {
      case AppButtonSize.small:
        return 36;
      case AppButtonSize.medium:
        return 48;
      case AppButtonSize.large:
        return 56;
    }
  }

  Color _getLoadingColor() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.danger:
        return Colors.white;
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return AppColors.primary;
    }
  }
}
