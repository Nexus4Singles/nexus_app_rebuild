import 'package:flutter_riverpod/flutter_riverpod.dart';

class SafeChatItem {
  final String name;
  final String message;
  final String time;
  final bool unread;

  const SafeChatItem({
    required this.name,
    required this.message,
    required this.time,
    required this.unread,
  });
}

final safeChatsProvider = Provider<List<SafeChatItem>>((ref) {
  return const [
    SafeChatItem(
      name: 'Nexus Coach',
      message: 'Your next session is ready.',
      time: '2m',
      unread: true,
    ),
    SafeChatItem(
      name: 'Support',
      message: 'How can we help you today?',
      time: '1h',
      unread: false,
    ),
    SafeChatItem(
      name: 'Community',
      message: 'New story posted in Relationships.',
      time: 'Yesterday',
      unread: false,
    ),
  ];
});
