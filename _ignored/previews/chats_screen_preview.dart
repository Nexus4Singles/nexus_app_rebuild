import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ChatsScreenPreview extends StatelessWidget {
  const ChatsScreenPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Chats", style: t.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Preview-only Chats UI (no backend yet).",
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            _ChatTile(
              name: "Nexus Community",
              message: "Welcome! This is a preview chat thread.",
              time: "9:41 AM",
              badge: "2",
            ),
            const SizedBox(height: AppSpacing.md),
            _ChatTile(
              name: "Support",
              message: "How can we help you today?",
              time: "Yesterday",
            ),
            const SizedBox(height: AppSpacing.md),
            _ChatTile(
              name: "Prayer Partner",
              message: "Praying with you 🙏",
              time: "Mon",
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final String? badge;

  const _ChatTile({
    required this.name,
    required this.message,
    required this.time,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: t.titleMedium?.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.titleMedium),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
              if (badge != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: t.labelSmall?.copyWith(color: Colors.white),
                  ),
                )
              ],
            ],
          ),
        ],
      ),
    );
  }
}
