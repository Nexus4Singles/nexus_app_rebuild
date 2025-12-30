import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class ChatDetailScreen extends StatelessWidget {
  final String name;

  const ChatDetailScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(name, style: AppTextStyles.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Safe Mode chat detail screen.\n\nLater: wire to real chat stream + Firestore.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _Bubble(
                    text: 'Hi 👋 Welcome to Nexus.',
                    isMe: false,
                  ),
                  _Bubble(
                    text: 'Thanks — just testing the rebuild!',
                    isMe: true,
                  ),
                  _Bubble(
                    text: 'Perfect. Firebase will return later safely.',
                    isMe: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.send, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const _Bubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withOpacity(0.7)),
        ),
        child: Text(text, style: AppTextStyles.bodyMedium),
      ),
    );
  }
}
