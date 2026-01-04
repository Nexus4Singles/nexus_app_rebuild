import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );

    final guestSession = ref.watch(guestSessionProvider);
    final isGuest = guestSession != null && !isSignedIn;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Search', style: AppTextStyles.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find a compatible partner',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select your preferences and explore profiles of Christian singles across the world.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),

            // Placeholder section (so screen doesn't feel empty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search filters', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Search filters UI is temporarily paused.\nWe’ll implement the final UX later.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  if (!isSignedIn) {
                    await GuestGuard.requireSignedIn(
                      context,
                      ref,
                      title: 'Create an account to search',
                      message:
                          'You\'re currently in guest mode. Create an account to run a search and view profiles.',
                      primaryText: 'Create an account',
                      onCreateAccount:
                          () => Navigator.of(context).pushNamed('/signup'),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Search coming soon')),
                  );
                },
                child: Text(isGuest ? 'Sign in to Search' : 'Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
