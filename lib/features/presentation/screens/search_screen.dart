import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/providers/auth_provider.dart';
import 'package:nexus_app_min_test/core/lists/nexus_lists_provider.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/core/session/is_guest_provider.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';
import 'package:nexus_app_min_test/core/widgets/disabled_account_gate.dart';
import 'package:nexus_app_min_test/core/dating/dating_profile_gate.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/application/compatibility_status_provider.dart';
import 'package:nexus_app_min_test/features/dating_search/application/dating_search_results_provider.dart';
import 'package:nexus_app_min_test/features/dating_search/application/saved_profiles_provider.dart';
import 'package:nexus_app_min_test/features/dating_search/domain/dating_search_filters.dart';
import 'package:nexus_app_min_test/features/dating_search/domain/dating_profile.dart';
import 'package:nexus_app_min_test/features/profile/presentation/screens/profile_screen.dart';
import 'package:nexus_app_min_test/features/launch/presentation/app_launch_gate.dart';
import 'package:nexus_app_min_test/features/auth/presentation/screens/login_screen.dart';
import 'package:nexus_app_min_test/features/auth/presentation/screens/signup_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // Defaults
  int _minAge = 21;
  int _maxAge = 65;

  String? _countryOfResidence;
  String? _longDistance;
  String? _maritalStatus;
  String? _kids;
  String? _genotype;
  void _clearFilters() {
    setState(() {
      _minAge = 21;
      _maxAge = 65;

      _countryOfResidence = null;
      _longDistance = null;
      _maritalStatus = null;
      _kids = null;
      _genotype = null;
    });
  }

  void _showAuthModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sign in to Search',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create an account or log in to search and view dating profiles.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('Log In'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the canonical guest logic (automatically watches auth state)
    final isGuestAsync = ref.watch(isGuestProvider);
    final isGuest = isGuestAsync.maybeWhen(
      data: (v) => v,
      orElse: () => true, // Default to guest while loading
    );

    final listsAsync = ref.watch(searchFilterListsProvider);

    final lists = listsAsync.maybeWhen(data: (v) => v, orElse: () => null);

    final countries = lists?.countryOfResidenceFilters ?? const <String>[];
    final distances = lists?.relationshipDistanceFilters ?? const <String>[];
    final maritalStatuses = lists?.maritalStatusFilters ?? const <String>[];
    final hasKids = lists?.hasKidsFilters ?? const <String>[];
    final genotypes = lists?.genotypeFilters ?? const <String>[];

    return DisabledAccountGate(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
          titleSpacing: 20,
          title: Text(
            'Search',
            style: AppTextStyles.headlineLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find a compatible partner',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Select your preferences and explore profiles of Christian singles across the world.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // Filters directly on page (NOT behind top-right icon)
                Expanded(
                  child: ListView(
                    children: [
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.tune,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'SEARCH FILTERS',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _clearFilters,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppColors.primary
                                        .withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    'Clear',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            Text(
                              'Age Range',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_minAge - $_maxAge years',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RangeSlider(
                              values: RangeValues(
                                _minAge.toDouble(),
                                _maxAge.toDouble(),
                              ),
                              min: 21,
                              max: 65,
                              divisions: 44,
                              labels: RangeLabels('$_minAge', '$_maxAge'),
                              onChanged: (v) {
                                setState(() {
                                  _minAge = v.start.round();
                                  _maxAge = v.end.round();
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            _DropdownTile(
                              label: 'Country of Residence',
                              value: _countryOfResidence,
                              options: countries,
                              onChanged:
                                  (v) =>
                                      setState(() => _countryOfResidence = v),
                            ),
                            _DropdownTile(
                              label: 'Long Distance',
                              value: _longDistance,
                              options: distances,
                              onChanged:
                                  (v) => setState(() => _longDistance = v),
                            ),
                            _DropdownTile(
                              label: 'Marital Status',
                              value: _maritalStatus,
                              options: maritalStatuses,
                              onChanged:
                                  (v) => setState(() => _maritalStatus = v),
                            ),
                            _DropdownTile(
                              label: 'Has Kids',
                              value: _kids,
                              options: hasKids,
                              onChanged: (v) => setState(() => _kids = v),
                            ),
                            _DropdownTile(
                              label: 'Genotype',
                              value: _genotype,
                              options: genotypes,
                              onChanged: (v) => setState(() => _genotype = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (isGuest) {
                        // Show auth modal for guests
                        _showAuthModal(context);
                        return;
                      }

                      // Persist UI selections into provider state (Results screen reads from this)
                      if (kDebugMode) {
                        // ignore: avoid_print
                        print(
                          '[SearchScreen] applying filters: '
                          'age=$_minAge-$_maxAge, '
                          'country="$_countryOfResidence", '
                          'distance="$_longDistance", '
                          'marital="$_maritalStatus", '
                          'kids="$_kids", '
                          'geno="$_genotype"',
                        );
                      }

                      ref
                          .read(datingSearchFiltersProvider.notifier)
                          .state = DatingSearchFilters(
                        minAge: _minAge,
                        maxAge: _maxAge,
                        countryOfResidence: _countryOfResidence,
                        countryOptions: countries,
                        longDistance: _longDistance,
                        maritalStatus: _maritalStatus,
                        hasKids: _kids,
                        genotype: _genotype,
                      );

                      ref.invalidate(datingSearchResultsProvider);

                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SearchResultsScreen(),
                        ),
                      );
                    },
                    child: Text(!isGuest ? 'Search' : 'Sign in to Search'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(datingSearchResultsProvider);

    return DisabledAccountGate(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
          title: Text('Results', style: AppTextStyles.headlineLarge),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => Text(
                    'Unable to load results right now. Please try again.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
              data: (result) {
                final items = result.items;
                if (items.isEmpty) {
                  final hint = result.emptyHint;
                  final hasHint = hint != null && hint.trim().isNotEmpty;

                  final title =
                      hasHint
                          ? 'No matches for your current filters'
                          : 'No matches found';

                  final subtitle =
                      hasHint
                          ? 'Try removing: $hint'
                          : 'Widen your filters and try again.';

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Icon(
                                Icons.search_off_rounded,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(title, style: AppTextStyles.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textMuted,
                                height: 1.35,
                              ),
                            ),
                            if (hasHint) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Tip: start with 1–2 filters, then narrow down.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Adjust filters'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(datingSearchResultsProvider);
                    await ref.read(datingSearchResultsProvider.future);
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder:
                        (context, i) => _SearchResultRow(profile: items[i]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultRow extends ConsumerWidget {
  final DatingProfile profile;
  const _SearchResultRow({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = profile.photos.isNotEmpty ? profile.photos.first : null;
    final subtitle = [
      if (profile.displayLocation.trim().isNotEmpty) profile.displayLocation,
      if ((profile.profession ?? '').trim().isNotEmpty)
        profile.profession!.trim(),
    ].join(' • ');

    final displayName =
        (profile.name).trim().isNotEmpty ? profile.name.trim() : 'User';

    final isSaved = ref.watch(isProfileSavedProvider(profile.uid));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: profile.uid),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 46,
                  height: 46,
                  color: Colors.black12,
                  child:
                      photo == null
                          ? const Icon(Icons.person, size: 24)
                          : Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) =>
                                    const Icon(Icons.person, size: 24),
                          ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${displayName}, ${profile.age}',
                      style: AppTextStyles.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    if (subtitle.trim().isNotEmpty)
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Bookmark button
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  await ref
                      .read(savedProfilesNotifierProvider)
                      .toggleSave(profile.uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSaved ? 'Removed from saved' : 'Profile saved!',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor:
                            isSaved
                                ? AppColors.textSecondary
                                : AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isSaved
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? AppColors.primary : AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownTile({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        value: (value != null && options.contains(value)) ? value : null,
        items:
            options
                .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
                .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
