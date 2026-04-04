import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/widgets/cached_image.dart';
import 'package:nexus_app_v2/features/profile/presentation/screens/profile_screen.dart';
import 'package:nexus_app_v2/features/dating_search/application/saved_profiles_provider.dart';
import '../../domain/dating_profile.dart';
import '../../domain/dating_search_result.dart';
import '../../application/dating_search_results_provider.dart';
import '../../application/dating_preferences_provider.dart';
import 'dating_preferences_setup_screen.dart';
import 'no_profiles_screen.dart';

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
  bool _isRestoringPosition = false;
  int _restoreAttempts = 0;
  bool _errorRetryScheduled = false;
  bool _autoRetryInFlight = false;

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
              _autoRetryInFlight = true;
              Future.delayed(const Duration(seconds: 2), () async {
                if (!mounted) return;
                ref.invalidate(datingSearchResultsProvider);
                ref.read(searchResultsCacheProvider.notifier).clear();
                ref.read(searchResultsOffsetProvider.notifier).state = 0;
                try {
                  await ref.read(accumulatedSearchResultsProvider.future);
                } catch (_) {}
                if (mounted) setState(() => _autoRetryInFlight = false);
              });
            }
            // Show loading spinner while the auto-retry is in flight,
            // so users never see "Something went wrong" for transient startup errors.
            if (_autoRetryInFlight) {
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
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!mounted) return;
                      ref.invalidate(datingSearchResultsProvider);
                      ref.read(searchResultsCacheProvider.notifier).clear();
                      ref.read(searchResultsOffsetProvider.notifier).state = 0;
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
          data: (result) {
            _errorRetryScheduled = false;
            _autoRetryInFlight = false;
            if (result.items.isEmpty) {
              // Items are empty — always show NoProfilesScreen.
              // No middle grounds: either profiles exist (grid) or they don't (NoProfilesScreen).
              Future<void> refreshResults() async {
                if (!mounted) return;
                ref.invalidate(datingSearchResultsProvider);
                ref.read(searchResultsCacheProvider.notifier).clear();
                ref.read(searchResultsOffsetProvider.notifier).state = 0;
                if (!mounted) return;
                await ref.read(accumulatedSearchResultsProvider.future);
              }

              return RefreshIndicator(
                onRefresh: refreshResults,
                child: NoProfilesScreen(
                  onRetry: refreshResults,
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
                  noProfilesInCountry: result.noProfilesInCountry,
                  countryName: result.noProfilesBreakdown?.countryName,
                  emptyHint: result.emptyHint,
                  breakdown: result.noProfilesBreakdown,
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
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_PaginatedGridView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {}

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
            if (widget.allResults.isExpandedSearch)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.public_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing compatible matches beyond your region while your local community grows.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
      ],
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
