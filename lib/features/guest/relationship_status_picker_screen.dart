import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/session/guest_session_provider.dart';
import '../../safe_imports.dart';

class RelationshipStatusPickerScreen extends ConsumerWidget {
  const RelationshipStatusPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 20,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome',
                style: AppTextStyles.displayLarge.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select your relationship status to continue.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              _OptionButton(
                label: 'Never Married',
                onPressed:
                    () => _selectStatus(
                      context,
                      ref,
                      RelationshipStatus.singleNeverMarried,
                    ),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Married',
                onPressed:
                    () =>
                        _selectStatus(context, ref, RelationshipStatus.married),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Divorced',
                onPressed:
                    () => _selectStatus(
                      context,
                      ref,
                      RelationshipStatus.divorced,
                    ),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Widowed',
                onPressed:
                    () =>
                        _selectStatus(context, ref, RelationshipStatus.widowed),
              ),

              const Spacer(),
              Text(
                'You can explore in guest mode. Some features will require creating an account.',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStatus(
    BuildContext context,
    WidgetRef ref,
    RelationshipStatus status,
  ) async {
    await ref.read(guestSessionProvider.notifier).setRelationshipStatus(status);
    // Status selected, guest entry gate will handle navigation
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _OptionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.surface),
          foregroundColor: WidgetStateProperty.all(AppColors.textPrimary),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return BorderSide(color: AppColors.primary, width: 2);
            }
            return BorderSide(color: AppColors.border, width: 1);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          overlayColor: WidgetStateProperty.all(
            AppColors.primary.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
