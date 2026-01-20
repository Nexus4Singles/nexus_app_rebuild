import 'package:flutter/material.dart';

import '../../app_shell.dart';
import 'placeholder_screen.dart';

import '../constants/app_constants.dart';

import '../../features/presentation/screens/home_screen.dart';
import '../../features/presentation/screens/search_screen.dart';
import '../../features/presentation/screens/chats_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_age_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_extra_info_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_photos_stub_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_audio_stub_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_audio_question_stub_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_audio_summary_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_hobbies_stub_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_qualities_stub_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_contact_info_stub_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_profile_complete_screen.dart';
import '../../features/presentation/screens/settings_screen.dart';
import '../../features/presentation/screens/contact_screen.dart';
import '../../features/presentation/screens/privacy_policy_screen.dart';
import '../../features/presentation/screens/terms_screen.dart';
import '../../features/presentation/screens/blocked_users_screen.dart';
import '../../features/presentation/screens/contact_support_screen.dart';
import '../../features/presentation/screens/help_center_screen.dart';

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
import '../../features/compatibility_quiz/presentation/screens/compatibility_quiz_screen.dart';

import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';

import '../../features/presentation/screens/_stubs/onboarding_stub_screen.dart';
import '../../features/presentation/screens/_stubs/notifications_stub_screen.dart';

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

  // /dating/setup/audio/qN
  if (segments.length == 4 &&
      segments[0] == 'dating' &&
      segments[1] == 'setup' &&
      segments[2] == 'audio' &&
      segments[3].startsWith('q')) {
    final raw = segments[3].substring(1);
    final n = int.tryParse(raw);
    if (n != null && n > 0) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DatingAudioQuestionStubScreen(questionNumber: n),
      );
    }
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

  
  // Dynamic profile route: /profile/<userId>
  final routeName = settings.name ?? '';
  if (routeName.startsWith('/profile/')) {
    final parts = Uri.parse(routeName).pathSegments;
    if (parts.length >= 2) {
      final userId = parts[1];
      if (userId.isNotEmpty) {
        return MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: userId),
          settings: settings,
        );
      }
    }
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

    case '/dating/setup/age':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DatingAgeScreen(),
      );

    case '/dating/setup/extra-info':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DatingExtraInfoScreen(),
      );

    case '/dating/setup/photos':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DatingPhotosStubScreen(),
      );

    case '/dating/setup/audio':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DatingAudioStubScreen(),
      );

    case '/dating/setup/audio/summary':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DatingAudioSummaryScreen(),
      );

    case '/dating/setup/hobbies':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DatingHobbiesStubScreen(),
      );

    case '/dating/setup/qualities':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DatingQualitiesStubScreen(),
      );

    case '/dating/setup/contact-info':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DatingContactInfoStubScreen(),
      );

    case '/dating/setup/complete':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DatingProfileCompleteScreen(),
      );

    case '/dating-profile/complete':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DatingProfileCompleteScreen(),
      );

    case '/settings':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const SettingsScreen(),
      );

    case '/help':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const HelpCenterScreen(),
      );

    case '/blocked-users':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const BlockedUsersScreen(),
      );

    case '/terms':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const TermsScreen(),
      );

    case '/privacy':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const PrivacyPolicyScreen(),
      );
    case '/signup':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const SignupScreen(),
      );

    case '/login':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const LoginScreen(),
      );

    case '/forgot-password':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ForgotPasswordScreen(),
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

    case '/contact':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ContactScreen(),
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
    case '/compatibility-quiz':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const CompatibilityQuizScreen(),
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
