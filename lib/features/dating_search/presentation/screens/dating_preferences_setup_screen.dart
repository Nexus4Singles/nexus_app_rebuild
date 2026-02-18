import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/widgets/nexus_country_picker.dart';
import 'package:nexus_app_v2/features/presurvey/presentation/screens/presurvey_relationship_status_screen.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/core/user/current_user_doc_provider.dart';
import '../../../auth/presentation/screens/signup_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'dart:async';
import '../../domain/dating_preferences.dart';
import '../../application/dating_preferences_provider.dart';
import '../../application/dating_search_results_provider.dart';
import 'dating_preferences_confirmation_screen.dart';
import 'no_profiles_screen.dart';
import '../widgets/dating_pool_guidelines_modal.dart';
import '../../application/dating_pool_guidelines_provider.dart';

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
  bool _guidelinesModalShown = false; // Track if modal was shown this session

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
      _maxAge = 70;
      // Show guidelines modal on first visit to dating search (non-editing mode)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGuidelinesModalIfNeeded();
      });
    }
  }

  void _savePreferences() async {
    // Check if user is authenticated - if not, show guest gate modal
    final authAsync = ref.watch(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (u) => u != null,
      orElse: () => false,
    );

    if (!isSignedIn) {
      _showGuestGateModal();
      return;
    }

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

    print(
      '[DatingPreferencesSetup] SAVING preferences: minAge=$_minAge, maxAge=$_maxAge, country=$_country',
    );

    try {
      await ref
          .read(datingPreferencesNotifierProvider.notifier)
          .savePreferences(prefs);

      if (!mounted) return;

      // FIXED: Wait longer for Firestore to complete the write
      // This ensures the new preferences are available before we invalidate
      await Future.delayed(const Duration(milliseconds: 800));

      // Invalidate both preferences and search results to force fresh fetch
      ref.invalidate(datingPreferencesProvider);
      ref.invalidate(datingSearchResultsProvider);
      ref.read(searchResultsCacheProvider.notifier).clear();

      // FIXED: Wait for preferences to actually reload from Firestore
      // Don't proceed until new preferences are loaded
      try {
        await ref.read(datingPreferencesProvider.future);
      } catch (_) {
        // If preferences fail to reload, proceed anyway
      }

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
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Finding matches...',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // FIXED: Wait longer for preferences to sync to Firestore
      // This ensures search results use the new preferences
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) {
        try {
          if (dialogContext?.mounted ?? false)
            Navigator.of(dialogContext!).pop();
        } catch (_) {}
        return;
      }

      // FIXED: Ensure preferences are reloaded before invalidating search
      try {
        await ref.read(datingPreferencesProvider.future);
        print('[DatingPreferencesSetupScreen] Preferences reloaded');
      } catch (e) {
        print('[DatingPreferencesSetupScreen] Error reloading preferences: $e');
        // If preferences reload fails, still proceed with search
      }

      // Invalidate search results to force refresh with new preferences
      ref.invalidate(datingSearchResultsProvider);
      ref.read(searchResultsCacheProvider.notifier).clear();
      print(
        '[DatingPreferencesSetupScreen] Cache cleared, fetching results...',
      );

      // FIXED: Add timeout to prevent endless loading spinner
      // If search takes >20 seconds, assume something is wrong and show error
      final resultsAsync = await ref
          .read(cachedDatingSearchResultsProvider.future)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              print(
                '[DatingPreferencesSetupScreen] Search timeout after 20 seconds',
              );
              throw TimeoutException(
                'Search took too long',
                const Duration(seconds: 20),
              );
            },
          );

      print(
        '[DatingPreferencesSetupScreen] ✅ Got ${resultsAsync.items.length} results',
      );

      if (!mounted) {
        try {
          if (dialogContext?.mounted ?? false)
            Navigator.of(dialogContext!).pop();
        } catch (_) {}
        return;
      }

      // Dismiss loading dialog BEFORE navigating
      try {
        if (dialogContext?.mounted ?? false) {
          Navigator.of(dialogContext!).pop();
          print('[DatingPreferencesSetupScreen] Dialog dismissed');
        }
      } catch (e) {
        print('[DatingPreferencesSetupScreen] Error dismissing dialog: $e');
      }

      if (!mounted) return;

      // If no profiles match preferences, go directly to no profiles screen
      if (resultsAsync.items.isEmpty) {
        print(
          '[DatingPreferencesSetupScreen] No profiles found, showing no-profiles screen',
        );
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
        print('[DatingPreferencesSetupScreen] Showing confirmation screen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const DatingPreferencesConfirmationScreen(),
          ),
        );
      }
    } catch (e) {
      print(
        '[DatingPreferencesSetupScreen] Error in _checkProfilesAndNavigate: $e',
      );
      if (!mounted) return;

      try {
        if (dialogContext?.mounted ?? false) {
          Navigator.of(dialogContext!).pop();
        }
      } catch (_) {}

      if (!mounted) return;

      // Default to confirmation screen on error
      print(
        '[DatingPreferencesSetupScreen] Error occurred, showing confirmation screen anyway',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DatingPreferencesConfirmationScreen(),
        ),
      );
    }
  }

  void _showGuestGateModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.getBackground(context),
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Preferences', style: AppTextStyles.headlineLarge),
                      const SizedBox(height: 16),
                      Text(
                        'You are currently in guest mode. To save your dating preferences, create an account or log in.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const PresurveyRelationshipStatusScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.getTextOnPrimary(
                              context,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Create Account',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.getTextOnPrimary(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: AppColors.getBorder(context),
                            ),
                          ),
                          child: Text(
                            'Log In',
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        AppColors.getBackground(context) == Colors.white
                            ? Colors.grey[100]
                            : Colors.grey[800],
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: AppColors.getTextPrimary(context),
                      size: 20,
                    ),
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showGuidelinesModalIfNeeded() async {
    // Prevent showing multiple times in this session
    if (_guidelinesModalShown) return;

    // Get current user ID for user-specific key check
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return; // Not logged in yet

    final prefs = await SharedPreferences.getInstance();

    // Check user-specific key to see if this user has seen guidelines
    final userSpecificKey = 'dating_pool_guidelines_shown_$userId';
    final hasSeenGuidelines = prefs.getBool(userSpecificKey) ?? false;

    if (hasSeenGuidelines == false) {
      _guidelinesModalShown = true; // Mark as shown for this session

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => DatingPoolGuidelinesModal(
              onDismiss: () {
                // Close modal immediately
                Navigator.of(ctx).pop();

                // Mark guidelines as seen only if widget is still mounted
                // This prevents "ref after dispose" errors
                if (mounted) {
                  ref
                      .read(markGuidelinesSeenProvider.notifier)
                      .markAsRead()
                      .catchError((e) {
                        print('[DatingPoolGuidelines] Dismiss error: $e');
                      });
                }
              },
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPreferences != null;

    // Check dating verification status from Firestore
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final dating = (userDoc?['dating'] as Map?)?.cast<String, dynamic>();
    final verificationStatus = dating?['verificationStatus']?.toString();
    final isVerified = verificationStatus == 'verified';

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
          isEditing ? 'Edit Preferences' : 'Find a Life Partner',
          style: AppTextStyles.headlineLarge,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'State your preferences below',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(context),
                ),
                //),
                //const SizedBox(height: 2),
                //Text(
                // 'Answer a few questions about what you\'re looking for',
                // style: AppTextStyles.bodyMedium.copyWith(
                // color: AppColors.getTextSecondary(context),
                //),
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
                    const SizedBox(width: 0),
                    Expanded(
                      child: RangeSlider(
                        values: RangeValues(
                          _minAge.toDouble(),
                          _maxAge.toDouble(),
                        ),
                        min: 21,
                        max: 70,
                        divisions: 49,
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
                    const SizedBox(width: 0),
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
                    'Would you like to connect with users outside your country of residence?',
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
                title: 'Would you like to connect with users with kids?',
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
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            if (!isVerified) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.hourglass_top_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Your profile is pending admin verification. You\'ll be able to save preferences once approved.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              return;
                            }
                            _savePreferences();
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.getBorder(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textOnPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Finding Matches',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.textOnPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                          : Text(
                            'Save Preferences',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textOnPrimary,
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
                      ? AppColors.textOnPrimary
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
                isSelected
                    ? AppColors.textOnPrimary
                    : AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
