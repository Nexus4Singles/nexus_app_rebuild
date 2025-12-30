import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/safe_providers/chats_provider_safe.dart';
import 'package:nexus_app_min_test/features/presentation/screens/chats_detail_screen.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(safeChatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Chats', style: AppTextStyles.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent conversations', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: chats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return _ChatRow(
                    name: chat.name,
                    message: chat.message,
                    time: chat.time,
                    unread: chat.unread,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(name: chat.name),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  const _ChatRow({
    required this.name,
    required this.message,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.chat_bubble, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppTextStyles.labelLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(time, style: AppTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color:
                            unread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (unread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
