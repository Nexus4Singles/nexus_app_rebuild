import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single selectable chip
class AppChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? selectedColor;
  final Color? unselectedColor;
  final bool enabled;

  const AppChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
    this.selectedColor,
    this.unselectedColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isSelected
            ? (selectedColor ?? AppColors.primary)
            : (unselectedColor ?? AppColors.surfaceDark);
    final textColor = isSelected ? Colors.white : AppColors.textPrimary;
    final borderColor =
        isSelected ? (selectedColor ?? AppColors.primary) : AppColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: AnimatedContainer(
          duration: AppSpacing.durationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: textColor),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.check, size: 16, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-select chip group
class AppChipSelector<T> extends StatelessWidget {
  final List<T> options;
  final T? selectedValue;
  final ValueChanged<T> onSelected;
  final String Function(T) labelBuilder;
  final IconData? Function(T)? iconBuilder;
  final Color? selectedColor;
  final bool wrap;
  final double spacing;
  final double runSpacing;
  final bool enabled;

  const AppChipSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.labelBuilder,
    this.iconBuilder,
    this.selectedColor,
    this.wrap = true,
    this.spacing = AppSpacing.sm,
    this.runSpacing = AppSpacing.sm,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final chips =
        options.map((option) {
          return AppChip(
            label: labelBuilder(option),
            isSelected: selectedValue == option,
            icon: iconBuilder?.call(option),
            selectedColor: selectedColor,
            enabled: enabled,
            onTap: enabled ? () => onSelected(option) : null,
          );
        }).toList();

    if (wrap) {
      return Wrap(spacing: spacing, runSpacing: runSpacing, children: chips);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            chips
                .map(
                  (chip) => Padding(
                    padding: EdgeInsets.only(right: spacing),
                    child: chip,
                  ),
                )
                .toList(),
      ),
    );
  }
}

/// Multi-select chip group
class AppMultiChipSelector<T> extends StatelessWidget {
  final List<T> options;
  final List<T> selectedValues;
  final ValueChanged<List<T>> onChanged;
  final String Function(T) labelBuilder;
  final IconData? Function(T)? iconBuilder;
  final Color? selectedColor;
  final bool wrap;
  final double spacing;
  final double runSpacing;
  final int? maxSelections;
  final bool enabled;

  const AppMultiChipSelector({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    required this.labelBuilder,
    this.iconBuilder,
    this.selectedColor,
    this.wrap = true,
    this.spacing = AppSpacing.sm,
    this.runSpacing = AppSpacing.sm,
    this.maxSelections,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final chips =
        options.map((option) {
          final isSelected = selectedValues.contains(option);
          final canSelect =
              maxSelections == null ||
              selectedValues.length < maxSelections! ||
              isSelected;

          return AppChip(
            label: labelBuilder(option),
            isSelected: isSelected,
            icon: iconBuilder?.call(option),
            selectedColor: selectedColor,
            enabled: enabled && canSelect,
            onTap:
                enabled && canSelect
                    ? () {
                      final newSelection = List<T>.from(selectedValues);
                      if (isSelected) {
                        newSelection.remove(option);
                      } else {
                        newSelection.add(option);
                      }
                      onChanged(newSelection);
                    }
                    : null,
          );
        }).toList();

    if (wrap) {
      return Wrap(spacing: spacing, runSpacing: runSpacing, children: chips);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            chips
                .map(
                  (chip) => Padding(
                    padding: EdgeInsets.only(right: spacing),
                    child: chip,
                  ),
                )
                .toList(),
      ),
    );
  }
}

/// Large option card for survey-style selections
class AppOptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? selectedColor;
  final bool enabled;

  const AppOptionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.selectedColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: AnimatedContainer(
          duration: AppSpacing.durationFast,
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? color.withOpacity(0.2)
                            : AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isSelected ? color : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? color : AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedContainer(
                duration: AppSpacing.durationFast,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? color : AppColors.border,
                    width: 2,
                  ),
                ),
                child:
                    isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Option card selector (single select)
class AppOptionCardSelector<T> extends StatelessWidget {
  final List<T> options;
  final T? selectedValue;
  final ValueChanged<T> onSelected;
  final String Function(T) titleBuilder;
  final String? Function(T)? subtitleBuilder;
  final IconData? Function(T)? iconBuilder;
  final Color? selectedColor;
  final double spacing;
  final bool enabled;

  const AppOptionCardSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.titleBuilder,
    this.subtitleBuilder,
    this.iconBuilder,
    this.selectedColor,
    this.spacing = AppSpacing.sm,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          options.map((option) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: AppOptionCard(
                title: titleBuilder(option),
                subtitle: subtitleBuilder?.call(option),
                icon: iconBuilder?.call(option),
                isSelected: selectedValue == option,
                selectedColor: selectedColor,
                enabled: enabled,
                onTap: enabled ? () => onSelected(option) : null,
              ),
            );
          }).toList(),
    );
  }
}
