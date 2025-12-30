import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../models/assessment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/story_provider.dart' show unreadStoryCountProvider;

// Import screens
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/survey_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/presentation/screens/user_profile_screen.dart';
import '../../features/chats/presentation/screens/chats_screen.dart';
import '../../features/chats/presentation/screens/chat_detail_screen.dart';
import '../../features/challenges/presentation/screens/challenges_screen.dart';
import '../../features/challenges/presentation/screens/journey_detail_screen.dart';
import '../../features/challenges/presentation/screens/session_flow_screen.dart';
import '../../features/stories/presentation/screens/stories_screen.dart';
import '../../features/stories/presentation/screens/story_detail_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/dating_profile_setup_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_married_screen.dart';
import '../../features/assessment/presentation/screens/assessment_screen.dart';
import '../../features/assessment/presentation/screens/assessment_intro_screen.dart';
import '../../features/assessment/presentation/screens/assessment_result_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/blocked_users_screen.dart';
import '../../features/settings/presentation/screens/contact_support_screen.dart';
import '../../features/settings/presentation/screens/terms_screen.dart';
import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/settings/presentation/screens/help_center_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../widgets/app_loading_states.dart';

// Placeholder provider for unread chat count
final unreadChatCountProvider = Provider<int?>((ref) => null);

// ============================================================================
// ROUTER PROVIDER
// ============================================================================

