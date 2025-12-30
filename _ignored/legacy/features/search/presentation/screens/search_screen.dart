import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/search_provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading_states.dart';
import '../../../../core/widgets/profile_gating_modal.dart';
import '../widgets/profile_card.dart';
import '../widgets/search_filters_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> 
    with SingleTickerProviderStateMixin {
  bool _hasSearched = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);
    final canViewProfiles = ref.watch(canViewProfilesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Beautiful header
            _buildHeader(context, filters),

            // Profile completion banner (if incomplete)
            if (!canViewProfiles)
              const ProfileCompletionBanner(),

            // Results or empty state
            Expanded(
              child: _hasSearched
                  ? _buildResults(context, ref, canViewProfiles)
                  : _buildSearchPrompt(context, filters),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SearchFilters filters) {
    final hasFilters = _hasActiveFilters(filters);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Your Match',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discover faith-centered singles',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              // Filter button with badge
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: hasFilters 
                          ? AppColors.primary.withOpacity(0.1) 
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => _showFilterModal(context),
                      icon: Icon(
                        Icons.tune_rounded,
                        color: hasFilters ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (hasFilters)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Age range quick filter with modern slider
          _buildAgeRangeSlider(filters),
          
          const SizedBox(height: 16),
          
          // Search button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _hasSearched = true);
                _animationController.forward(from: 0);
                ref.invalidate(filteredSearchResultsProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeRangeSlider(SearchFilters filters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Age Range',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${filters.minAge} - ${filters.maxAge} years',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primary.withOpacity(0.2),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withOpacity(0.1),
            trackHeight: 4,
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 2,
            ),
          ),
          child: RangeSlider(
            values: RangeValues(
              filters.minAge.toDouble(),
              filters.maxAge.toDouble(),
            ),
            min: 21,
            max: 70,
            divisions: 49,
            onChanged: (values) {
              ref.read(searchFiltersProvider.notifier).setAgeRange(
                values.start.toInt(),
                values.end.toInt(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchPrompt(BuildContext context, SearchFilters filters) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated heart icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.secondary.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Ready to Find Love?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Set your preferences and tap Search\nto discover faith-centered singles.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Quick filter chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickFilterChip('All Ages', filters.minAge == 21 && filters.maxAge == 70),
                _buildQuickFilterChip('25-35', filters.minAge == 25 && filters.maxAge == 35),
                _buildQuickFilterChip('35-45', filters.minAge == 35 && filters.maxAge == 45),
                _buildQuickFilterChip('45+', filters.minAge == 45 && filters.maxAge == 70),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        final notifier = ref.read(searchFiltersProvider.notifier);
        switch (label) {
          case 'All Ages':
            notifier.setAgeRange(21, 70);
            break;
          case '25-35':
            notifier.setAgeRange(25, 35);
            break;
          case '35-45':
            notifier.setAgeRange(35, 45);
            break;
          case '45+':
            notifier.setAgeRange(45, 70);
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, WidgetRef ref, bool canViewProfiles) {
    final resultsAsync = ref.watch(filteredSearchResultsProvider);

    return resultsAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return _buildNoResults(context);
        }
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Results count
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text(
                      '${users.length} ${users.length == 1 ? 'Match' : 'Matches'} Found',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    // Sort button - disabled until we have enough users
                    // Will implement: Recently Active, Newest, Age, etc.
                    TextButton.icon(
                      onPressed: null, // Disabled for now
                      icon: Icon(Icons.sort, size: 18, color: AppColors.textMuted.withOpacity(0.5)),
                      label: Text(
                        'Sort',
                        style: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              // Grid of profiles
              Expanded(
                child: _buildProfileGrid(context, users, canViewProfiles),
              ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingState(),
      error: (e, _) => AppErrorState(
        message: 'Failed to load profiles',
        onRetry: () => ref.invalidate(filteredSearchResultsProvider),
      ),
    );
  }

  Widget _buildProfileGrid(BuildContext context, List<UserModel> users, bool canViewProfiles) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68, // Taller cards for more photo visibility
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isSaved = ref.watch(isProfileSavedProvider(user.id));
        
        return ProfileCard(
          user: user,
          showSaveButton: canViewProfiles,
          isSaved: isSaved,
          onTap: () => _handleProfileTap(context, ref, user, canViewProfiles),
          onSave: canViewProfiles ? () {
            ref.read(savedProfilesProvider.notifier).toggleSave(user.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isSaved ? 'Removed from saved' : 'Profile saved!'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: isSaved ? AppColors.textSecondary : AppColors.primary,
                duration: const Duration(seconds: 1),
              ),
            );
          } : null,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Matches Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters\nto see more profiles',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(searchFiltersProvider.notifier).reset();
                ref.invalidate(filteredSearchResultsProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset Filters'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProfileTap(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    bool canViewProfiles,
  ) async {
    if (!canViewProfiles) {
      await ProfileGatingModal.show(
        context,
        title: 'View Full Profiles',
        message: 'Complete your dating profile to view full profiles and connect with others.',
      );
      return;
    }
    context.push('/profile/${user.uid}');
  }

  bool _hasActiveFilters(SearchFilters filters) {
    return filters.education != null ||
        filters.church != null ||
        filters.country != null ||
        filters.nationality != null ||
        filters.incomeSource != null ||
        filters.longDistancePreference != null ||
        filters.maritalStatus != null ||
        filters.hasKids != null ||
        filters.genotype != null;
  }

  void _showFilterModal(BuildContext context) {
    showSearchFiltersSheet(context);
  }
}

