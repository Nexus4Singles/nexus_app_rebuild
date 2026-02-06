import 'package:flutter/material.dart';

class GradientPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const GradientPill({
    required this.text,
    this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [backgroundColor, backgroundColor.withOpacity(0.7)],
        ),
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: textColor.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 12, color: textColor),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
              fontSize: 12,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}