/// Main router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final authStream = ref.watch(authStateStreamProvider);
  final userAsync = ref.watch(currentUserProvider);
  
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authStream),
    
    // Redirect logic
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == AppRoutes.login ||
                          state.matchedLocation == AppRoutes.signup;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isSurvey = state.matchedLocation == AppRoutes.survey;
      
      return authState.when(
        data: (user) {
          // Not authenticated
          if (user == null) {
            // Allow splash, login, signup
            if (isSplash || isLoggingIn) return null;
            // Redirect to login
            return AppRoutes.login;
          }
          
          // Authenticated - check if needs onboarding
          final userData = userAsync.valueOrNull;
          final needsOnboarding = userData?.needsNexus2Onboarding ?? true;
          
          if (needsOnboarding) {
            // Allow survey screen
            if (isSurvey) return null;
            // If on login/signup/splash, redirect to survey
            if (isLoggingIn || isSplash) return AppRoutes.survey;
            // For other routes, also redirect to survey
            return AppRoutes.survey;
          }
          
          // Fully onboarded - redirect away from auth screens
          if (isLoggingIn || isSplash || isSurvey) {
            return AppRoutes.home;
          }
          
          return null; // No redirect needed
        },
        loading: () => null, // Stay on current route while loading
        error: (_, __) => AppRoutes.login,
      );
    },
    
    // Error page
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
    
    // Routes
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      
      // Onboarding
      GoRoute(
        path: AppRoutes.survey,
        name: 'survey',
        builder: (context, state) => const SurveyScreen(),
      ),
      
      // Main app shell with bottom nav
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.search,
            name: 'search',
            // Redirect married users away from search (dating) section
            redirect: (context, state) {
              final container = ProviderScope.containerOf(context);
              final user = container.read(currentUserProvider).valueOrNull;
              final isMarried = user?.nexus2?.relationshipStatus == RelationshipStatus.married;
              if (isMarried) {
                return AppRoutes.home; // Redirect married users to home
              }
              return null; // Allow singles
            },
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.chats,
            name: 'chats',
            // Redirect married users away from chats (dating) section
            redirect: (context, state) {
              final container = ProviderScope.containerOf(context);
              final user = container.read(currentUserProvider).valueOrNull;
              final isMarried = user?.nexus2?.relationshipStatus == RelationshipStatus.married;
              if (isMarried) {
                return AppRoutes.home; // Redirect married users to home
              }
              return null; // Allow singles
            },
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChatsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.challenges,
            name: 'challenges',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChallengesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.stories,
            name: 'stories',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StoriesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      
      // Assessment flow (outside shell - no bottom nav)
      // Assessment intro screen
      GoRoute(
        path: '/assessment/:type',
        name: 'assessmentIntro',
        builder: (context, state) {
          final typeStr = state.pathParameters['type']!;
          final type = _parseAssessmentType(typeStr);
          if (type == null) {
            return const AssessmentResultScreen(); // Fallback
          }
          return AssessmentIntroScreen(assessmentType: type);
        },
      ),
      // Assessment questions screen
      GoRoute(
        path: '/assessment/:type/questions',
        name: 'assessmentQuestions',
        builder: (context, state) {
          final typeStr = state.pathParameters['type']!;
          final type = _parseAssessmentType(typeStr);
          return AssessmentScreen(assessmentType: type);
        },
      ),
      // Legacy assessment route (keep for backwards compatibility)
      GoRoute(
        path: AppRoutes.assessment,
        name: 'assessment',
        builder: (context, state) {
          final type = state.extra as AssessmentType?;
          return AssessmentScreen(assessmentType: type);
        },
      ),
      GoRoute(
        path: AppRoutes.assessmentResult,
        name: 'assessmentResult',
        builder: (context, state) => const AssessmentResultScreen(),
      ),
      
      // Story detail (outside shell - immersive reading)
      GoRoute(
        path: '/story/:storyId',
        name: 'storyDetail',
        builder: (context, state) {
          final storyId = state.pathParameters['storyId']!;
          return StoryDetailScreen(storyId: storyId);
        },
      ),
      
      // Journey detail
      GoRoute(
        path: '/journey/:productId',
        name: 'journeyDetail',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return JourneyDetailScreen(productId: productId);
        },
      ),
      
      // Session flow (full screen experience)
      GoRoute(
        path: '/journey/:productId/session/:sessionNumber',
        name: 'sessionFlow',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          final sessionNumber = int.tryParse(state.pathParameters['sessionNumber'] ?? '1') ?? 1;
          return SessionFlowScreen(
            productId: productId,
            sessionNumber: sessionNumber,
          );
        },
      ),
      
      // Dating profile setup (multi-step onboarding for singles)
      GoRoute(
        path: '/dating-profile/setup',
        name: 'datingProfileSetup',
        builder: (context, state) => const DatingProfileSetupScreen(),
      ),
      
      // View other user's profile (dating section - singles only)
      GoRoute(
        path: '/profile/:userId',
        name: 'userProfile',
        redirect: (context, state) {
          final container = ProviderScope.containerOf(context);
          final user = container.read(currentUserProvider).valueOrNull;
          final isMarried = user?.nexus2?.relationshipStatus == RelationshipStatus.married;
          if (isMarried) {
            return AppRoutes.home; // Married users cannot view dating profiles
          }
          return null;
        },
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return UserProfileScreen(userId: userId);
        },
      ),
      
      // Chat detail screen (dating section - singles only)
      GoRoute(
        path: '/chat/:chatId',
        name: 'chatDetail',
        redirect: (context, state) {
          final container = ProviderScope.containerOf(context);
          final user = container.read(currentUserProvider).valueOrNull;
          final isMarried = user?.nexus2?.relationshipStatus == RelationshipStatus.married;
          if (isMarried) {
            return AppRoutes.home; // Married users cannot access dating chats
          }
          return null;
        },
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          return ChatDetailScreen(chatId: chatId);
        },
      ),
      
      // Settings screen
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      
      // Contact Support screen
      GoRoute(
        path: '/contact-support',
        name: 'contactSupport',
        builder: (context, state) => const ContactSupportScreen(),
      ),
      
      // Blocked users screen
      GoRoute(
        path: '/blocked-users',
        name: 'blockedUsers',
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      
      // Subscription screen
      GoRoute(
        path: '/subscription',
        name: 'subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      
      // Edit profile screen (dating users)
      GoRoute(
        path: '/edit-profile',
        name: 'editProfile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      
      // Edit profile screen (married users)
      GoRoute(
        path: '/edit-profile-married',
        name: 'editProfileMarried',
        builder: (context, state) => const EditProfileMarriedScreen(),
      ),
      
      // Terms of Service
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const TermsScreen(),
      ),
      
      // Privacy Policy
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      
      // Help Center
      GoRoute(
        path: '/help',
        name: 'help',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      
      // Forgot Password
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      
      // Notifications
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

// ============================================================================
// MAIN SHELL (Bottom Nav Container)
// ============================================================================

/// Main shell widget that provides bottom navigation
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    
    return userAsync.when(
      data: (user) {
        final statusStr = user?.nexus2?.relationshipStatus;
        final status = statusStr != null && statusStr.isNotEmpty 
            ? RelationshipStatus.fromValue(statusStr) 
            : null;
        final tabs = NavConfig.getTabsForStatus(status);
        
        // Determine current index based on location
        final location = GoRouterState.of(context).matchedLocation;
        int currentIndex = 0;
        for (int i = 0; i < tabs.length; i++) {
          if (location.startsWith(tabs[i].route)) {
            currentIndex = i;
            break;
          }
        }
        
        return Scaffold(
          body: widget.child,
          bottomNavigationBar: _buildBottomNav(context, tabs, currentIndex, status),
        );
      },
      loading: () => Scaffold(
        body: widget.child, // Still show content while loading
      ),
      error: (e, _) => Scaffold(
        body: widget.child,
      ),
    );
  }
  
  Widget _buildBottomNav(
    BuildContext context,
    List<NavTabConfig> tabs,
    int currentIndex,
    RelationshipStatus? status,
  ) {
    // Get badge counts (would come from providers in real app)
    final chatBadgeCount = ref.watch(unreadChatCountProvider);
    final storyBadgeCount = ref.watch(unreadStoryCountProvider);
    final storyBadge = storyBadgeCount > 0 ? storyBadgeCount : null;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final isActive = index == currentIndex;
              
              // Determine badge count
              int? badgeCount;
              if (tab.id == NavTab.chats) badgeCount = chatBadgeCount;
              if (tab.id == NavTab.stories) badgeCount = storyBadge;
              
              return Expanded(
                child: _NavItem(
                  tab: tab,
                  isActive: isActive,
                  badgeCount: badgeCount,
                  onTap: () => _onNavTap(context, tabs, index),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
  
  void _onNavTap(BuildContext context, List<NavTabConfig> tabs, int index) {
    final route = tabs[index].route;
    context.go(route);
  }
}



// ============================================================================
// NAV ITEM
// ============================================================================

class _NavItem extends StatelessWidget {
  final NavTabConfig tab;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive 
        ? theme.colorScheme.primary 
        : theme.colorScheme.onSurface.withOpacity(0.6);
    
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive 
                      ? theme.colorScheme.primary.withOpacity(0.1) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(tab.iconName, isActive),
                  color: color,
                  size: 24,
                ),
              ),
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      badgeCount! > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tab.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getIcon(String name, bool isActive) {
    // Map icon names to Material Icons
    final icons = <String, IconData>{
      'home_outlined': isActive ? Icons.home : Icons.home_outlined,
      'search_outlined': Icons.search,
      'chat_outlined': isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
      'stories_outlined': isActive ? Icons.auto_stories : Icons.auto_stories_outlined,
      'challenges_outlined': isActive ? Icons.fitness_center : Icons.fitness_center_outlined,
      'profile_outlined': isActive ? Icons.person : Icons.person_outline,
    };
    return icons[name] ?? Icons.circle_outlined;
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Parse assessment type from URL string
AssessmentType? _parseAssessmentType(String typeStr) {
  switch (typeStr) {
    case 'singles_readiness':
      return AssessmentType.singlesReadiness;
    case 'remarriage_readiness':
      return AssessmentType.remarriageReadiness;
    case 'marriage_health_check':
      return AssessmentType.marriageHealthCheck;
    default:
      return null;
  }
}

// ============================================================================
// REFRESH STREAM
// ============================================================================

/// Converts a Stream to a Listenable for GoRouter refresh
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ============================================================================
// ERROR SCREEN
// ============================================================================

class ErrorScreen extends StatelessWidget {
  final Exception? error;
  
  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppErrorState(
        title: 'Page Not Found',
        message: error?.toString() ?? 'The page you\'re looking for doesn\'t exist.',
        onRetry: () => context.go(AppRoutes.home),
      ),
    );
  }
}
