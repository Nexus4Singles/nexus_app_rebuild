import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import '../theme/app_colors.dart';

/// Country data model for storage
class CountrySelection {
  final String name;
  final String code; // ISO-2 code (e.g., "NG", "US")
  final String dialCode;
  final String flagEmoji;

  const CountrySelection({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flagEmoji,
  });

  factory CountrySelection.fromCountry(Country country) {
    return CountrySelection(
      name: country.name,
      code: country.countryCode,
      dialCode: '+${country.phoneCode}',
      flagEmoji: country.flagEmoji,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'code': code,
    'dialCode': dialCode,
    'flagEmoji': flagEmoji,
  };

  factory CountrySelection.fromJson(Map<String, dynamic> json) {
    return CountrySelection(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      dialCode: json['dialCode'] as String? ?? '',
      flagEmoji: json['flagEmoji'] as String? ?? '',
    );
  }

  @override
  String toString() => '$flagEmoji $name';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountrySelection &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Country picker form field with premium styling
class CountryPickerField extends StatelessWidget {
  final String label;
  final CountrySelection? value;
  final String hint;
  final ValueChanged<CountrySelection> onChanged;
  final bool isRequired;
  final bool showDialCode;
  final List<String>? favoriteCountries;
  final List<String>? excludedCountries;

  const CountryPickerField({
    super.key,
    required this.label,
    this.value,
    required this.hint,
    required this.onChanged,
    this.isRequired = false,
    this.showDialCode = false,
    this.favoriteCountries,
    this.excludedCountries,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Field
        GestureDetector(
          onTap: () => _showCountryPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue ? AppColors.primary.withOpacity(0.3) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                // Flag emoji or globe icon
                if (hasValue) ...[
                  Text(
                    value!.flagEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Icon(
                    Icons.public,
                    size: 24,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                ],

                // Country name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasValue ? value!.name : hint,
                        style: TextStyle(
                          fontSize: 15,
                          color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasValue && showDialCode)
                        Text(
                          value!.dialCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCountryPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    
    showCountryPicker(
      context: context,
      showPhoneCode: showDialCode,
      showWorldWide: false,
      showSearch: true,
      useSafeArea: true,
      favorite: favoriteCountries ?? ['NG', 'US', 'GB', 'CA', 'GH'],
      exclude: excludedCountries,
      countryListTheme: CountryListThemeData(
        backgroundColor: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
        textStyle: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        searchTextStyle: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        inputDecoration: InputDecoration(
          hintText: 'Search country...',
          hintStyle: TextStyle(color: AppColors.textMuted),
          prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      onSelect: (Country country) {
        onChanged(CountrySelection.fromCountry(country));
      },
    );
  }
}

/// Shows a country picker dialog and returns the selection
Future<CountrySelection?> showCountryPickerDialog({
  required BuildContext context,
  CountrySelection? initialValue,
  bool showDialCode = false,
  List<String>? favoriteCountries,
  List<String>? excludedCountries,
}) async {
  CountrySelection? result;

  showCountryPicker(
    context: context,
    showPhoneCode: showDialCode,
    showWorldWide: false,
    showSearch: true,
    useSafeArea: true,
    favorite: favoriteCountries ?? ['NG', 'US', 'GB', 'CA', 'GH'],
    exclude: excludedCountries,
    countryListTheme: CountryListThemeData(
      backgroundColor: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
      textStyle: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      searchTextStyle: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      inputDecoration: InputDecoration(
        hintText: 'Search country...',
        hintStyle: TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    onSelect: (Country country) {
      result = CountrySelection.fromCountry(country);
    },
  );

  // Need to wait for dialog to close
  await Future.delayed(const Duration(milliseconds: 100));
  return result;
}

/// Common country codes for quick access
class CommonCountries {
  static const nigeria = CountrySelection(
    name: 'Nigeria',
    code: 'NG',
    dialCode: '+234',
    flagEmoji: '🇳🇬',
  );

  static const unitedStates = CountrySelection(
    name: 'United States',
    code: 'US',
    dialCode: '+1',
    flagEmoji: '🇺🇸',
  );

  static const unitedKingdom = CountrySelection(
    name: 'United Kingdom',
    code: 'GB',
    dialCode: '+44',
    flagEmoji: '🇬🇧',
  );

  static const canada = CountrySelection(
    name: 'Canada',
    code: 'CA',
    dialCode: '+1',
    flagEmoji: '🇨🇦',
  );

  static const ghana = CountrySelection(
    name: 'Ghana',
    code: 'GH',
    dialCode: '+233',
    flagEmoji: '🇬🇭',
  );

  static const southAfrica = CountrySelection(
    name: 'South Africa',
    code: 'ZA',
    dialCode: '+27',
    flagEmoji: '🇿🇦',
  );

  /// List of popular countries for Nigerian diaspora
  static const List<CountrySelection> popularCountries = [
    nigeria,
    unitedStates,
    unitedKingdom,
    canada,
    ghana,
    southAfrica,
  ];

  /// Get country by code
  static CountrySelection? getByCode(String code) {
    try {
      return popularCountries.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }
}
