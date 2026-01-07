import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/lists/nexus_lists_provider.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/application/compatibility_status_provider.dart';

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
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );

    final guestSession = ref.watch(guestSessionProvider);
    final isGuest = guestSession != null;

    final compatAsync = ref.watch(compatibilityStatusProvider);
    final listsAsync = ref.watch(searchFilterListsProvider);

    final lists = listsAsync.maybeWhen(data: (v) => v, orElse: () => null);

    final countries = lists?.countryOfResidenceFilters ?? const <String>[];
    final educationLevels = lists?.educationLevelFilters ?? const <String>[];
    final incomeSources = lists?.incomeSourceFilters ?? const <String>[];
    final distances = lists?.relationshipDistanceFilters ?? const <String>[];
    final maritalStatuses = lists?.maritalStatusFilters ?? const <String>[];
    final hasKids = lists?.hasKidsFilters ?? const <String>[];
    final genotypes = lists?.genotypeFilters ?? const <String>[];

    return Scaffold(
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
                                (v) => setState(() => _countryOfResidence = v),
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
                            onChanged: (v) => setState(() => _longDistance = v),
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
                      child: Text(
                        'Results will appear here after search (hook Firestore query later).',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
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
                    if (!isSignedIn) {
                      await GuestGuard.requireSignedIn(
                        context,
                        ref,
                        title: 'Create an account to search',
                        message:
                            'You’re currently in guest mode. Create an account to run a search and view profiles.',
                        primaryText: 'Create an account',
                        onCreateAccount:
                            () => Navigator.of(context).pushNamed('/signup'),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Search coming soon')),
                    );
                  },
                  child: Text(isSignedIn ? 'Search' : 'Sign in to Search'),
                ),
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
