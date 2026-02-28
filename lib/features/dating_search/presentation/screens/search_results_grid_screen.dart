import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/widgets/cached_image.dart';
import 'package:nexus_app_v2/core/constants/app_constants.dart';
import 'package:nexus_app_v2/core/router/app_routes.dart';
import 'package:nexus_app_v2/features/profile/presentation/screens/profile_screen.dart';
import 'package:nexus_app_v2/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:nexus_app_v2/features/dating_search/application/saved_profiles_provider.dart';
import '../../domain/dating_profile.dart';
import '../../domain/dating_search_result.dart';
import '../../application/dating_search_results_provider.dart';
import '../../application/dating_preferences_provider.dart';
import '../../application/dating_dismissed_profiles_provider.dart';
import 'dating_preferences_setup_screen.dart';

/// Calculate hours, minutes, and seconds remaining until 24-hour daily limit resets
String _getCountdownText(DateTime limitHitAt) {
  final now = DateTime.now();
  final resetTime = limitHitAt.add(const Duration(hours: 24));
  final difference = resetTime.difference(now);

  final hours = difference.inHours;
  final minutes = difference.inMinutes % 60;
  final seconds = difference.inSeconds % 60;

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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

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
      _isRestoringPosition = false;
    }
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      final position = _scrollController.offset;
      ref.read(searchResultsScrollPositionProvider.notifier).state = position;
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isRestoringPosition) return;

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
    final resultsAsync = ref.watch(accumulatedSearchResultsProvider);
    final currentOffset = ref.watch(searchResultsOffsetProvider);
    final preferencesAsync = ref.watch(datingPreferencesProvider);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: null,
          title: Text('Search Results', style: AppTextStyles.headlineMedium),
          actions: [
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
        body: resultsAsync.when(
          loading: () {
            _errorRetryScheduled = false;
            final cached = resultsAsync.valueOrNull;
            if (currentOffset > 0 &&
                cached != null &&
                cached.items.isNotEmpty) {
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
                  allResults: cached,
                  scrollController: _scrollController,
                  onLoadMore: () {},
                ),
              );
            }
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
            if (result.items.isEmpty) {
              // Inline empty state — no separate screen
              return RefreshIndicator(
                onRefresh: () async {
                  if (!mounted) return;
                  ref.invalidate(datingSearchResultsProvider);
                  ref.read(searchResultsCacheProvider.notifier).clear();
                  ref.read(searchResultsOffsetProvider.notifier).state = 0;
                  if (!mounted) return;
                  await ref.read(accumulatedSearchResultsProvider.future);
                },
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 64,
                                color: AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No profiles yet',
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'New users join every day. Pull down to refresh.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                                textAlign: TextAlign.center,
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

    if (widget.allResults.hitDailyLimit &&
        widget.allResults.dailyLimitHitAt != null) {
      _startCountdownTimer();
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
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

    if (!_showDailyLimitCard &&
        position.pixels >= position.maxScrollExtent - 100) {
      setState(() => _showDailyLimitCard = true);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    'Subscribe to view more profiles',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final isSaved = ref.watch(isProfileSavedProvider(profile.uid));
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
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error opening profile: $e'),
                  backgroundColor: AppColors.primary,
                ),
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
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
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
            ],
          ),
        ),
      );
    } catch (e) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context)),
          color: AppColors.getSurface(context),
        ),
        child: Stack(
          children: [
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
