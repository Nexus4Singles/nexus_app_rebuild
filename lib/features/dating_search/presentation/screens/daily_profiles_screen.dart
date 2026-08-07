import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/widgets/cached_image.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/features/profile/presentation/screens/profile_screen.dart';
import '../../domain/dating_profile.dart';
import '../../application/daily_profiles_provider.dart';
import '../../application/dating_preferences_provider.dart';
import '../../application/market_country_utils.dart';
import '../../application/saved_profiles_provider.dart';
import '../../application/market_phase_provider.dart';
import 'dating_preferences_setup_screen.dart';
import 'package:nexus_app_v2/core/dating/dating_verification_status_provider.dart';
import '../widgets/daily_profile_native_ad.dart';
import 'market_coming_soon_screen.dart';
import 'waiting_list_screen.dart';

/// Daily 5 profiles screen - shows 5 curated profiles per day as full-screen carousel
/// Only used for non-Nigeria countries to validate efficacy
class DailyProfilesScreen extends ConsumerStatefulWidget {
  const DailyProfilesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DailyProfilesScreen> createState() =>
      _DailyProfilesScreenState();
}

class _DailyProfilesScreenState extends ConsumerState<DailyProfilesScreen>
    with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  Timer? _dailyRefreshTimer;
  int _currentIndex = 0;
  late String _loadedDateKey;

  @override
  void initState() {
    super.initState();
    _loadedDateKey = _dateKey(DateTime.now().toUtc());
    _pageController = PageController();
    _pageController.addListener(() {
      setState(() {
        _currentIndex = _pageController.page?.toInt() ?? 0;
      });
    });
    _dailyRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final nowUtc = DateTime.now().toUtc();
      final currentDateKey = _dateKey(nowUtc);
      final enteredNewDay = currentDateKey != _loadedDateKey;
      final withinRolloverWindow = nowUtc.hour == 0;

      if (enteredNewDay || withinRolloverWindow) {
        _loadedDateKey = currentDateKey;
        ref.invalidate(dailyProfilesProvider);
      }
    });
  }

  @override
  void dispose() {
    _dailyRefreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dailyProfilesAsync = ref.watch(dailyProfilesProvider);
    final preferencesAsync = ref.watch(datingPreferencesProvider);
    final authAsync = ref.watch(authStateProvider);
    final showPreferencesEditor = preferencesAsync.maybeWhen(
      data: (prefs) => prefs != null,
      orElse: () => false,
    );

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: null,
          title: Text('Today\'s Picks', style: AppTextStyles.headlineMedium),
          actions: [
            if (showPreferencesEditor)
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  preferencesAsync.whenData((prefs) {
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => DatingPreferencesSetupScreen(
                              existingPreferences: prefs,
                            ),
                      ),
                    );
                  });
                },
              ),
          ],
        ),
        body: dailyProfilesAsync.when(
          loading:
              () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Today\'s Picks...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
          error:
              (e, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load profiles',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(dailyProfilesProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          data: (dailyState) {
            if (dailyState?.isDailyLimitReached == true) {
              return _buildDailyLimitState(context, dailyState!.resetTime);
            }

            final hasProfiles =
                dailyState != null && dailyState.profiles.isNotEmpty;

            if (!hasProfiles) {
              final country = preferencesAsync.maybeWhen(
                data: (prefs) => prefs?.countryOfResidence,
                orElse: () => null,
              );
              final isUkMarket =
                  country != null && MarketCountryUtils.isUkMarket(country);
              final prefs = preferencesAsync.maybeWhen(
                data: (p) => p,
                orElse: () => null,
              );

              if (isUkMarket) {
                return const WaitingListScreen();
              }

              if (country != null &&
                  MarketCountryUtils.isPrelaunchCarouselMarket(country)) {
                return MarketComingSoonScreen(existingPreferences: prefs);
              }

              // If user has saved age-range preferences, show a specific
              // message explaining there are no profiles within that range
              if (prefs != null) {
                return _AgeRangeEmptyState(
                  minAge: prefs.minAge,
                  maxAge: prefs.maxAge,
                  onEdit: () {
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DatingPreferencesSetupScreen(
                          existingPreferences: prefs,
                        ),
                      ),
                    );
                  },
                  onRefresh: () => ref.invalidate(dailyProfilesProvider),
                );
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_outline_rounded,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Profiles Available',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back tomorrow for new matches',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 160,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () => ref.invalidate(dailyProfilesProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final profileCount = dailyState.profiles.length;
            final totalPages = profileCount + 1;
            final isAdPage = _currentIndex >= profileCount;

            return Column(
              children: [
                // Profile counter and progress
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isAdPage)
                        Text(
                          '${_currentIndex + 1} of $profileCount',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        const SizedBox(width: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Daily Picks',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Carousel
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemCount: totalPages,
                    itemBuilder: (context, index) {
                      if (index < dailyState.profiles.length) {
                        final profile = dailyState.profiles[index];
                        return _ProfileCarouselCard(
                          profile: profile,
                          isCurrentCard: index == _currentIndex,
                          onTapProfile: () {
                            _recordProfileView(
                              profile,
                              authAsync.valueOrNull?.uid,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => ProfileScreen(userId: profile.uid),
                              ),
                            );
                          },
                          compatibilityScore: profile.compatibilityScore,
                        );
                      }

                      return DailyProfileNativeAd(
                        adUnitId: const String.fromEnvironment(
                          'ADMOB_NATIVE_AD_UNIT_ID',
                          defaultValue:
                              'ca-app-pub-3940256099942544/2247696110',
                        ),
                      );
                    },
                  ),
                ),

                // Action buttons - Premium design
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Tap the picture to view full profile.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Carousel indicators - dots only
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...List.generate(dailyState.profiles.length, (index) {
                        final isActive = index == _currentIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: isActive ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient:
                                  isActive
                                      ? LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.secondary,
                                        ],
                                      )
                                      : null,
                              color:
                                  isActive
                                      ? null
                                      : AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _recordProfileView(DatingProfile profile, String? uid) {
    if (uid == null) return;
    ref
        .read(dailyProfilesNotifierProvider.notifier)
        .recordProfileView(uid, profile.uid, false);
  }

  Widget _buildDailyLimitState(BuildContext context, DateTime resetTime) {
    final resetTimeText = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(resetTime.toLocal()),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              'You have viewed today\'s 5 profiles',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'New profiles will be available after midnight.\nNext reset: $resetTimeText',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ProfileCarouselCard extends ConsumerWidget {
  final DatingProfile profile;
  final bool isCurrentCard;
  final VoidCallback onTapProfile;
  final int? compatibilityScore;

  const _ProfileCarouselCard({
    required this.profile,
    required this.isCurrentCard,
    required this.onTapProfile,
    this.compatibilityScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(isProfileSavedProvider(profile.uid));
    final photo = profile.validProfilePhoto;

    return GestureDetector(
      onTap: onTapProfile,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.getBorder(context)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Background image - fills entire card
            Positioned.fill(
              child:
                  photo != null
                      ? CachedImage(
                        photo,
                        fit: BoxFit.cover,
                        cacheDuration: const Duration(days: 30),
                      )
                      : Container(
                        color: AppColors.getBackground(context),
                        child: Icon(
                          Icons.person,
                          size: 80,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
            ),

            // Dark gradient overlay - better for text visibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),
            ),

            // Compatibility score badge (top left)
            if (compatibilityScore != null)
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(compatibilityScore!),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${compatibilityScore}%',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Save button (top right)
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  ref
                      .read(savedProfilesNotifierProvider)
                      .toggleSave(profile.uid);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.textOnPrimary.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_outline,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ),

            // Profile info - bottom area with proper sizing
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name and age
                      Text(
                        '${profile.name}, ${profile.age}',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Location
                      if (profile.displayLocation.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.textOnPrimary.withOpacity(0.8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  profile.displayLocation,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textOnPrimary.withOpacity(
                                      0.8,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Profile traits badges
                      if (profile.maritalStatus != null ||
                          profile.profession != null ||
                          profile.haveKids != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (profile.maritalStatus != null)
                                _TraitBadge(profile.maritalStatus!),
                              if (profile.profession != null)
                                _TraitBadge(profile.profession!),
                              if (profile.haveKids != null)
                                _TraitBadge(
                                  profile.haveKids!.toLowerCase() == 'yes'
                                      ? 'Has kids'
                                      : 'No kids',
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Verification badge (bottom left)
            if (profile.isVerified)
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green[500]!;
    if (score >= 60) return Colors.orange[500]!;
    if (score >= 40) return Colors.amber[600]!;
    return Colors.red[500]!;
  }
}

class _TraitBadge extends StatelessWidget {
  final String text;

  const _TraitBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textOnPrimary.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Compact, styled empty state for age-range specific 'no profiles' cases
class _AgeRangeEmptyState extends StatelessWidget {
  final int minAge;
  final int maxAge;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  const _AgeRangeEmptyState({
    required this.minAge,
    required this.maxAge,
    required this.onEdit,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                color: AppColors.primary,
                size: 34,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'No Profiles within your selected Age Range Yet. Check back later.',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.08)),
              ),
              child: Text(
                'There are currently no profiles between $minAge and $maxAge years. Try widening your age range or check back later.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.35,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: onEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Edit Age Range',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                SizedBox(
                  width: 120,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onRefresh,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withOpacity(0.25)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Refresh',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
