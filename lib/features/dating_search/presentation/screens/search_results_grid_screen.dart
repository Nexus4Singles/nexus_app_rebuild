import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Calculate hours remaining until 24-hour daily limit resets
int _getHoursUntilReset(DateTime limitHitAt) {
  final now = DateTime.now();
  final resetTime = limitHitAt.add(const Duration(hours: 24));
  final hoursRemaining = resetTime.difference(now).inHours;

  // Ensure we never show negative hours
  return hoursRemaining > 0 ? hoursRemaining : 0;
}

class SearchResultsGridScreen extends ConsumerStatefulWidget {
  const SearchResultsGridScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchResultsGridScreen> createState() =>
      _SearchResultsGridScreenState();
}

class _SearchResultsGridScreenState
    extends ConsumerState<SearchResultsGridScreen> {
  late ScrollController _scrollController;
  bool _showDailyLimitCard = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // FIXED: Trigger load-more when user scrolls near bottom
    // This loads the next batch of 30 profiles
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      // Trigger load more
      if (!_showDailyLimitCard) {
        final currentOffset = ref.read(searchResultsOffsetProvider);
        ref.read(searchResultsOffsetProvider.notifier).state =
            currentOffset + 30; // Load 30 more profiles
      }
    }

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
    final ref = this.ref;
    // FIXED: Use accumulating provider that shows results incrementally
    final resultsAsync = ref.watch(accumulatedSearchResultsProvider);
    final preferencesAsync = ref.watch(datingPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
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
          // FIXED: Don't show spinner - show empty state with loading indicator
          // User will see results start appearing as they load
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading Matches...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
        error: (e, st) {
          final isTimeout = e.toString().contains('Timeout');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTimeout ? Icons.schedule_rounded : Icons.error_outline,
                  size: 48,
                  color: AppColors.getTextSecondary(context),
                ),
                const SizedBox(height: 16),
                Text(
                  isTimeout ? 'Search Took Too Long' : 'Unable to load results',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isTimeout
                      ? 'Network may be slow. Try again.'
                      : 'Something went wrong. Please try again.',
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
                      ref.read(searchResultsOffsetProvider.notifier).state = 0;
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
                        body: Center(child: Text('Error loading preferences')),
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
    );
  }
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

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
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

    final List<DatingProfile> displayItems = [...widget.allResults.items];

    if (kDebugMode) {
      // ignore: avoid_print
      print('[SearchResultsGrid] displayItems=${displayItems.length}');
    }

    return Stack(
      children: [
        CustomScrollView(
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
            // Pagination removed - all profiles now load at once
          ],
        ),
        // Premium upsell footer (compact) if daily limit hit AND user scrolled to bottom
        if (widget.allResults.hitDailyLimit && _showDailyLimitCard)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.9),
                    AppColors.primary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Daily Limit Reached',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.allResults.dailyLimitHitAt != null)
                          Text(
                            'Resets in ${_getHoursUntilReset(widget.allResults.dailyLimitHitAt!)}h',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => const SubscriptionScreen(
                                  initialTabIndex:
                                      0, // Show Dating Features tab
                                ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
    final isSaved = ref.watch(isProfileSavedProvider(profile.uid));
    final photo = profile.photos.isNotEmpty ? profile.photos.first : null;
    if (photo == null || photo.isEmpty) {
      print(
        '[SearchResultsGrid] No photo for profile: uid=${profile.uid}, name=${profile.name}',
      );
    } else {
      print(
        '[SearchResultsGrid] Photo URL for profile: uid=${profile.uid}, name=${profile.name}, url=$photo',
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: profile.uid)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                Theme.of(context).brightness == Brightness.light
                    ? Color(0xFFD1D5DB)
                    : AppColors.border,
          ),
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
                          width: 200,
                          height: 300,
                          borderRadius: BorderRadius.circular(16),
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
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (profile.displayLocation.isNotEmpty)
                              Text(
                                profile.displayLocation,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white70,
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
                onTap: () async {
                  await ref
                      .read(savedProfilesNotifierProvider)
                      .toggleSave(profile.uid);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
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
  }
}
