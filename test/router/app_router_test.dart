import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app_v2/core/router/app_router.dart';
import 'package:nexus_app_v2/core/router/app_routes.dart';
import 'package:nexus_app_v2/core/router/placeholder_screen.dart';

Route<dynamic> _resolve(String routeName) {
  return onGenerateRoute(RouteSettings(name: routeName));
}

void main() {
  group('onGenerateRoute', () {
    test('resolves known static route: /signup', () {
      final route = _resolve('/signup');
      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect(route.settings.name, '/signup');
    });

    test('resolves dynamic route: /chats/:chatId', () {
      final route = _resolve('/chats/abc');
      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect(route.settings.name, '/chats/abc');
    });

    test('resolves dynamic route: /profile/:userId', () {
      final route = _resolve('/profile/u123');
      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect(route.settings.name, '/profile/u123');
    });

    test('resolves dynamic route: /journey/:id', () {
      final route = _resolve('/journey/p987');
      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect(route.settings.name, '/journey/p987');
    });

    test('resolves dynamic route: /journey/:id/activity/:missionId', () {
      final route = _resolve('/journey/p987/activity/2');
      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect(route.settings.name, '/journey/p987/activity/2');
    });

    test('resolves known static route: AppNavRoutes.assessments', () {
      final route = _resolve(AppRoutes.assessments);
      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect(route.settings.name, AppRoutes.assessments);
    });

    testWidgets('unknown route resolves to fallback placeholder', (
      tester,
    ) async {
      final route = _resolve('/does-not-exist') as MaterialPageRoute<dynamic>;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return route.builder(context);
            },
          ),
        ),
      );

      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.textContaining('Unknown route:'), findsOneWidget);
    });
  });
}
