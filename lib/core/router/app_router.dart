import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/app_shell.dart';
import 'package:nexus_app_min_test/safe_imports.dart';

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const AppShell());
    case '/home':
      return MaterialPageRoute(builder: (_) => const HomeScreen());
    case '/search':
      return MaterialPageRoute(builder: (_) => const SearchScreen());
    case '/chats':
      return MaterialPageRoute(builder: (_) => const ChatsScreen());
    case '/challenges':
      return MaterialPageRoute(builder: (_) => const ChallengesScreen());
    case '/profile':
      return MaterialPageRoute(builder: (_) => const ProfileScreen());
    default:
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(child: Text('Route not found: ${settings.name}')),
        ),
      );
  }
}
