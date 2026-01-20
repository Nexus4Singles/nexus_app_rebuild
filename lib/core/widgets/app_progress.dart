import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Linear progress bar with optional percentage label
class AppLinearProgress extends StatelessWidget {
  final double progress;
  final double height;
  final Color? progressColor;
  final Color? backgroundColor;
  final bool showPercentage;
  final BorderRadius? borderRadius;

  const AppLinearProgress({
    super.key,
    required this.progress,
    this.height = 8,
    this.progressColor,
    this.backgroundColor,
    this.showPercentage = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final defaultRadius = borderRadius ?? BorderRadius.circular(height / 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPercentage) ...[
          Text(
            '${(clampedProgress * 100).toInt()}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.surfaceDark,
            borderRadius: defaultRadius,
          ),
          child: Stack(
            children: [
              AnimatedFractionallySizedBox(
                duration: AppSpacing.durationMedium,
                curve: AppSpacing.curveStandard,
                widthFactor: clampedProgress,
                child: Container(
                  decoration: BoxDecoration(
                    color: progressColor ?? AppColors.primary,
                    borderRadius: defaultRadius,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular progress indicator with percentage in center
class AppCircularProgress extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? backgroundColor;
  final bool showPercentage;
  final Widget? child;

  const AppCircularProgress({
    super.key,
    required this.progress,
    this.size = 80,
    this.strokeWidth = 8,
    this.progressColor,
    this.backgroundColor,
    this.showPercentage = true,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                backgroundColor ?? AppColors.surfaceDark,
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clampedProgress),
              duration: AppSpacing.durationMedium,
              curve: AppSpacing.curveStandard,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    progressColor ?? AppColors.primary,
                  ),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          // Center content
          if (child != null)
            child!
          else if (showPercentage)
            Text(
              '${(clampedProgress * 100).toInt()}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Step progress indicator (1, 2, 3...)
class AppStepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? completedColor;
  final double stepSize;
  final double lineHeight;

  const AppStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
    this.activeColor,
    this.inactiveColor,
    this.completedColor,
    this.stepSize = 32,
    this.lineHeight = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isEven) {
          // Step circle
          final stepNumber = index ~/ 2 + 1;
          return _buildStep(context, stepNumber);
        } else {
          // Connector line
          final beforeStep = index ~/ 2 + 1;
          return _buildConnector(beforeStep);
        }
      }),
    );
  }

  Widget _buildStep(BuildContext context, int stepNumber) {
    final isCompleted = stepNumber < currentStep;
    final isActive = stepNumber == currentStep;

    Color bgColor;
    Color textColor;
    Widget content;

    if (isCompleted) {
      bgColor = completedColor ?? AppColors.accent;
      textColor = Colors.white;
      content = Icon(Icons.check, size: stepSize * 0.5, color: textColor);
    } else if (isActive) {
      bgColor = activeColor ?? AppColors.primary;
      textColor = Colors.white;
      content = Text(
        stepNumber.toString(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: stepSize * 0.4,
        ),
      );
    } else {
      bgColor = inactiveColor ?? AppColors.surfaceDark;
      textColor = AppColors.textMuted;
      content = Text(
        stepNumber.toString(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: stepSize * 0.4,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: stepSize,
          height: stepSize,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Center(child: content),
        ),
        if (stepLabels != null && stepNumber <= stepLabels!.length) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            stepLabels![stepNumber - 1],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isActive ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnector(int beforeStep) {
    final isCompleted = beforeStep < currentStep;

    return Expanded(
      child: Container(
        height: lineHeight,
        color:
            isCompleted
                ? (completedColor ?? AppColors.accent)
                : (inactiveColor ?? AppColors.surfaceDark),
      ),
    );
  }
}

/// Question progress dots (for assessments)
class AppQuestionProgress extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final Map<int, bool>? answeredQuestions;
  final double dotSize;
  final double spacing;

  const AppQuestionProgress({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
    this.answeredQuestions,
    this.dotSize = 8,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: List.generate(totalQuestions, (index) {
        final isAnswered = answeredQuestions?[index] ?? false;
        final isCurrent = index == currentQuestion;

        Color dotColor;
        if (isCurrent) {
          dotColor = AppColors.primary;
        } else if (isAnswered) {
          dotColor = AppColors.accent;
        } else {
          dotColor = AppColors.surfaceDark;
        }

        return AnimatedContainer(
          duration: AppSpacing.durationFast,
          width: isCurrent ? dotSize * 2 : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: BorderRadius.circular(dotSize / 2),
          ),
        );
      }),
    );
  }
}

/// Streak/badge progress indicator
class AppStreakIndicator extends StatelessWidget {
  final int current;
  final int target;
  final IconData icon;
  final String label;
  final Color? color;

  const AppStreakIndicator({
    super.key,
    required this.current,
    required this.target,
    this.icon = Icons.local_fire_department,
    this.label = 'Day Streak',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / target).clamp(0.0, 1.0);
    final displayColor = color ?? AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: displayColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: displayColor, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$current / $target',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: displayColor,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 40,
            height: 40,
            child: AppCircularProgress(
              progress: progress,
              size: 40,
              strokeWidth: 4,
              progressColor: displayColor,
              showPercentage: false,
              child: Icon(
                Icons.emoji_events,
                size: 18,
                color: progress >= 1.0 ? displayColor : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
