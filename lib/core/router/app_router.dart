import 'package:nexus_app_min_test/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/app_shell.dart';
import 'package:nexus_app_min_test/safe_imports.dart';

import 'package:nexus_app_min_test/features/presentation/screens/_stubs/stories_stub_screen.dart';
import 'package:nexus_app_min_test/features/presentation/screens/_stubs/notifications_stub_screen.dart';
import 'package:nexus_app_min_test/features/presentation/screens/_stubs/contact_support_stub_screen.dart';
import 'package:nexus_app_min_test/features/presentation/screens/_stubs/chat_thread_stub_screen.dart';
import 'package:nexus_app_min_test/features/presentation/screens/_stubs/profile_view_stub_screen.dart';

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';

  // Dynamic routes: /chat/:id and /profile/:id
  final chatMatch = RegExp(r'^/chat/([^/]+)$').firstMatch(name);
  if (chatMatch != null) {
    final chatId = chatMatch.group(1)!;
    return MaterialPageRoute(builder: (_) => ChatThreadStubScreen(chatId: chatId));
  }

  final profileMatch = RegExp(r'^/profile/([^/]+)$').firstMatch(name);
  if (profileMatch != null) {
    final userId = profileMatch.group(1)!;
    return MaterialPageRoute(builder: (_) => ProfileViewStubScreen(userId: userId));
  }

  switch (name) {
    case AppRoutes.root:
      return MaterialPageRoute(builder: (_) => const AppShell());

    // Main tabs
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const HomeScreen());
    case AppRoutes.search:
      return MaterialPageRoute(builder: (_) => const SearchScreen());
    case AppRoutes.chats:
      return MaterialPageRoute(builder: (_) => const ChatsScreen());
    case AppRoutes.challenges:
      return MaterialPageRoute(builder: (_) => const ChallengesScreen());
    case AppRoutes.profile:
      return MaterialPageRoute(builder: (_) => const ProfileScreen());

    // Missing known routes (stubs)
    case AppRoutes.stories:
      return MaterialPageRoute(builder: (_) => const StoriesStubScreen());
    case AppRoutes.notifications:
      return MaterialPageRoute(builder: (_) => const NotificationsStubScreen());
    case AppRoutes.contactSupport:
      return MaterialPageRoute(builder: (_) => const ContactSupportStubScreen());

    default:
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(child: Text('Route not found: $name')),
        ),
      );
  }
}
