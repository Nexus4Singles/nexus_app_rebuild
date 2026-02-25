import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/widgets/cached_image.dart';
import 'package:nexus_app_v2/features/profile/presentation/screens/profile_screen.dart';
import 'package:nexus_app_v2/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:nexus_app_v2/features/dating_search/application/saved_profiles_provider.dart';
import '../../domain/dating_profile.dart';
import '../../domain/dating_search_result.dart';
import '../../application/dating_search_results_provider.dart';
import '../../application/dating_preferences_provider.dart';
import '../../application/dating_dismissed_profiles_provider.dart';
import 'no_profiles_screen.dart';
import 'dating_preferences_setup_screen.dart';

/// Calculate hours, minutes, and seconds remaining until 24-hour daily limit resets
String _getCountdownText(DateTime limitHitAt) {
  final now = DateTime.now();
  final resetTime = limitHitAt.add(const Duration(hours: 24));
  final difference = resetTime.difference(now);

  final hours = difference.inHours;
  final minutes = difference.inMinutes % 60;
  final seconds = difference.inSeconds % 60;

  // Format: "23h 45m 30s"
  if (hours > 0) {
    return '${hours}h ${minutes}m ${seconds}s';
  } else if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  } else if (seconds > 0) {
    return '${seconds}s';
  } else {
    return 'Resetting...';
  }
}

class SearchResultsGridScreen extends ConsumerStatefulWidget {
  const SearchResultsGridScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchResultsGridScreen> createState() =>
      _SearchResultsGridScreenState();
}

