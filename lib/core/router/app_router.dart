import 'package:flutter/material.dart';

import '../../app_shell.dart';
import 'placeholder_screen.dart';

import '../constants/app_constants.dart';
import '../widgets/disabled_account_gate.dart';

import '../../features/launch/presentation/screens/home_screen.dart';
import '../../features/dating_search/presentation/screens/search_screen.dart';
import '../../features/launch/presentation/screens/onboarding_screen.dart';
import '../../features/dating_search/presentation/screens/new_dating_search_screen.dart';
import '../../features/chats/presentation/screens/chats_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_age_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_extra_info_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_photos_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_audio_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_audio_question_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_audio_summary_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_hobbies_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_qualities_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_contact_info_screen.dart';
import '../../features/dating_onboarding/presentation/screens/dating_profile_complete_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/contact_screen.dart';
import '../../features/profile/presentation/screens/privacy_policy_screen.dart';
import '../../features/profile/presentation/screens/terms_screen.dart';
import '../../features/chats/presentation/screens/blocked_users_screen.dart';
import '../../features/profile/presentation/screens/help_center_screen.dart';

import 'app_routes.dart';

import '../../features/stories/presentation/screens/stories_screen.dart';
import '../../features/stories/presentation/screens/story_detail_screen.dart';

import '../../features/challenges/presentation/screens/challenges_screen.dart';
import '../../features/challenges/presentation/screens/journey_detail_screen.dart';
import '../../features/challenges/presentation/screens/journey_gate_screen.dart';
import '../../features/challenges/domain/journey_v1_models.dart';

import '../../features/subscription/presentation/screens/journey_purchase_screen.dart';
import '../../features/counselling/presentation/screens/book_marriage_coach_screen.dart';
import '../../features/counselling/presentation/screens/coach_list_screen.dart';
import '../../features/counselling/presentation/screens/my_bookings_screen.dart';
import '../../features/counselling/presentation/screens/coach_dashboard_screen.dart';
import '../../features/counselling/domain/counselling_models.dart';

import '../../features/assessment/presentation/screens/assessments_hub_screen.dart';
import '../../features/assessment/presentation/screens/assessment_intro_screen.dart';
import '../../features/assessment/presentation/screens/assessment_screen.dart';
import '../../features/assessment/presentation/screens/assessment_result_screen.dart';

import '../../features/chats/presentation/screens/chat_thread_screen.dart';
import '../../features/compatibility_quiz/presentation/screens/compatibility_quiz_screen.dart';

import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/launch/presentation/app_launch_gate.dart'
    show AuthEntryScreen;

import '../../features/admin_review/presentation/screens/admin_review_queue_screen.dart';

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';

  // Handle custom scheme deeplinks (nexusapp://...)
  if (name.contains('nexusapp://')) {
    final uri = Uri.parse(name);

    // nexusapp://story/{storyId}
    if (uri.host == 'story' && uri.pathSegments.isNotEmpty) {
      final storyId = uri.pathSegments[0];
      debugPrint('[AppRouter] Custom scheme deeplink resolved: story/$storyId');
      return MaterialPageRoute(
        settings: RouteSettings(
          name: '/story/$storyId',
          arguments: settings.arguments,
        ),
        builder: (_) => StoryDetailScreen(storyId: storyId),
      );
    }

    // Default to AppShell for other nexusapp:// schemes
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const AppShell(),
    );
  }

  // Ignore other external scheme deeplinks for stability.
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
        builder: (_) => DatingAudioQuestionScreen(questionNumber: n),
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
    debugPrint('[AppRouter] /journey route resolved with id=$journeyId');
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => JourneyDetailScreen(id: journeyId),
    );
  }

  // /story/:id
  if (segments.length == 2 && segments[0] == 'story') {
    final storyId = segments[1];
    debugPrint('[AppRouter] /story route resolved with id=$storyId');
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => StoryDetailScreen(storyId: storyId),
    );
  }

  // /journey-purchase - Receives journey as argument
  if (uri.path == '/journey-purchase') {
    final journey = settings.arguments as JourneyV1;
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => JourneyPurchaseScreen(journey: journey),
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
        builder: (_) => const AppShell(),
      );

    case '/search':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const NewDatingSearchScreen(),
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
        builder: (_) => DatingPhotosScreen(),
      );

    case '/dating/setup/audio':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DatingAudioScreen(),
      );

    case '/dating/setup/audio/summary':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DatingAudioSummaryScreen(),
      );

    case '/dating/setup/hobbies':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DatingHobbiesScreen(),
      );

    case '/dating/setup/qualities':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DatingQualitiesScreen(),
      );

    case '/dating/setup/contact-info':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DatingContactInfoScreen(),
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
    case '/auth-entry':
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AuthEntryScreen(),
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
      // Notifications route wrapped with DisabledAccountGate
      // Rejected/disabled users are blocked from accessing any screen
      // If app is open when notification clicked, they're caught here before HomeScreen
      return MaterialPageRoute(
        settings: settings,
        builder:
            (_) => const DisabledAccountGate(
              child: HomeScreen(),
              message:
                  'Your account has been disabled. Please contact support.',
            ),
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
    case AppRoutes.bookMarriageCoach:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const BookMarriageCoachScreen(),
      );
    case '/compatibility-quiz':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const CompatibilityQuizScreen(),
      );

    case AppRoutes.coachList:
      final sessionType =
          settings.arguments as SessionType? ?? SessionType.individual;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => CoachListScreen(sessionType: sessionType),
      );

    case AppRoutes.myBookings:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const MyBookingsScreen(),
      );

    case AppRoutes.coachDashboard:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const CoachDashboardScreen(),
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
