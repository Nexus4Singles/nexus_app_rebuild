import 'package:flutter/material.dart';

import '../../app_shell.dart';
import 'placeholder_screen.dart';

import '../constants/app_constants.dart';

import '../../features/presentation/screens/home_screen.dart';
import '../../features/presentation/screens/search_screen.dart';
import '../../features/presentation/screens/chats_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/presentation/screens/settings_screen.dart';

import 'app_routes.dart';

import '../../features/stories/presentation/screens/stories_screen.dart';
import '../../features/stories/presentation/screens/story_detail_screen.dart';

import '../../features/challenges/presentation/screens/challenges_screen.dart';
import '../../features/challenges/presentation/screens/journey_detail_screen.dart';
import '../../features/challenges/presentation/screens/journey_gate_screen.dart';

import '../../features/assessment/presentation/screens/assessments_hub_screen.dart';
import '../../features/assessment/presentation/screens/assessment_intro_screen.dart';
import '../../features/assessment/presentation/screens/assessment_screen.dart';
import '../../features/assessment/presentation/screens/assessment_result_screen.dart';

import '../../features/chats/presentation/screens/chat_thread_screen.dart';

import '../../features/presentation/screens/_stubs/signup_stub_screen.dart';
import '../../features/presentation/screens/_stubs/login_stub_screen.dart';
import '../../features/presentation/screens/_stubs/forgot_password_stub_screen.dart';
import '../../features/presentation/screens/_stubs/onboarding_stub_screen.dart';
import '../../features/presentation/screens/_stubs/notifications_stub_screen.dart';
import '../../features/presentation/screens/_stubs/contact_support_stub_screen.dart';

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';

  // Ignore external scheme deeplinks for stability.
  if (name.contains('://')) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const AppShell(),
    );
  }

  final uri = Uri.parse(name);
  final segments = uri.pathSegments;

  // /chats/:chatId
  if (segments.length == 2 && segments[0] == 'chats') {
    final chatId = segments[1];
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => ChatThreadScreen(chatId: chatId),
    );
  }

  // /journey/:id/mission/:missionId  OR  /journey/:id/activity/:missionId
  if (segments.length == 4 &&
      segments[0] == 'journey' &&
      (segments[2] == 'mission' || segments[2] == 'activity')) {
    final journeyId = segments[1];
    final missionId = segments[3];
    return MaterialPageRoute(
      settings: settings,
      builder:
          (_) => JourneyGateScreen(journeyId: journeyId, missionId: missionId),
    );
  }

  // /journey/:id
  if (segments.length == 2 && segments[0] == 'journey') {
    final journeyId = segments[1];
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => JourneyDetailScreen(id: journeyId),
    );
  }

  switch (uri.path) {
    case '/':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const AppShell(),
      );

    case '/home':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const HomeScreen(),
      );

    case '/search':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const SearchScreen(),
      );

    case '/chats':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ChatsScreen(),
      );
    case '/profile':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ProfileScreen(),
      );

    case '/settings':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const SettingsScreen(),
      );

    case '/signup':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const SignupStubScreen(),
      );

    case '/login':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const LoginStubScreen(),
      );

    case '/forgot-password':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ForgotPasswordStubScreen(),
      );

    case '/onboarding':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const OnboardingStubScreen(),
      );

    case '/notifications':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const NotificationsStubScreen(),
      );

    case '/contact-support':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ContactSupportStubScreen(),
      );

    case AppRoutes.stories:
      return MaterialPageRoute(
        settings: settings,

        builder: (_) => const StoriesScreen(),
      );

    case AppRoutes.challenges:
      return MaterialPageRoute(
        settings: settings,

        builder: (_) => const ChallengesScreen(),
      );

    case AppRoutes.assessments:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const AssessmentsHubScreen(),
      );

    case AppRoutes.assessmentIntro:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => AssessmentIntroScreen(),
      );

    case AppRoutes.assessment:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => AssessmentScreen(),
      );

    case AppRoutes.assessmentResult:
      return MaterialPageRoute(
        settings: settings,

        builder: (_) => const AssessmentResultScreen(),
      );

    default:
      return MaterialPageRoute(
        settings: settings,
        builder:
            (_) => PlaceholderScreen(
              title: 'Not found',
              message: 'Unknown route: $name',
            ),
      );
  }
}
