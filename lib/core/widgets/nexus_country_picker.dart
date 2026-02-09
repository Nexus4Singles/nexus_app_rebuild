import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

class NexusCountryPicker {
  static void show({
    required BuildContext context,
    required String title,
    required void Function(String) onPicked,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode ? AppColors.border : Color(0xFFD1D5DB);

    showCountryPicker(
      context: context,
      showPhoneCode: false,
      showWorldWide: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.getBackground(context),
        textStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.getTextPrimary(context),
        ),
        searchTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.getTextPrimary(context),
        ),
        inputDecoration: InputDecoration(
          hintText: 'Search $title',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
          filled: true,
          fillColor: AppColors.getSurface(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      onSelect: (Country c) => onPicked(c.name),
    );
  }
}