class _SearchResultsGridScreenState
    extends ConsumerState<SearchResultsGridScreen>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _showDailyLimitCard = false;
  bool _isRestoringPosition = false;
  int _restoreAttempts = 0;
  bool _errorRetryScheduled = false;

  Future<bool> _handleBackToSavedPreferences() async {
    try {
      final prefs = await ref.read(datingPreferencesProvider.future);
      if (!mounted) return false;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => DatingPreferencesSetupScreen(existingPreferences: prefs),
        ),
      );
      return false;
    } catch (_) {
      if (!mounted) return false;

      // Fallback: still route to preferences setup instead of popping to a blank route.
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DatingPreferencesSetupScreen()),
      );
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Restore scroll position after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollPosition();
    });
  }

  void _restoreScrollPosition() {
    if (!mounted) return;
    final savedPosition = ref.read(searchResultsScrollPositionProvider);
    if (savedPosition > 0 && _scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent == 0.0 && _restoreAttempts < 5) {
        _restoreAttempts += 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreScrollPosition();
        });
        return;
      }

      final target = savedPosition.clamp(0.0, maxExtent).toDouble();
      _isRestoringPosition = true;
      _scrollController.jumpTo(target);
      // DEBUG: Restored scroll position - skipped to reduce log noise
      _isRestoringPosition = false;
    }
  }

  @override
  void dispose() {
    // Save scroll position before disposing
    if (_scrollController.hasClients) {
      final position = _scrollController.offset;
      ref.read(searchResultsScrollPositionProvider.notifier).state = position;
      // DEBUG: Saved scroll position - skipped to reduce log noise
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isRestoringPosition) return;

    // FIXED: Removed runaway offset increment that fired on every scroll
    // frame within 500px of bottom, causing accumulatedSearchResultsProvider
    // to re-evaluate repeatedly and reset the grid to the top.
    // All results are loaded in the initial 100-profile batch.

    // Show daily limit card when user reaches very bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      if (!_showDailyLimitCard) {
        setState(() => _showDailyLimitCard = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ref = this.ref;
    // FIXED: Use accumulating provider that shows results incrementally
    final resultsAsync = ref.watch(accumulatedSearchResultsProvider);
    final currentOffset = ref.watch(searchResultsOffsetProvider);
    final preferencesAsync = ref.watch(datingPreferencesProvider);

    return WillPopScope(
      onWillPop: _handleBackToSavedPreferences,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () {
              _handleBackToSavedPreferences();
            },
          ),
          title: Text('Search Results', style: AppTextStyles.headlineLarge),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Get preferences value before navigating
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
        body: resultsAsync.when(
          loading: () {
            _errorRetryScheduled = false;
            // During refresh/re-evaluation, keep showing previous results
            // so the grid is not destroyed and scroll position is preserved.
            // Only reuse previous results for incremental pagination loads.
            // For preference-change refresh (offset=0), show loader immediately.
            final cached = resultsAsync.valueOrNull;
            if (currentOffset > 0 &&
                cached != null &&
                cached.items.isNotEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  // DEBUG: User triggered refresh - skipped to reduce log noise
                  if (!mounted) return;
                  ref.invalidate(datingSearchResultsProvider);
                  ref.read(searchResultsCacheProvider.notifier).clear();
                  ref.read(searchResultsOffsetProvider.notifier).state = 0;
                  if (!mounted) return;
                  await ref.read(accumulatedSearchResultsProvider.future);
                },
                child: _PaginatedGridView(
                  allResults: cached,
                  scrollController: _scrollController,
                  onLoadMore: () {},
                ),
              );
            }
            // First load — show spinner only
            // DEBUG: First load, showing spinner - skipped to reduce log noise
            return Container(
              color: AppColors.getBackground(context),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Matches...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          error: (e, st) {
            if (!_errorRetryScheduled && mounted) {
              _errorRetryScheduled = true;
              Future.delayed(const Duration(seconds: 2), () async {
                if (!mounted) return;
                ref.invalidate(datingSearchResultsProvider);
                ref.read(searchResultsCacheProvider.notifier).clear();
                ref.read(searchResultsOffsetProvider.notifier).state = 0;
                try {
                  await ref.read(accumulatedSearchResultsProvider.future);
                } catch (_) {}
              });
            }
            return Center(
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
                    'Unable to load results',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Something went wrong. Please try again.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 120,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!mounted) return;
                        ref.invalidate(datingSearchResultsProvider);
                        ref.read(searchResultsCacheProvider.notifier).clear();
                        ref.read(searchResultsOffsetProvider.notifier).state =
                            0;
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            );
          },
          data: (result) {
            _errorRetryScheduled = false;
            // Only show "no profiles" screen when result is TRULY empty after ALL operations
            // complete (preferences loaded, daily limits applied, daily limit checks done, etc.)
            // If result is empty here, it means the provider (accumulatedSearchResultsProvider)
            // has fully completed all async operations and legitimately has no profiles.
            // This prevents showing "no profiles" during loading phases.
            if (result.items.isEmpty) {
              return ref
                  .watch(datingPreferencesProvider)
                  .when(
                    data: (preferences) {
                      return NoProfilesScreen(
                        noProfilesInCountry: result.noProfilesInCountry,
                        countryName: preferences?.countryOfResidence,
                        onRetry: () {
                          if (!mounted) return;
                          ref.invalidate(datingSearchResultsProvider);
                          ref.read(searchResultsCacheProvider.notifier).clear();
                          ref.read(searchResultsOffsetProvider.notifier).state =
                              0;
                        },
                        onEditPreferences: () {
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
                      );
                    },
                    loading:
                        () => const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        ),
                    error:
                        (e, st) => const Scaffold(
                          body: Center(
                            child: Text('Error loading preferences'),
                          ),
                        ),
                  );
            }

            return RefreshIndicator(
              onRefresh: () async {
                if (!mounted) return;
                ref.invalidate(datingSearchResultsProvider);
                ref.read(searchResultsCacheProvider.notifier).clear();
                ref.read(searchResultsOffsetProvider.notifier).state = 0;
                if (!mounted) return;
                await ref.read(accumulatedSearchResultsProvider.future);
              },
              child: _PaginatedGridView(
                allResults: result,
                scrollController: _scrollController,
                onLoadMore: () {
                  if (!mounted) return;
                  final currentOffset = ref.read(searchResultsOffsetProvider);
                  ref.read(searchResultsOffsetProvider.notifier).state =
                      currentOffset + 20;
                },
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// Custom widget to handle paginated grid display with load-more indicator
class _PaginatedGridView extends ConsumerStatefulWidget {
  final DatingSearchResult allResults;
  final ScrollController scrollController;
  final VoidCallback onLoadMore;

  const _PaginatedGridView({
    required this.allResults,
    required this.scrollController,
    required this.onLoadMore,
  });

  @override
  ConsumerState<_PaginatedGridView> createState() => _PaginatedGridViewState();
}

class _PaginatedGridViewState extends ConsumerState<_PaginatedGridView> {
  bool _showDailyLimitCard = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);

    // Start a countdown timer to update UI every minute (for live countdown)
    if (widget.allResults.hitDailyLimit &&
        widget.allResults.dailyLimitHitAt != null) {
      _startCountdownTimer();
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {}); // Rebuild every second for live countdown
      }
    });
  }

  @override
  void didUpdateWidget(_PaginatedGridView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }

    // Restart timer if daily limit changed
    if (widget.allResults.hitDailyLimit &&
        widget.allResults.dailyLimitHitAt != null) {
      _startCountdownTimer();
    } else {
      _countdownTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;

    // Show daily limit card when user reaches bottom
    if (!_showDailyLimitCard &&
        position.pixels >= position.maxScrollExtent - 100) {
      setState(() => _showDailyLimitCard = true);
    }

    // Pagination removed - no more load more logic needed
  }

  @override
  Widget build(BuildContext context) {
    // Pagination removed - all profiles now load at once
    // No need to watch offset or load more

    // APPLY PAGINATION DEPTH LIMIT
    // Enforce max pages based on subscription tier
    // Each page shows 20 profiles (2x10 grid)
    final maxProfilesAllowed = widget.allResults.maxPaginationPages * 20;
    final List<DatingProfile> displayItems = [
      ...widget.allResults.items.take(maxProfilesAllowed),
    ];

    final reachedPaginationCap =
        widget.allResults.items.length > maxProfilesAllowed;

    return Stack(
      children: [
        CustomScrollView(
          key: const PageStorageKey<String>(
            'dating-search-results-grid-scroll',
          ),
          controller: widget.scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _ProfileCard(profile: displayItems[index]);
                }, childCount: displayItems.length),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
              ),
            ),
            // Show "End of search results" message when pagination cap is reached
            if (reachedPaginationCap)
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'End of current search results',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ve reached ${widget.allResults.maxPaginationPages} pages. Adjust your preferences to explore different matches.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // Daily limit footer (FREE users only) when scrolled to bottom
        if (widget.allResults.hitDailyLimit && _showDailyLimitCard)
          _buildDailyLimitCard(context),
      ],
    );
  }

  Widget _buildDailyLimitCard(BuildContext context) {
    final limitHitAt = widget.allResults.dailyLimitHitAt;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.95),
              AppColors.primaryDark,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Maximum 10 Profiles/Day',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Subscribe to view several profiles at once',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (limitHitAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Resets in ${_getCountdownText(limitHitAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 85,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => const SubscriptionScreen(initialTabIndex: 0),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Upgrade',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

class _ProfileCard extends ConsumerWidget {
  final DatingProfile profile;

  const _ProfileCard({required this.profile});

  // Commented out - not currently used as joining date badge is disabled
  // String _getJoinedText(DateTime createdAt) {
  //   final now = DateTime.now();
  //   final difference = now.difference(createdAt);
  //
  //   if (difference.inDays == 0) {
  //     return 'Joined today';
  //   } else if (difference.inDays == 1) {
  //     return 'Joined yesterday';
  //   } else if (difference.inDays < 7) {
  //     return 'Joined ${difference.inDays}d ago';
  //   } else if (difference.inDays < 30) {
  //     final weeks = (difference.inDays / 7).floor();
  //     return 'Joined ${weeks}w ago';
  //   } else {
  //     final months = (difference.inDays / 30).floor();
  //     return 'Joined ${months}mo ago';
  //   }
  // }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final isSaved = ref.watch(isProfileSavedProvider(profile.uid));
      // FIXED: Use validProfilePhoto getter which handles deleted/missing photos
      final photo = profile.validProfilePhoto;

      return GestureDetector(
        onTap: () {
          try {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: profile.uid),
              ),
            );
          } catch (e) {
            // FIXED: Catch navigation errors to prevent Navigator history issues
            // This prevents cascading failures when one profile card fails
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error opening profile: $e')),
              );
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorder(context)),
            color: AppColors.getSurface(context),
          ),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child:
                    photo != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedImage(
                            photo,
                            fit: BoxFit.cover,
                            cacheDuration: const Duration(days: 30),
                            errorWidget: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: AppColors.getBackground(context),
                              ),
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 40,
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                          ),
                        )
                        : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.getBackground(context),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
              ),

              // Gradient overlay for readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.overlay],
                    ),
                  ),
                ),
              ),

              // Name, age, and compatibility badge
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${profile.name}, ${profile.age}',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.textOnPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (profile.displayLocation.isNotEmpty)
                                Text(
                                  profile.displayLocation,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textOnPrimary.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Save/Bookmark button (top right)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    // FIXED: Don't await - fire and forget for instant UI response
                    ref
                        .read(savedProfilesNotifierProvider)
                        .toggleSave(profile.uid);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_outline,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Joined date badge (top left) - Commented out for now
              // Positioned(
              //   top: 12,
              //   left: 12,
              //   child: Container(
              //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              //     decoration: BoxDecoration(
              //       color: Colors.black.withOpacity(0.6),
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: Text(
              //       _getJoinedText(profile.createdAt),
              //       style: AppTextStyles.labelSmall.copyWith(
              //         color: Colors.white,
              //         fontWeight: FontWeight.w600,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      );
    } catch (e) {
      // FIXED: Fallback error widget to prevent entire grid from breaking
      // This ensures one profile's issue doesn't crash the whole search grid
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context)),
          color: AppColors.getSurface(context),
        ),
        child: Stack(
          children: [
            // Error placeholder
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.getBackground(context),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 40,
                        color: AppColors.getTextSecondary(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Profile unavailable',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
