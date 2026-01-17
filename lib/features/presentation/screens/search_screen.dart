import 'package:flutter/material.dart';
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
import 'package:nexus_app_min_test/features/dating_search/domain/dating_search_filters.dart';
import 'package:nexus_app_min_test/features/dating_search/domain/dating_profile.dart';
import 'package:nexus_app_min_test/features/profile/presentation/screens/profile_screen.dart';

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
  String? _education;
  String? _sourceOfIncome;
  String? _longDistance;
  String? _maritalStatus;
  String? _kids;
  String? _genotype;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final user = authAsync.maybeWhen(data: (u) => u, orElse: () => null);
    final isSignedIn = user != null && !user.isAnonymous;

    final isGuestAsync = ref.watch(isGuestProvider);
    final isGuest = isGuestAsync.maybeWhen(data: (v) => v, orElse: () => !isSignedIn);
final compatAsync = ref.watch(compatibilityStatusProvider);
    final resultsAsync = ref.watch(datingSearchResultsProvider);
    final listsAsync = ref.watch(searchFilterListsProvider);

    final lists = listsAsync.maybeWhen(data: (v) => v, orElse: () => null);

    final countries = lists?.countryOfResidenceFilters ?? const <String>[];
    final educationLevels = lists?.educationLevelFilters ?? const <String>[];
    final incomeSources = lists?.incomeSourceFilters ?? const <String>[];
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
          title: Text('Search', style: AppTextStyles.headlineLarge),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchGateBanner(guest: isGuest, compatAsync: compatAsync),
                const SizedBox(height: 14),

                Text(
                  'Find a compatible partner',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select your preferences and explore profiles of Christian singles across the world.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 16),

                // Filters directly on page (NOT behind top-right icon)
                Expanded(
                  child: ListView(
                    children: [
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Search filters',
                              style: AppTextStyles.labelLarge,
                            ),
                            const SizedBox(height: 12),

                            Text('Age range', style: AppTextStyles.bodyMedium),
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 6),

                            _DropdownTile(
                              label: 'Country of Residence',
                              value: _countryOfResidence,
                              options: countries,
                              onChanged:
                                  (v) =>
                                      setState(() => _countryOfResidence = v),
                            ),
                            _DropdownTile(
                              label: 'Education Level',
                              value: _education,
                              options: educationLevels,
                              onChanged: (v) => setState(() => _education = v),
                            ),
                            _DropdownTile(
                              label: 'Regular Source of Income',
                              value: _sourceOfIncome,
                              options: incomeSources,
                              onChanged:
                                  (v) => setState(() => _sourceOfIncome = v),
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

                      const SizedBox(height: 14),

                      _SectionCard(
                        child: _SearchResultsCard(resultsAsync: resultsAsync),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      await DatingProfileGate.requireCompleteProfile(
                        context,
                        ref,
                        onAllowed: () async {
                          // Persist selected filters into the real provider
                          ref
                              .read(datingSearchFiltersProvider.notifier)
                              .state = DatingSearchFilters(
                            minAge: _minAge,
                            maxAge: _maxAge,
                            countryOfResidence: _countryOfResidence,
                            educationLevel: _education,
                            regularSourceOfIncome: _sourceOfIncome,
                            longDistance: _longDistance,
                            maritalStatus: _maritalStatus,
                            hasKids: _kids,
                            genotype: _genotype,
                          );

                          // Trigger a fresh Firestore-backed fetch
                          ref.invalidate(datingSearchResultsProvider);

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Searching…')),
                          );
                        },
                      );
                    },
                    child: Text(isSignedIn ? 'Search' : 'Sign in to Search'),
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

class _SearchResultsCard extends StatelessWidget {
  final AsyncValue<List<DatingProfile>> resultsAsync;
  const _SearchResultsCard({required this.resultsAsync});

  @override
  Widget build(BuildContext context) {
    return resultsAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (e, _) => Text(
            'Unable to load results right now. Please try again.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            'No results yet. Adjust filters and tap Search.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Results', style: AppTextStyles.labelLarge),
            const SizedBox(height: 12),
            ...items.take(20).map((p) => _SearchResultRow(profile: p)),
            if (items.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Showing first 20 results. Narrow filters to refine.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  final DatingProfile profile;
  const _SearchResultRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final photo = profile.photos.isNotEmpty ? profile.photos.first : null;
    final subtitle = [
      if (profile.displayLocation.trim().isNotEmpty) profile.displayLocation,
      if ((profile.profession ?? '').trim().isNotEmpty)
        profile.profession!.trim(),
    ].join(' • ');

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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 54,
                  height: 54,
                  color: Colors.black12,
                  child:
                      photo == null
                          ? const Icon(Icons.person, size: 28)
                          : Image.network(photo, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.name}, ${profile.age}',
                      style: AppTextStyles.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (!profile.isVerified)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Unverified (Legacy)',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
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
              const SizedBox(width: 10),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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

class _SearchGateBanner extends StatelessWidget {
  final bool guest;
  final AsyncValue<CompatibilityStatus> compatAsync;

  const _SearchGateBanner({required this.guest, required this.compatAsync});

  @override
  Widget build(BuildContext context) {
    if (guest) {
      return _BannerCard(
        title: 'Guest mode',
        body:
            'You can set filters now. To run a search and view profiles, please sign in.',
        cta: 'Create account',
        onTap: () => Navigator.of(context).pushNamed('/signup'),
      );
    }

    return compatAsync.when(
      data: (status) {
        if (status == CompatibilityStatus.incomplete) {
          return _BannerCard(
            title: 'Compatibility quiz required',
            body:
                'Complete your compatibility quiz before you can browse or search profiles.',
            cta: 'Take quiz',
            onTap: () => Navigator.of(context).pushNamed('/compatibility-quiz'),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;

  const _BannerCard({
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.lock_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onTap,
                    child: Text(
                      cta,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
