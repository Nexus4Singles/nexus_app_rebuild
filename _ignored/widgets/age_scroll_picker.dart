import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Scroll-based age picker (wheel picker style like Nexus 1.0)
/// Uses CupertinoPicker-style scrolling for smooth age selection
class AgeScrollPicker extends StatefulWidget {
  final int? initialAge;
  final int minAge;
  final int maxAge;
  final ValueChanged<int> onAgeChanged;

  const AgeScrollPicker({
    super.key,
    this.initialAge,
    this.minAge = 21, // Minimum dating age is 21
    this.maxAge = 70,
    required this.onAgeChanged,
  });

  @override
  State<AgeScrollPicker> createState() => _AgeScrollPickerState();
}

class _AgeScrollPickerState extends State<AgeScrollPicker> {
  late FixedExtentScrollController _scrollController;
  late int _selectedAge;

  @override
  void initState() {
    super.initState();
    _selectedAge = widget.initialAge ?? 25;
    // Clamp to valid range
    _selectedAge = _selectedAge.clamp(widget.minAge, widget.maxAge);
    
    final initialIndex = _selectedAge - widget.minAge;
    _scrollController = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.maxAge - widget.minAge + 1;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Selection highlight
          Center(
            child: Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
          ),

          // Wheel picker
          ListWheelScrollView.useDelegate(
            controller: _scrollController,
            itemExtent: 50,
            perspective: 0.005,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedAge = widget.minAge + index;
              });
              widget.onAgeChanged(_selectedAge);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) {
                final age = widget.minAge + index;
                final isSelected = age == _selectedAge;

                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: isSelected ? 28 : 20,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected 
                          ? AppColors.primary 
                          : AppColors.textSecondary.withOpacity(0.6),
                    ),
                    child: Text('$age'),
                  ),
                );
              },
            ),
          ),

          // Top fade gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface,
                    AppColors.surface.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          // Bottom fade gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.surface,
                    AppColors.surface.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Age picker form field with label
/// Tapping opens a bottom sheet with scroll picker
class AgePickerField extends StatelessWidget {
  final String label;
  final int? value;
  final String hint;
  final int minAge;
  final int maxAge;
  final ValueChanged<int> onChanged;
  final bool isRequired;

  const AgePickerField({
    super.key,
    required this.label,
    this.value,
    required this.hint,
    this.minAge = 21, // Minimum dating age is 21
    this.maxAge = 70,
    required this.onChanged,
    this.isRequired = false,
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
          onTap: () => _showAgePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue 
                    ? AppColors.primary.withOpacity(0.3) 
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cake_outlined,
                  size: 20,
                  color: hasValue ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? '$value years old' : hint,
                    style: TextStyle(
                      fontSize: 15,
                      color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                    ),
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
      ],
    );
  }

  void _showAgePicker(BuildContext context) {
    HapticFeedback.lightImpact();
    int selectedAge = value ?? 25;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Your Age',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onChanged(selectedAge);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Age wheel picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AgeScrollPicker(
                initialAge: value,
                minAge: minAge,
                maxAge: maxAge,
                onAgeChanged: (age) {
                  selectedAge = age;
                },
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }
}

/// Inline age scroll picker for direct embedding in forms
/// Shows the wheel picker directly without bottom sheet
class InlineAgeScrollPicker extends StatelessWidget {
  final String label;
  final int? value;
  final int minAge;
  final int maxAge;
  final ValueChanged<int> onChanged;
  final bool isRequired;

  const InlineAgeScrollPicker({
    super.key,
    required this.label,
    this.value,
    this.minAge = 21, // Minimum dating age is 21
    this.maxAge = 70,
    required this.onChanged,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 12),

        // Wheel picker
        AgeScrollPicker(
          initialAge: value,
          minAge: minAge,
          maxAge: maxAge,
          onAgeChanged: onChanged,
        ),

        // Selected age display
        if (value != null) ...[
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$value years old',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
