import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/lists/nexus_lists_provider.dart';
import 'package:nexus_app_min_test/features/dating_search/application/dating_search_results_provider.dart';
import 'package:nexus_app_min_test/features/dating_search/domain/dating_profile.dart';

import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/application/compatibility_status_provider.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // Filters (stub state for now)
  int _minAge = 21;
  int _maxAge = 65;

  String? _countryOfResidence;
  String? _nationality;
  String? _education;
  String? _sourceOfIncome;
  String? _longDistance;
  String? _maritalStatus;
  String? _kids;
  String? _genotype;

  // Results (stub)
  bool _showResults = true;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );

    final guestSession = ref.watch(guestSessionProvider);
    final isGuest = guestSession != null;
    final gender = guestSession?.gender; // collected from presurvey
    final oppositeGender = _oppositeGender(gender);

    final compatAsync = ref.watch(compatibilityStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Search', style: AppTextStyles.headlineLarge),
        actions: [
          IconButton(
            onPressed: () => _openFilters(context),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filters',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchGateBanner(guest: isGuest, compatAsync: compatAsync),
            const SizedBox(height: 16),
            if (gender == null) ...[
              _InfoBanner(
                text:
                    'Please complete presurvey to enable dating search personalization.',
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child:
                  _showResults
                      ? _ResultsGrid(oppositeGender: oppositeGender)
                      : const _EmptyState(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomActionBar(
        isSignedIn: isSignedIn,
        onReset: _resetFilters,
        onApply: () async {
          if (!isSignedIn) {
            await GuestGuard.requireSignedIn(
              context,
              ref,
              title: 'Create an account to search',
              message:
                  'You\'re currently in guest mode. Create an account to search and view profiles.',
              primaryText: 'Create an account',
              onCreateAccount: () => Navigator.of(context).pushNamed('/signup'),
            );
            return;
          }

          // TODO: real Firestore query + opposite sex enforcement + result stream.
          setState(() => _showResults = true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Filters applied (TODO)')),
          );
        },
      ),
    );
  }

  String? _oppositeGender(String? g) {
    if (g == null) return null;
    if (g.toLowerCase() == 'male') return 'female';
    if (g.toLowerCase() == 'female') return 'male';
    return null;
  }

  void _resetFilters() {
    setState(() {
      _minAge = 21;
      _maxAge = 65;
      _countryOfResidence = null;
      _nationality = null;
      _education = null;
      _sourceOfIncome = null;
      _longDistance = null;
      _maritalStatus = null;
      _kids = null;
      _genotype = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Filters reset')));
  }

  Future<void> _openFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: _FilterSheet(
                minAge: _minAge,
                maxAge: _maxAge,
                countryOfResidence: _countryOfResidence,
                nationality: _nationality,
                education: _education,
                sourceOfIncome: _sourceOfIncome,
                longDistance: _longDistance,
                maritalStatus: _maritalStatus,
                kids: _kids,
                genotype: _genotype,
                onChanged: (s) {
                  setState(() {
                    _minAge = s.minAge;
                    _maxAge = s.maxAge;
                    _countryOfResidence = s.countryOfResidence;
                    _nationality = s.nationality;
                    _education = s.education;
                    _sourceOfIncome = s.sourceOfIncome;
                    _longDistance = s.longDistance;
                    _maritalStatus = s.maritalStatus;
                    _kids = s.kids;
                    _genotype = s.genotype;
                  });
                },
              ),
            ),
          ),
    );
  }
}

class _FilterState {
  final int minAge;
  final int maxAge;
  final String? countryOfResidence;
  final String? nationality;
  final String? education;
  final String? sourceOfIncome;
  final String? longDistance;
  final String? maritalStatus;
  final String? kids;
  final String? genotype;

  const _FilterState({
    required this.minAge,
    required this.maxAge,
    required this.countryOfResidence,
    this.nationality,
    this.education,
    this.sourceOfIncome,
    this.longDistance,
    this.maritalStatus,
    this.kids,
    this.genotype,
  });
}

class _FilterSheet extends ConsumerStatefulWidget {
  final int minAge;
  final int maxAge;
  final String? countryOfResidence;
  final String? nationality;
  final String? education;
  final String? sourceOfIncome;
  final String? longDistance;
  final String? maritalStatus;
  final String? kids;
  final String? genotype;

  final ValueChanged<_FilterState> onChanged;

  const _FilterSheet({
    required this.minAge,
    required this.maxAge,
    required this.countryOfResidence,
    required this.nationality,
    required this.education,
    required this.sourceOfIncome,
    required this.longDistance,
    required this.maritalStatus,
    required this.kids,
    required this.genotype,
    required this.onChanged,
  });

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late int minAge = widget.minAge;
  late int maxAge = widget.maxAge;

  String? countryOfResidence;

  String? nationality;
  String? education;
  String? sourceOfIncome;
  String? longDistance;
  String? maritalStatus;
  String? kids;
  String? genotype;

  @override
  void initState() {
    super.initState();
    countryOfResidence = widget.countryOfResidence;
    nationality = widget.nationality;
    education = widget.education;
    sourceOfIncome = widget.sourceOfIncome;
    longDistance = widget.longDistance;
    maritalStatus = widget.maritalStatus;
    kids = widget.kids;
    genotype = widget.genotype;
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(searchFilterListsProvider);

    final lists = listsAsync.maybeWhen(data: (v) => v, orElse: () => null);

    final countries = lists?.countryOfResidenceFilters ?? const <String>[];
    final educationLevels = lists?.educationLevelFilters ?? const <String>[];
    final incomeSources = lists?.incomeSourceFilters ?? const <String>[];
    final distances = lists?.relationshipDistanceFilters ?? const <String>[];
    final maritalStatuses = lists?.maritalStatusFilters ?? const <String>[];
    final hasKids = lists?.hasKidsFilters ?? const <String>[];
    final genotypes = lists?.genotypeFilters ?? const <String>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Search for a life partner', style: AppTextStyles.titleLarge),
        const SizedBox(height: 14),

        _DropdownTile(
          label: 'Country of Residence',
          value: countryOfResidence,
          onTap: () async {
            final v = await _pickSimple(
              context,
              'Country of Residence',
              countries,
            );
            setState(() => countryOfResidence = v);
          },
        ),
        _DropdownTile(
          label: 'Nationality',
          value: nationality,
          onTap: () async {
            final v = await _pickSimple(context, 'Nationality', countries);
            setState(() => nationality = v);
          },
        ),
        _DropdownTile(
          label: 'Education Level',
          value: education,
          onTap: () async {
            final v = await _pickSimple(
              context,
              'Education Level',
              educationLevels,
            );
            setState(() => education = v);
          },
        ),
        _DropdownTile(
          label: 'Regular Source of Income',
          value: sourceOfIncome,
          onTap: () async {
            final v = await _pickSimple(
              context,
              'Source of Income',
              incomeSources,
            );
            setState(() => sourceOfIncome = v);
          },
        ),
        _DropdownTile(
          label: 'Long Distance',
          value: longDistance,
          onTap: () async {
            final v = await _pickSimple(context, 'Long Distance', distances);
            setState(() => longDistance = v);
          },
        ),
        _DropdownTile(
          label: 'Marital Status',
          value: maritalStatus,
          onTap: () async {
            final v = await _pickSimple(
              context,
              'Marital Status',
              maritalStatuses,
            );
            setState(() => maritalStatus = v);
          },
        ),
        _DropdownTile(
          label: 'Has Kids',
          value: kids,
          onTap: () async {
            final v = await _pickSimple(context, 'Has Kids', hasKids);
            setState(() => kids = v);
          },
        ),
        _DropdownTile(
          label: 'Genotype',
          value: genotype,
          onTap: () async {
            final v = await _pickSimple(context, 'Genotype', genotypes);
            setState(() => genotype = v);
          },
        ),

        const SizedBox(height: 18),
        Text('Age Range', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(minAge.toDouble(), maxAge.toDouble()),
          min: 21,
          max: 65,
          divisions: 47,
          labels: RangeLabels('$minAge', '$maxAge'),
          onChanged: (v) {
            setState(() {
              minAge = v.start.round();
              maxAge = v.end.round();
            });
          },
        ),

        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.onChanged(
                _FilterState(
                  minAge: minAge,
                  maxAge: maxAge,
                  countryOfResidence: countryOfResidence,
                  nationality: nationality,
                  education: education,
                  sourceOfIncome: sourceOfIncome,
                  longDistance: longDistance,
                  maritalStatus: maritalStatus,
                  kids: kids,
                  genotype: genotype,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Search Filters'),
          ),
        ),
      ],
    );
  }

  Future<String?> _pickSimple(
    BuildContext context,
    String title,
    List<String> options,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Text(title, style: AppTextStyles.titleLarge),
                const SizedBox(height: 12),
                ...options.map(
                  (o) => ListTile(
                    title: Text(o),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, o),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DropdownTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color:
                        value == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsGrid extends ConsumerWidget {
  final String? oppositeGender;

  const _ResultsGrid({required this.oppositeGender});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real results come from Firestore provider (gated by guest + compatibility + firebaseReady).
    final resultsAsync = ref.watch(datingSearchResultsProvider);

    return resultsAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return const _EmptyState();
        }

        final filtered =
            (oppositeGender == null)
                ? profiles
                : profiles.where((p) => p.gender == oppositeGender).toList();

        if (filtered.isEmpty) {
          return const _EmptyState();
        }

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final p = filtered[index];
            return _ProfileCard(profile: p);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _EmptyState(),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final DatingProfile profile;

  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.photos.isNotEmpty ? profile.photos.first : null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Open ${profile.name} (TODO)')));
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child:
                    photoUrl == null
                        ? Container(
                          color: AppColors.primary.withOpacity(0.06),
                          child: const Icon(
                            Icons.person,
                            size: 90,
                            color: AppColors.border,
                          ),
                        )
                        : Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                color: AppColors.primary.withOpacity(0.06),
                                child: const Icon(
                                  Icons.person,
                                  size: 90,
                                  color: AppColors.border,
                                ),
                              ),
                        ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.name}, ${profile.age}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.displayLocation,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.profession ?? '',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}

class _BottomActionBar extends StatelessWidget {
  final bool isSignedIn;
  final VoidCallback onReset;
  final Future<void> Function() onApply;

  const _BottomActionBar({
    required this.isSignedIn,
    required this.onReset,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReset,
                child: const Text('Reset Filter'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async => onApply(),
                child: const Text('Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No results yet.\nAdjust filters and apply.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
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
        cta: 'Sign in',
        onTap: () => Navigator.of(context).pushNamed('/login'),
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
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
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
