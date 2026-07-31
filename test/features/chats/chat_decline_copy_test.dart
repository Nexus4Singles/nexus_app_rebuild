import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app_v2/features/chats/presentation/screens/chat_thread_decline_utils.dart';

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

    test('returns a friendly fallback status for declined messages', () {
      expect(buildDeclineStatusText(''), 'Polite response sent');
      expect(
        buildDeclineStatusText('Already chatting with someone'),
        'Response sent',
      );
    });
  });
}
