import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'searchable_picker.dart';

/// Church picker form field with "Other" text field support
/// When user selects "Other", a text field appears for manual entry
class ChurchPickerField extends StatefulWidget {
  final String label;
  final String? value;
  final String? customValue; // For "Other" manual entry
  final String hint;
  final List<String> churches;
  final ValueChanged<String> onChurchSelected;
  final ValueChanged<String?>? onCustomChurchChanged;
  final bool isRequired;

  const ChurchPickerField({
    super.key,
    required this.label,
    this.value,
    this.customValue,
    required this.hint,
    required this.churches,
    required this.onChurchSelected,
    this.onCustomChurchChanged,
    this.isRequired = false,
  });

  @override
  State<ChurchPickerField> createState() => _ChurchPickerFieldState();
}

class _ChurchPickerFieldState extends State<ChurchPickerField> {
  late TextEditingController _customController;
  bool get _isOtherSelected => widget.value?.toLowerCase() == 'other';

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.customValue);
  }

  @override
  void didUpdateWidget(ChurchPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customValue != oldWidget.customValue) {
      _customController.text = widget.customValue ?? '';
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  /// Get the display value (church name or custom entry)
  String get _displayValue {
    if (_isOtherSelected && widget.customValue?.isNotEmpty == true) {
      return widget.customValue!;
    }
    return widget.value ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.isRequired)
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

        // Church picker field
        GestureDetector(
          onTap: _showChurchPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.value != null 
                    ? AppColors.primary.withOpacity(0.3) 
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.church,
                  size: 20,
                  color: widget.value != null 
                      ? AppColors.primary 
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _displayValue.isNotEmpty ? _displayValue : widget.hint,
                    style: TextStyle(
                      fontSize: 15,
                      color: _displayValue.isNotEmpty 
                          ? AppColors.textPrimary 
                          : AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),

        // "Other" text field (appears when "Other" is selected)
        if (_isOtherSelected) ...[
          const SizedBox(height: 12),
          _buildCustomChurchField(),
        ],
      ],
    );
  }

  Widget _buildCustomChurchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.customValue?.isNotEmpty == true
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: TextField(
        controller: _customController,
        onChanged: (value) {
          widget.onCustomChurchChanged?.call(value);
        },
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Enter your church name',
          hintStyle: TextStyle(color: AppColors.textMuted),
          prefixIcon: Icon(
            Icons.edit,
            size: 20,
            color: AppColors.primary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  void _showChurchPicker() async {
    HapticFeedback.lightImpact();
    
    final result = await showSearchablePicker(
      context: context,
      title: 'Select Church',
      items: widget.churches,
      selectedItem: widget.value,
      alphabeticalGrouping: true,
    );

    if (result != null) {
      widget.onChurchSelected(result);
      
      // Clear custom value if not "Other"
      if (result.toLowerCase() != 'other') {
        widget.onCustomChurchChanged?.call(null);
      }
    }
  }
}

/// Helper to get the final church value (handles "Other" + custom)
/// Use this when saving to database
String getChurchValue({
  required String? selectedChurch,
  required String? customChurch,
}) {
  if (selectedChurch?.toLowerCase() == 'other' && 
      customChurch?.isNotEmpty == true) {
    return customChurch!;
  }
  return selectedChurch ?? '';
}

/// Helper to determine if "Other" was selected
bool isOtherChurchSelected(String? church) {
  return church?.toLowerCase() == 'other';
}

/// Stateful wrapper for church selection with "Other" support
class ChurchSelectionState {
  String? selectedChurch;
  String? customChurch;

  ChurchSelectionState({
    this.selectedChurch,
    this.customChurch,
  });

  /// Get the final church value to save
  String get finalValue => getChurchValue(
    selectedChurch: selectedChurch,
    customChurch: customChurch,
  );

  /// Check if a valid church is selected
  bool get isValid {
    if (selectedChurch == null || selectedChurch!.isEmpty) return false;
    if (selectedChurch!.toLowerCase() == 'other') {
      return customChurch?.isNotEmpty == true;
    }
    return true;
  }

  /// Initialize from stored value
  /// If the stored value is not in the standard list, it's a custom entry
  factory ChurchSelectionState.fromStoredValue(
    String? storedValue,
    List<String> standardChurches,
  ) {
    if (storedValue == null || storedValue.isEmpty) {
      return ChurchSelectionState();
    }

    // Check if stored value is in standard list (case-insensitive)
    final isStandard = standardChurches.any(
      (c) => c.toLowerCase() == storedValue.toLowerCase()
    );

    if (isStandard) {
      // Find the exact match from standard list
      final match = standardChurches.firstWhere(
        (c) => c.toLowerCase() == storedValue.toLowerCase(),
        orElse: () => storedValue,
      );
      return ChurchSelectionState(selectedChurch: match);
    } else {
      // It's a custom church
      return ChurchSelectionState(
        selectedChurch: 'Other',
        customChurch: storedValue,
      );
    }
  }
}
