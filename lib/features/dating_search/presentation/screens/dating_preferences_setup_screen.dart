import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/widgets/nexus_country_picker.dart';
import '../../domain/dating_preferences.dart';
import '../../application/dating_preferences_provider.dart';
import '../../application/dating_search_results_provider.dart';
import 'dating_preferences_confirmation_screen.dart';
import 'no_profiles_screen.dart';

class DatingPreferencesSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final DatingPreferences? existingPreferences;

  const DatingPreferencesSetupScreen({
    Key? key,
    this.onComplete,
    this.existingPreferences,
  }) : super(key: key);

  @override
  ConsumerState<DatingPreferencesSetupScreen> createState() =>
      _DatingPreferencesSetupScreenState();
}

class _DatingPreferencesSetupScreenState
    extends ConsumerState<DatingPreferencesSetupScreen> {
  late int _minAge;
  late int _maxAge;
  String? _country;
  bool? _allowLongDistance;
  bool? _openToKids;
  bool? _openToMarriedBefore;
  String? _genotype;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPreferences != null) {
      _minAge = widget.existingPreferences!.minAge;
      _maxAge = widget.existingPreferences!.maxAge;
      _country = widget.existingPreferences!.countryOfResidence;
      _allowLongDistance = widget.existingPreferences!.allowLongDistance;
      _openToKids = widget.existingPreferences!.openToKids;
      _openToMarriedBefore = widget.existingPreferences!.openToMarriedBefore;
      _genotype = widget.existingPreferences!.genotypePreference;
    } else {
      _minAge = 21;
      _maxAge = 65;
    }
  }

  void _savePreferences() async {
    // Validate required fields
    if (_country == null || _country!.isEmpty) {
      _showSnackBar('Please select your country of residence');
      return;
    }

    // Age is already set with defaults but validate it makes sense
    if (_minAge >= _maxAge) {
      _showSnackBar('Minimum age must be less than maximum age');
      return;
    }

    setState(() => _isLoading = true);

    final prefs = DatingPreferences(
      minAge: _minAge,
      maxAge: _maxAge,
      countryOfResidence: _country,
      allowLongDistance: _allowLongDistance,
      openToKids: _openToKids,
      openToMarriedBefore: _openToMarriedBefore,
      genotypePreference: _genotype,
      createdAt: widget.existingPreferences?.createdAt ?? DateTime.now(),
      lastRefreshedAt: DateTime.now(),
    );

    print('[DatingPreferencesSetup] SAVING preferences: minAge=$_minAge, maxAge=$_maxAge, country=$_country');

    try {
      await ref
          .read(datingPreferencesNotifierProvider.notifier)
          .savePreferences(prefs);

      if (!mounted) return;

      // Wait a bit for Firestore to sync
      await Future.delayed(const Duration(milliseconds: 300));

      // Invalidate both preferences and search results to force fresh fetch
      ref.invalidate(datingPreferencesProvider);
      ref.invalidate(datingSearchResultsProvider);
      ref.read(searchResultsCacheProvider.notifier).clear();

      // If editing existing preferences, just pop back to results
      if (widget.existingPreferences != null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // Check if there are any matching profiles for the new preferences
      // Skip this check if we're editing existing preferences
      if (widget.existingPreferences == null) {
        _checkProfilesAndNavigate(prefs);
      } else {
        // Just pop back if editing
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving preferences: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _checkProfilesAndNavigate(DatingPreferences prefs) async {
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Finding matches...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      // Wait a bit for Firestore to sync
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) {
        Navigator.of(context).pop();
        return;
      }

      // Invalidate search results to force refresh
      ref.invalidate(datingSearchResultsProvider);
      ref.read(searchResultsCacheProvider.notifier).clear();

      // Get the search results
      final resultsAsync = await ref.read(
        cachedDatingSearchResultsProvider.future,
      );

      if (!mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        return;
      }

      // Dismiss loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      // If no profiles match preferences, go directly to no profiles screen
      if (resultsAsync.items.isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => NoProfilesScreen(
                  onRetry: () {
                    ref.invalidate(datingSearchResultsProvider);
                    ref.read(searchResultsCacheProvider.notifier).clear();
                  },
                  onEditPreferences: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder:
                            (_) => DatingPreferencesSetupScreen(
                              existingPreferences: prefs,
                            ),
                      ),
                    );
                  },
                ),
          ),
        );
      } else {
        // Otherwise show confirmation screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const DatingPreferencesConfirmationScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking search results: $e');
      if (!mounted) return;

      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (_) {}

      if (!mounted) return;

      // Default to confirmation screen on error
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DatingPreferencesConfirmationScreen(),
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPreferences != null;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        toolbarHeight: 56,
        leading:
            isEditing
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                )
                : null,
        title: Text(
          isEditing ? 'Edit Preferences' : 'Your Preferences',
          style: AppTextStyles.headlineLarge,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Let\'s find your perfect match',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Answer a few questions about what you\'re looking for',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 16),

              // Age Range
              _PreferenceSection(
                title: 'What age range are you looking for?',
                compact: true,
                child: Row(
                  children: [
                    Text(
                      '$_minAge',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RangeSlider(
                        values: RangeValues(
                          _minAge.toDouble(),
                          _maxAge.toDouble(),
                        ),
                        min: 21,
                        max: 65,
                        divisions: 44,
                        onChanged: (RangeValues values) {
                          setState(() {
                            _minAge = values.start.toInt();
                            _maxAge = values.end.toInt();
                          });
                        },
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.border,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_maxAge',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Country
              _PreferenceSection(
                title: 'What country do you reside in?',
                child: _CountrySelector(
                  selectedCountry: _country,
                  onChanged: (country) {
                    setState(() => _country = country);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Long Distance
              _PreferenceSection(
                title:
                    'Would you like to connect with people outside your country of residence?',
                child: _YesNoButtons(
                  value: _allowLongDistance,
                  onChanged: (value) {
                    setState(() => _allowLongDistance = value);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Kids
              _PreferenceSection(
                title: 'Would you like to connect with people who have kids?',
                child: _YesNoButtons(
                  value: _openToKids,
                  onChanged: (value) {
                    setState(() => _openToKids = value);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Married Before
              _PreferenceSection(
                title:
                    'Would you like to connect with people who have been married before?',
                child: _YesNoButtons(
                  value: _openToMarriedBefore,
                  onChanged: (value) {
                    setState(() => _openToMarriedBefore = value);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Genotype
              _PreferenceSection(
                title: 'Do you have a genotype preference?',
                child: _GenotypeSelector(
                  selectedGenotype: _genotype,
                  onChanged: (genotype) {
                    setState(() => _genotype = genotype);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Save Preferences',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable section widget
class _PreferenceSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool compact;

  const _PreferenceSection({
    required this.title,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding:
              compact
                  ? const EdgeInsets.symmetric(vertical: 4, horizontal: 10)
                  : const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).brightness == Brightness.light
                      ? Color(0xFFD1D5DB)
                      : AppColors.border,
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Yes/No button pair
class _YesNoButtons extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _YesNoButtons({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PreferenceButton(
            label: 'Yes',
            isSelected: value == true,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PreferenceButton(
            label: 'No',
            isSelected: value == false,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PreferenceButton(
            label: 'No Preference',
            isSelected: value == null,
            onTap: () => onChanged(null),
          ),
        ),
      ],
    );
  }
}

/// Country selector
class _CountrySelector extends StatelessWidget {
  final String? selectedCountry;
  final ValueChanged<String?> onChanged;

  const _CountrySelector({
    required this.selectedCountry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        NexusCountryPicker.show(
          context: context,
          title: 'country of residence',
          onPicked: (country) {
            onChanged(country);
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                Theme.of(context).brightness == Brightness.light
                    ? Color(0xFFD1D5DB)
                    : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedCountry ?? 'Select country',
              style: AppTextStyles.bodyMedium.copyWith(
                color:
                    selectedCountry != null
                        ? AppColors.getTextPrimary(context)
                        : AppColors.getTextSecondary(context),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.getTextSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Genotype selector
class _GenotypeSelector extends StatelessWidget {
  final String? selectedGenotype;
  final ValueChanged<String?> onChanged;

  const _GenotypeSelector({
    required this.selectedGenotype,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PreferenceChip(
          label: 'No Preference',
          isSelected: selectedGenotype == null,
          onTap: () => onChanged(null),
        ),
        _PreferenceChip(
          label: 'AA',
          isSelected: selectedGenotype == 'AA',
          onTap: () => onChanged('AA'),
        ),
        _PreferenceChip(
          label: 'AS',
          isSelected: selectedGenotype == 'AS',
          onTap: () => onChanged('AS'),
        ),
        _PreferenceChip(
          label: 'SS',
          isSelected: selectedGenotype == 'SS',
          onTap: () => onChanged('SS'),
        ),
      ],
    );
  }
}

/// Individual preference button
class _PreferenceButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PreferenceButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary
                    : (Theme.of(context).brightness == Brightness.light
                        ? Color(0xFFD1D5DB)
                        : AppColors.border),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color:
                  isSelected
                      ? Colors.white
                      : AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Individual preference chip
class _PreferenceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PreferenceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary
                    : (Theme.of(context).brightness == Brightness.light
                        ? Color(0xFFD1D5DB)
                        : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color:
                isSelected ? Colors.white : AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
