import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app_v2/features/chats/presentation/screens/chat_thread_decline_utils.dart';

class _ExampleMessage {
  final bool isMe;
  final bool isDeclined;
  final String? messageId;
  final String? senderId;

  const _ExampleMessage({
    required this.isMe,
    required this.isDeclined,
    this.messageId,
    this.senderId,
  });
}

void main() {
  group('chat decline copy', () {
    test('uses a clear button label for the decline action', () {
      expect(buildDeclineButtonLabel(), 'Decline');
    });

    test('builds a short notification body for common decline reasons', () {
      expect(
        buildDeclineNotificationBody(
          'alice',
          'Looking for different connections',
        ),
        '@alice is looking for a different type of connection at this time',
      );
      expect(
        buildDeclineNotificationBody('bob', 'Not a good fit for me right now'),
        '@bob doesn\'t think they are a good fit for you',
      );
      expect(
        buildDeclineNotificationBody('carol', 'Already chatting with someone'),
        '@carol is occupied with someone else at the moment',
      );
    });

    test('finds the latest incoming non-declined message target', () {
      final items = [
        const _ExampleMessage(
          isMe: false,
          isDeclined: false,
          messageId: 'first',
          senderId: 'user-a',
        ),
        const _ExampleMessage(
          isMe: true,
          isDeclined: false,
          messageId: 'second',
          senderId: 'me',
        ),
        const _ExampleMessage(
          isMe: false,
          isDeclined: true,
          messageId: 'third',
          senderId: 'user-b',
        ),
      ];

      final target = findLatestIncomingDeclineTarget<_ExampleMessage>(
        items: items,
        isMe: (item) => item.isMe,
        isDeclined: (item) => item.isDeclined,
        messageId: (item) => item.messageId,
        senderId: (item) => item.senderId,
      );

      expect(target?.messageId, 'first');
      expect(target?.senderId, 'user-a');
    });

    test('returns a friendly fallback status for declined messages', () {
      expect(buildDeclineStatusText(''), 'Polite response sent');
      expect(
        buildDeclineStatusText('Already chatting with someone'),
        'Response sent',
      );
    });
  });
}
