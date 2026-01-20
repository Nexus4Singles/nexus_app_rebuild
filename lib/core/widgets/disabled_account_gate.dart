import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/user/current_user_disabled_provider.dart';

/// Wrap any screen with this gate to block usage for disabled accounts.
///
/// - It reads from Firestore via currentUserDocProvider (stream-hardened).
/// - It shows a clear, consistent UI.
class DisabledAccountGate extends ConsumerWidget {
  final Widget child;

  /// Optional override message for special contexts.
  final String? message;

  const DisabledAccountGate({super.key, required this.child, this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabledAsync = ref.watch(currentUserDisabledProvider);

    return disabledAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => child, // fail-open to avoid bricking the app
      data: (isDisabled) {
        if (!isDisabled) return child;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block_rounded, size: 54),
                      const SizedBox(height: 16),
                      Text(
                        'Account disabled',
                        style: AppTextStyles.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message ?? 'Your account has been disabled by Admin.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      _SupportHint(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SupportHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'If you believe this is a mistake, please contact support.',
              style: AppTextStyles.bodyMedium.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
