import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/search_provider.dart';

/// Search Filters Bottom Sheet
/// Allows users to filter profiles by:
/// - Age range
/// - Location/Country
/// - Education
/// - Income source
/// - Marital status (divorced, widowed, never married)
/// - Has kids
/// - Genotype
/// - Long distance preference
/// 
/// NOTE: No denomination filter as requested
class SearchFiltersSheet extends ConsumerStatefulWidget {
  const SearchFiltersSheet({super.key});

  @override
  ConsumerState<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends ConsumerState<SearchFiltersSheet> {
  late RangeValues _ageRange;
  String? _country;
  String? _education;
  String? _incomeSource;
  String? _maritalStatus;
  String? _hasKids;
  String? _genotype;
  String? _longDistance;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(searchFiltersProvider);
    _ageRange = RangeValues(
      filters.minAge?.toDouble() ?? 21,
      filters.maxAge?.toDouble() ?? 60,
    );
    _country = filters.country;
    _education = filters.education;
    _incomeSource = filters.incomeSource;
    _maritalStatus = filters.maritalStatus;
    _hasKids = filters.hasKids;
    _genotype = filters.genotype;
    _longDistance = filters.longDistancePreference;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _resetFilters,
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Apply',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Filters
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Age Range
                  _buildSectionTitle('Age Range'),
                  const SizedBox(height: 8),
                  _buildAgeRangeSlider(),
                  const SizedBox(height: 24),
                  
                  // Country
                  _buildSectionTitle('Country'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _country,
                    hint: 'Any country',
                    items: _countries,
                    onChanged: (v) => setState(() => _country = v),
                  ),
                  const SizedBox(height: 24),
                  
                  // Education
                  _buildSectionTitle('Education'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _education,
                    hint: 'Any education level',
                    items: _educationLevels,
                    onChanged: (v) => setState(() => _education = v),
                  ),
                  const SizedBox(height: 24),
                  
                  // Income Source
                  _buildSectionTitle('Income Source'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _incomeSource,
                    hint: 'Any income source',
                    items: _incomeSources,
                    onChanged: (v) => setState(() => _incomeSource = v),
                  ),
                  const SizedBox(height: 24),
                  
                  // Marital Status
                  _buildSectionTitle('Marital Status'),
                  const SizedBox(height: 8),
                  _buildChipGroup(
                    options: _maritalStatuses,
                    selected: _maritalStatus,
                    onSelected: (v) => setState(() => _maritalStatus = v),
                  ),
                  const SizedBox(height: 24),
                  
                  // Has Kids
                  _buildSectionTitle('Has Children'),
                  const SizedBox(height: 8),
                  _buildChipGroup(
                    options: _hasKidsOptions,
                    selected: _hasKids,
                    onSelected: (v) => setState(() => _hasKids = v),
                  ),
                  const SizedBox(height: 24),
                  
                  // Genotype
                  _buildSectionTitle('Genotype'),
                  const SizedBox(height: 8),
                  _buildChipGroup(
                    options: _genotypes,
                    selected: _genotype,
                    onSelected: (v) => setState(() => _genotype = v),
                  ),
                  const SizedBox(height: 24),
                  
                  // Long Distance
                  _buildSectionTitle('Open to Long Distance'),
                  const SizedBox(height: 8),
                  _buildChipGroup(
                    options: _longDistanceOptions,
                    selected: _longDistance,
                    onSelected: (v) => setState(() => _longDistance = v),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildAgeRangeSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildAgeLabel(_ageRange.start.round()),
            Text(
              'to',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            _buildAgeLabel(_ageRange.end.round()),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surfaceLight,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withOpacity(0.1),
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
          ),
          child: RangeSlider(
            values: _ageRange,
            min: 21,
            max: 70,
            divisions: 49,
            onChanged: (values) {
              HapticFeedback.selectionClick();
              setState(() => _ageRange = values);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAgeLabel(int age) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$age years',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: AppColors.textMuted)),
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('Any', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ...items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildChipGroup({
    required List<String> options,
    String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(
          label: 'Any',
          isSelected: selected == null,
          onTap: () => onSelected(null),
        ),
        ...options.map((option) => _buildFilterChip(
          label: option,
          isSelected: selected == option,
          onTap: () => onSelected(option),
        )),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _resetFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _ageRange = const RangeValues(21, 60);
      _country = null;
      _education = null;
      _incomeSource = null;
      _maritalStatus = null;
      _hasKids = null;
      _genotype = null;
      _longDistance = null;
    });
  }

  void _applyFilters() {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(searchFiltersProvider.notifier);
    notifier.setAgeRange(_ageRange.start.round(), _ageRange.end.round());
    notifier.setCountry(_country);
    notifier.setEducation(_education);
    notifier.setIncomeSource(_incomeSource);
    notifier.setMaritalStatus(_maritalStatus);
    notifier.setHasKids(_hasKids);
    notifier.setGenotype(_genotype);
    notifier.setLongDistancePreference(_longDistance);
  }

  // Filter options
  static const _countries = [
    'Nigeria',
    'United States',
    'United Kingdom',
    'Canada',
    'Ghana',
    'South Africa',
    'Kenya',
    'Australia',
    'Germany',
    'France',
    'Other',
  ];

  static const _educationLevels = [
    'Graduate',
    'Any is fine',
  ];

  static const _incomeSources = [
    'Yes',
    'Not Compulsory',
  ];

  static const _maritalStatuses = [
    'Never Married',
    'Any is fine',
  ];

  static const _hasKidsOptions = [
    'No kids',
    'Any is fine',
  ];

  static const _genotypes = [
    'AA only',
    'Any',
  ];

  static const _longDistanceOptions = [
    'Yes',
    'No',
    'Maybe',
  ];
}

/// Show the search filters bottom sheet
void showSearchFiltersSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => const SearchFiltersSheet(),
    ),
  );
}
