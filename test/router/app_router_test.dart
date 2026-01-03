import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/router/app_router.dart';
import 'package:nexus_app_min_test/core/constants/app_constants.dart';

Widget _buildAppWithRoute(String routeName) {
  return ProviderScope(
    child: MaterialApp(
      onGenerateRoute: onGenerateRoute,
      initialRoute: routeName,
    ),
  );
}

Future<void> _pumpRoute(WidgetTester tester, String routeName) async {
  await tester.pumpWidget(_buildAppWithRoute(routeName));
  await tester.pumpAndSettle();
}

void main() {
  group('onGenerateRoute', () {
    testWidgets('resolves known static route: AppNavRoutes.home', (tester) async {
      await _pumpRoute(tester, AppNavRoutes.home);
      expect(find.byType(PlaceholderScreen), findsNothing);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('resolves dynamic route: /chats/:chatId', (tester) async {
      await _pumpRoute(tester, '/chats/abc');
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.textContaining('Chat (chatId: abc)'), findsOneWidget);
    });

    testWidgets('resolves dynamic route: /profile/:userId', (tester) async {
      await _pumpRoute(tester, '/profile/u123');
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.textContaining('Profile (userId: u123)'), findsOneWidget);
    });

    testWidgets('resolves dynamic route: /journey/:productId', (tester) async {
      await _pumpRoute(tester, '/journey/p987');
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.textContaining('Journey (productId: p987)'), findsOneWidget);
    });

    testWidgets('resolves dynamic route: /journey/:productId/session/:sessionNumber', (tester) async {
      await _pumpRoute(tester, '/journey/p987/session/2');
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.textContaining('Journey Session (productId: p987, session: 2)'), findsOneWidget);
    });

    testWidgets('resolves dynamic route: /story/:storyId', (tester) async {
      await _pumpRoute(tester, '/story/s55');
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.textContaining('Story (storyId: s55)'), findsOneWidget);
    });

    testWidgets('resolves dynamic route: /story/:storyId/poll', (tester) async {
      await _pumpRoute(tester, '/story/s55/poll');
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.textContaining('Story Poll (storyId: s55)'), findsOneWidget);
    });

    testWidgets('unknown route resolves to fallback placeholder', (tester) async {
      await _pumpRoute(tester, '/does-not-exist');
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.textContaining('Not Found:'), findsOneWidget);
    });
  });
}
