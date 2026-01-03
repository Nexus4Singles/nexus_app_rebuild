import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class NexusCountryPicker {
  static void show({
    required BuildContext context,
    required String title,
    required void Function(String) onPicked,
  }) {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      showWorldWide: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.background,
        textStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        searchTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        inputDecoration: InputDecoration(
          hintText: 'Search $title',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      onSelect: (Country c) => onPicked(c.name),
    );
  }
}
