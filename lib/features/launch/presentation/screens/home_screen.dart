import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:nexus_app_v2/core/widgets/guest_guard.dart';
import 'package:nexus_app_v2/core/theme/app_colors.dart';
import 'package:nexus_app_v2/core/theme/app_text_styles.dart';
import 'package:nexus_app_v2/core/constants/app_constants.dart';
import 'package:nexus_app_v2/core/router/app_routes.dart';
import 'package:nexus_app_v2/core/providers/tab_selection_provider.dart';
import 'package:nexus_app_v2/features/presurvey/presentation/screens/presurvey_relationship_status_screen.dart';

import 'package:nexus_app_v2/core/session/is_guest_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/core/providers/assessment_provider.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';

import 'package:nexus_app_v2/core/session/relationship_status_key.dart';
import 'package:nexus_app_v2/core/session/effective_relationship_status_provider.dart';
import 'package:nexus_app_v2/core/models/assessment_model.dart';

import 'package:nexus_app_v2/features/stories/data/story_repository.dart';
import 'package:nexus_app_v2/features/stories/domain/story_models.dart';
import 'package:nexus_app_v2/features/stories/presentation/screens/stories_screen.dart';

import 'package:nexus_app_v2/features/journeys/data/journey_repository.dart';
import 'package:nexus_app_v2/features/journeys/domain/journey_models.dart';
import 'package:nexus_app_v2/features/challenges/providers/journeys_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> _homeDisplayNameForUser(User? u) async {
  if (u == null) return '';

  // First try Firestore (primary source of truth once persisted)
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
  var username = (doc.data()?['username'] ?? '').toString().trim();

  // If not in Firestore yet, check SharedPreferences (during signup before email verification)
  if (username.isEmpty) {
    final prefs = await SharedPreferences.getInstance();
    username =
        (prefs.getString('pending_username_${u.uid}') ?? '').toString().trim();
  }

  // Return first word of username
  if (username.isNotEmpty) {
    return username.split(RegExp(r'\s+')).first.trim();
  }

  return '';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<String?> _loadActiveJourneyIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString('activeJourneyId') ??
        prefs.getString('active_journey_id') ??
        prefs.getString('activeJourney') ??
        prefs.getString('active_journey');
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  String _assessmentTitleForKey(String key) {
    if (key == 'married') return 'Marriage Health Check';
    if (key == 'divorced' || key == 'widowed')
      return 'Remarriage Readiness Test';
    return 'Marriage Readiness Test';
  }

  String _assessmentDescForKey(String key) {
    if (key == 'married') return 'Find out how healthy your marriage is';
    if (key == 'divorced' || key == 'widowed') {
      return 'Find out how ready you are to get married again';
    }
    return 'Find out how ready you are for the marriage you desire';
  }

  String _journeysCopyForKey(String key) {
    if (key == 'married') {
      return 'Strengthen your marriage by equipping yourself with practical knowledge and guidance required to navigate every aspect of married life';
    }
    if (key == 'divorced') {
      return 'Rebuild with clarity and confidence by gaining practical guidance for healing, growth, and healthier relationships ahead';
    }
    if (key == 'widowed') {
      return 'Find steady guidance and practical support as you navigate life, healing, and relationships after spousal loss';
    }
    return 'Equip yourself with the practical knowledge, clarity, and confidence you need to choose a life partner and navigate marriage';
  }

  AssessmentType _assessmentTypeForKey(String key) {
    if (key == 'married') return AssessmentType.marriageHealthCheck;
    if (key == 'divorced' || key == 'widowed')
      return AssessmentType.remarriageReadiness;
    return AssessmentType.singlesReadiness;
  }

  /// Get the correct assessment ID for results lookup (handles divorced/widowed distinction)
  String _getAssessmentIdForKey(String key) {
    if (key == 'married') return 'marriage_health_check';
    if (key == 'divorced') return 'remarriage_readiness_divorced';
    if (key == 'widowed') return 'remarriage_readiness_widowed';
    return 'singles_readiness'; // default
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenW = MediaQuery.of(context).size.width;
    // Responsive scaling: compact for narrow screens (<375), normal otherwise
    final isCompact = screenW < 375;
    final hPad = isCompact ? 16.0 : 20.0;
    final cardGap = isCompact ? 14.0 : 20.0;

    // Use the canonical guest logic (respects `force_guest` etc.)
    // This now watches auth state internally, so it auto-updates on login/logout
    final isGuestAsync = ref.watch(isGuestProvider);
    final isGuest = isGuestAsync.maybeWhen(data: (v) => v, orElse: () => true);

    // Use effective relationship status provider for real-time updates
    final effectiveStatus = ref.watch(effectiveRelationshipStatusProvider);
    final statusKey = relationshipStatusKeyFromEnum(effectiveStatus);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Home',
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 80 + bottomInset),
        physics: const ClampingScrollPhysics(),
        children: [
          // Greeting Header
          if (isGuest)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello 👋',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You can read our weekly stories without an account!',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.4,
                  ),
                ),
              ],
            )
          else
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnap) {
                final user = authSnap.data ?? FirebaseAuth.instance.currentUser;
                return FutureBuilder<String>(
                  future: _homeDisplayNameForUser(user),
                  builder: (context, snap) {
                    final firstName = (snap.data ?? '').trim();
                    // Determine if user is returning (not first session)
                    final createdAt = user?.metadata.creationTime;
                    final lastSignIn = user?.metadata.lastSignInTime;
                    final isReturningUser =
                        createdAt != null &&
                        lastSignIn != null &&
                        lastSignIn.difference(createdAt).inHours > 24;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName.isEmpty
                              ? '${_greeting()} 👋'
                              : '${_greeting()}, $firstName 👋',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (isReturningUser)
                          Text(
                            'Welcome back — continue where you left off',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.3,
                            ),
                          )
                        else
                          Text(
                            'Explore different features below',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.3,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),

          SizedBox(height: cardGap),

          // Assessment Card - Dynamic based on completion status
          _AssessmentCard(
            statusKey: statusKey,
            assessmentType: _assessmentTypeForKey(statusKey),
            assessmentId: _getAssessmentIdForKey(statusKey),
            titleBuilder: (ctx, key) => _assessmentTitleForKey(key),
            descBuilder: (ctx, key) => _assessmentDescForKey(key),
          ),

          SizedBox(height: cardGap),

          _StoryOfWeekCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoriesScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          FutureBuilder<String?>(
            future: _loadActiveJourneyIdFromPrefs(),
            builder: (context, activeSnap) {
              final activeId = activeSnap.data;

              return Column(
                children: [
                  if (activeId != null) ...[
                    _JourneyCard(
                      title: 'Continue Journey',
                      subtitle: 'Pick up where you left off',
                      pillText: 'In progress',
                      pillColor: Color(0xFF10B981),
                      pillBgColor: Color(0xFFD1FAE5),
                      progress: 0.15,
                      ctaText: 'Continue',
                      onTap: () {
                        Navigator.of(context).pushNamed('/journey/$activeId');
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _JourneyCard(
                    title: 'Journeys',
                    subtitle: _journeysCopyForKey(statusKey),
                    pillText: '',
                    pillColor: Colors.white,
                    pillBgColor: Colors.white.withOpacity(0.2),
                    progress: null,
                    ctaText: 'Explore Journeys',
                    onTap: () async {
                      await GuestGuard.requireSignedIn(
                        context,
                        ref,
                        title: 'Create an account',
                        message:
                            'Create an account to start journeys and unlock personalized guidance.',
                        primaryText: 'Create an account',
                        onCreateAccount:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const PresurveyRelationshipStatusScreen(),
                              ),
                            ),
                        onAllowed: () async {
                          ref
                              .read(journeysOpenedFromHomeProvider.notifier)
                              .state = true;
                          ref.read(selectedTabProvider.notifier).state =
                              NavTab.challenges;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _MarriageCoachCard(
                    onTap: () {
                      // If counselling tab is visible for the user's status, switch tab.
                      // Otherwise navigate directly to the booking screen.
                      if (NavConfig.isTabVisible(
                        NavTab.counselling,
                        effectiveStatus,
                      )) {
                        ref.read(selectedTabProvider.notifier).state =
                            NavTab.counselling;
                      } else {
                        Navigator.of(
                          context,
                        ).pushNamed(AppNavRoutes.bookMarriageCoach);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Journey catalog is loaded reactively based on relationship status
                  // The journeyCatalogProvider watches effectiveRelationshipStatusProvider
                  // so it automatically updates when status changes
                  Consumer(
                    builder: (context, ref, child) {
                      final catalogAsync = ref.watch(journeyCatalogProvider);
                      return catalogAsync.when(
                        data: (catalog) {
                          // Catalog is loaded and reactive - actual journey display
                          // happens on the challenges screen
                          return const SizedBox.shrink();
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ASSESSMENT CARD WIDGET - Dynamic based on completion status
// ============================================================================
class _AssessmentCard extends ConsumerWidget {
  final String statusKey;
  final AssessmentType assessmentType;
  final String
  assessmentId; // Specific ID for lookup (handles divorced/widowed)
  final String Function(BuildContext, String) titleBuilder;
  final String Function(BuildContext, String) descBuilder;

  const _AssessmentCard({
    required this.statusKey,
    required this.assessmentType,
    required this.assessmentId,
    required this.titleBuilder,
    required this.descBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final userId = currentUser?.id ?? '';

    if (userId.isEmpty) {
      // For guests, show Start Assessment
      return _StartAssessmentCard(
        statusKey: statusKey,
        titleBuilder: titleBuilder,
        descBuilder: descBuilder,
      );
    }

    // Watch latest assessment result for this type
    // Use specific assessment ID (not generic type ID) to handle divorced/widowed distinction
    final latestResultAsync = ref.watch(
      latestAssessmentResultProvider(assessmentId),
    );

    return latestResultAsync.when(
      data: (result) {
        if (result != null) {
          // User has completed assessment - show View Result
          return _ViewAssessmentResultCard(
            statusKey: statusKey,
            titleBuilder: titleBuilder,
            descBuilder: descBuilder,
            result: result,
          );
        } else {
          // No result yet - show Start Assessment
          return _StartAssessmentCard(
            statusKey: statusKey,
            titleBuilder: titleBuilder,
            descBuilder: descBuilder,
          );
        }
      },
      loading: () {
        // While loading, show Start Assessment as default
        return _StartAssessmentCard(
          statusKey: statusKey,
          titleBuilder: titleBuilder,
          descBuilder: descBuilder,
        );
      },
      error: (error, stack) {
        // On error, show Start Assessment
        return _StartAssessmentCard(
          statusKey: statusKey,
          titleBuilder: titleBuilder,
          descBuilder: descBuilder,
        );
      },
    );
  }
}

// ============================================================================
// START ASSESSMENT CARD - For first-time or no result
// ============================================================================
class _StartAssessmentCard extends ConsumerWidget {
  final String statusKey;
  final String Function(BuildContext, String) titleBuilder;
  final String Function(BuildContext, String) descBuilder;

  const _StartAssessmentCard({
    required this.statusKey,
    required this.titleBuilder,
    required this.descBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PremiumCard(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Assessment',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            titleBuilder(context, statusKey),
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descBuilder(context, statusKey),
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () async {
                await GuestGuard.requireSignedIn(
                  context,
                  ref,
                  title: 'Create an account',
                  message:
                      'Create an account to start your assessment and unlock personalized recommendations.',
                  primaryText: 'Create an account',
                  onCreateAccount:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => const PresurveyRelationshipStatusScreen(),
                        ),
                      ),
                  onAllowed: () async {
                    Navigator.of(context).pushNamed(AppRoutes.assessmentIntro);
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Start Assessment',
                style: AppTextStyles.buttonMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// VIEW ASSESSMENT RESULT CARD - When user has completed assessment
// ============================================================================
class _ViewAssessmentResultCard extends StatelessWidget {
  final String statusKey;
  final String Function(BuildContext, String) titleBuilder;
  final String Function(BuildContext, String) descBuilder;
  final AssessmentResult result;

  const _ViewAssessmentResultCard({
    required this.statusKey,
    required this.titleBuilder,
    required this.descBuilder,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.textOnPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.textOnPrimary.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 16,
                  color: AppColors.textOnPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Assessment',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            titleBuilder(context, statusKey),
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Score: ${(result.percentage * 100).round()}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textOnPrimary.withOpacity(0.9),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '%',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textOnPrimary.withOpacity(0.9),
                        height: 1.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _HomeTierPill(tier: result.overallTier),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/assessment/result');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'View Assessment Result',
                style: AppTextStyles.buttonMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TIER PILL - Matches assessment result screen style
// ============================================================================
class _HomeTierPill extends StatelessWidget {
  final SignalTier tier;
  const _HomeTierPill({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textOnPrimary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 12,
            color: AppColors.textOnPrimary,
          ),
          const SizedBox(width: 5),
          Text(
            tier.displayName,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PREMIUM CARD WIDGET
// ============================================================================
class _PremiumCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;

  const _PremiumCard({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isCompact = screenW < 375;
    final cardPad = isCompact ? 16.0 : 20.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPad),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppColors.surface : null,
        borderRadius: BorderRadius.circular(20),
        border:
            gradient == null
                ? Border.all(
                  color: AppColors.getBorder(context).withOpacity(0.5),
                )
                : null,
        boxShadow: [
          BoxShadow(
            color: (gradient != null ? AppColors.primary : Colors.black)
                .withOpacity(gradient != null ? 0.15 : 0.03),
            blurRadius: gradient != null ? 20 : 8,
            offset: Offset(0, gradient != null ? 8 : 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================================
// STORY OF WEEK CARD
// ============================================================================
class _StoryOfWeekCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StoryOfWeekCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const repo = StoryRepository();

    return FutureBuilder<Story?>(
      future: repo.loadCurrentStory(),
      builder: (context, snapshot) {
        final story = snapshot.data;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.getBorder(context).withOpacity(0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.getOverlayLight(context),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header Above Image
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.auto_stories,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Story of the Week',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Hero Image with Overlay
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _AdaptiveImage(
                          imagePath: story?.heroImageAsset,
                          placeholder:
                              'assets/images/stories/placeholder_couple.jpg',
                        ),
                        // Gradient Overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.0),
                                  Colors.black.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Title Overlay
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_stories,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Story of the Week',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                story?.title ?? 'Loading story…',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (story != null) ...[
                          Row(
                            children: [
                              _InfoChip(
                                icon: Icons.category_outlined,
                                text: story.category,
                              ),
                              const SizedBox(width: 8),
                              _InfoChip(
                                icon: Icons.access_time,
                                text: '${story.readTimeMins} min',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            story.excerpt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.4,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'A fresh story to guide your dating, marriage, and relationship life this week.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: onTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Read Now',
                              style: AppTextStyles.buttonMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Loads either a network image (when the path is a URL) or an asset fallback.
class _AdaptiveImage extends StatelessWidget {
  final String? imagePath;
  final String placeholder;

  const _AdaptiveImage({required this.imagePath, required this.placeholder});

  bool get _isRemote => (imagePath ?? '').startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isRemote) {
      return Image.network(
        imagePath!,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => Image.asset(placeholder, fit: BoxFit.cover),
      );
    }

    return Image.asset(
      imagePath?.isNotEmpty == true ? imagePath! : placeholder,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(placeholder, fit: BoxFit.cover),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String pillText;
  final Color pillColor;
  final Color pillBgColor;
  final double? progress;
  final String ctaText;
  final VoidCallback onTap;

  const _JourneyCard({
    required this.title,
    required this.subtitle,
    required this.pillText,
    required this.pillColor,
    required this.pillBgColor,
    required this.progress,
    required this.ctaText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Journeys',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                ctaText,
                style: AppTextStyles.buttonMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INFO CHIP
// ============================================================================
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.getBorder(context).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.getTextSecondary(context)),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MARRIAGE COACH CARD WIDGET
// ============================================================================

class _MarriageCoachCard extends StatelessWidget {
  final VoidCallback onTap;

  const _MarriageCoachCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.light
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.waving_hand_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            // Middle: Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Coming Soon Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Speak to a Marriage Coach',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Get expert guidance from professional marriage counselors and family therapists',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right: Arrow Button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
