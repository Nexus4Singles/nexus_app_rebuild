import 'package:flutter/material.dart';

class ActivityNumberBadge extends StatelessWidget {
  final int number;
  final bool isCompleted;
  final bool isLocked;

  const ActivityNumberBadge({
    required this.number,
    this.isCompleted = false,
    this.isLocked = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    Color bgColor =
        isCompleted ? secondary.withOpacity(0.15) : primary.withOpacity(0.15);
    Color borderColor =
        isCompleted ? secondary.withOpacity(0.25) : primary.withOpacity(0.25);
    Color textColor = isCompleted ? secondary : primary;

    if (isLocked) {
      bgColor = primary.withOpacity(0.08);
      borderColor = primary.withOpacity(0.12);
      textColor = primary.withOpacity(0.60);
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgColor, bgColor.withOpacity(0.7)],
        ),
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: textColor.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: Center(
        child:
            isCompleted
                ? Icon(Icons.check, size: 18, color: textColor)
                : isLocked
                ? Icon(Icons.lock_outline, size: 14, color: textColor)
                : Text(
                  '$number',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
      ),
    );
  }
}
