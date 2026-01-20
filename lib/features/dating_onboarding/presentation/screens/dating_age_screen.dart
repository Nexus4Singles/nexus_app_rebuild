import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../application/dating_onboarding_provider.dart';

class DatingAgeScreen extends ConsumerStatefulWidget {
  const DatingAgeScreen({super.key});

  @override
  ConsumerState<DatingAgeScreen> createState() => _DatingAgeScreenState();
}

class _DatingAgeScreenState extends ConsumerState<DatingAgeScreen> {
  static const int _minAge = 21;
  static const int _maxAge = 70;

  late FixedExtentScrollController _controller;
  int _selectedAge = 21;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(datingOnboardingProvider);
    _selectedAge = (draft.age ?? _minAge).clamp(_minAge, _maxAge);
    _controller = FixedExtentScrollController(
      initialItem: _selectedAge - _minAge,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    ref.read(datingOnboardingProvider.notifier).setAge(_selectedAge);
    Navigator.pushNamed(context, '/dating/onboarding/extra-info');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: Text('Step 1 of 8', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How old are you?', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 10),
              Text(
                'Nexus is for users between the ages of 21 to 70 years',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Container(
                    height: 280,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ListWheelScrollView.useDelegate(
                          controller: _controller,
                          itemExtent: 52,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) {
                            setState(() => _selectedAge = _minAge + i);
                          },
                          perspective: 0.003,
                          diameterRatio: 1.5,
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (_, i) {
                              final age = _minAge + i;
                              final selected = age == _selectedAge;
                              return Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 180),
                                  style:
                                      selected
                                          ? AppTextStyles.headlineMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              )
                                          : AppTextStyles.titleLarge.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                  child: Text('$age'),
                                ),
                              );
                            },
                            childCount: (_maxAge - _minAge) + 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
