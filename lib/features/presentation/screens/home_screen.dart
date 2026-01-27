import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';
import 'package:nexus_app_min_test/core/theme/app_colors.dart';
import 'package:nexus_app_min_test/core/theme/app_text_styles.dart';

import 'package:nexus_app_min_test/core/session/is_guest_provider.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

import 'package:nexus_app_min_test/core/session/relationship_status_key.dart';

import 'package:nexus_app_min_test/features/stories/data/story_repository.dart';
import 'package:nexus_app_min_test/features/stories/domain/story_models.dart';
import 'package:nexus_app_min_test/features/stories/presentation/screens/stories_screen.dart';

import 'package:nexus_app_min_test/features/journeys/data/journey_repository.dart';
import 'package:nexus_app_min_test/features/journeys/domain/journey_models.dart';
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

  Future<String> _loadStatusKeyFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString('relationshipStatus') ??
        prefs.getString('relationship_status') ??
        prefs.getString('user_relationship_status') ??
        prefs.getString('onboarding_relationship_status') ??
        prefs.getString('category') ??
        prefs.getString('user_category') ??
        '';
    return relationshipStatusKeyFromString(raw);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Use the canonical guest logic (respects `force_guest` etc.)
    // This now watches auth state internally, so it auto-updates on login/logout
    final isGuestAsync = ref.watch(isGuestProvider);
    final isGuest = isGuestAsync.maybeWhen(data: (v) => v, orElse: () => true);

    // Fallback for relationship status comes from local prefs (guest + signed-in safe).
    final fallbackKey = relationshipStatusKeyFromString('');

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Home',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: _loadStatusKeyFromPrefs(),
        builder: (context, statusSnap) {
          final statusKey = statusSnap.data ?? fallbackKey;

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 220 + bottomInset),
            children: [
              // Greeting Header
              if (isGuest)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello 👋',
                      style: AppTextStyles.displayMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can read our weekly stories without an account!',
                      style: AppTextStyles.bodyMedium.copyWith(
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
                    final user =
                        authSnap.data ?? FirebaseAuth.instance.currentUser;
                    return FutureBuilder<String>(
                      future: _homeDisplayNameForUser(user),
                      builder: (context, snap) {
                        final firstName = (snap.data ?? '').trim();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstName.isEmpty
                                  ? '${_greeting()} 👋'
                                  : '${_greeting()}, $firstName 👋',
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Welcome — continue where you left off',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.getTextSecondary(context),
                                height: 1.4,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Assessment Card
              _PremiumCard(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                            Icons.psychology_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
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
                      _assessmentTitleForKey(statusKey),
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _assessmentDescForKey(statusKey),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
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
                                () =>
                                    Navigator.of(context).pushNamed('/signup'),
                            onAllowed: () async {
                              Navigator.of(context).pushNamed('/assessment');
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

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
                            Navigator.of(
                              context,
                            ).pushNamed('/journey/$activeId');
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      _JourneyCard(
                        title: 'Journeys',
                        subtitle: _journeysCopyForKey(statusKey),
                        pillText: 'New',
                        pillColor: AppColors.primary,
                        pillBgColor: AppColors.primarySoft,
                        progress: null,
                        ctaText: 'Start Now',
                        onTap: () async {
                          await GuestGuard.requireSignedIn(
                            context,
                            ref,
                            title: 'Create an account',
                            message:
                                'Create an account to start journeys and unlock personalized guidance.',
                            primaryText: 'Create an account',
                            onCreateAccount:
                                () =>
                                    Navigator.of(context).pushNamed('/signup'),
                            onAllowed: () async {
                              Navigator.of(context).pushNamed('/challenges');
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<Journey>>(
                        future: const JourneyRepository()
                            .loadJourneysForCategory(statusKey),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const SizedBox.shrink();
                          }
                          final list = snapshot.data ?? const <Journey>[];
                          if (list.isEmpty) return const SizedBox.shrink();
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppColors.surface : null,
        borderRadius: BorderRadius.circular(20),
        border:
            gradient == null
                ? Border.all(color: AppColors.getBorder(context).withOpacity(0.5))
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
                border: Border.all(color: AppColors.getBorder(context).withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.auto_stories,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Story of the Week',
                            style: AppTextStyles.titleMedium.copyWith(
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
                    padding: const EdgeInsets.all(20),
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
                          const SizedBox(height: 14),
                          Text(
                            story.excerpt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.5,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'A fresh story to guide your dating, marriage, and relationship life this week.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
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
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
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
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  pillText,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(progress! * 100).toInt()}%',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
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
