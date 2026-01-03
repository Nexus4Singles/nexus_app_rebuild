import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/user/current_user_doc_provider.dart';
import '../../guest/guest_entry_gate.dart';
import '../../../core/bootstrap/bootstrap_gate.dart';
import '../../presurvey/presentation/splash/presurvey_splash_screen.dart';

class AppLaunchGate extends ConsumerWidget {
  const AppLaunchGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      data: (user) {
        // If not signed in, start presurvey splash.
        if (user == null) {
          return const PresurveySplashScreen();
        }

        // Signed in user: check if they already have gender (v1 users / completed v2 profile).
        final userDocAsync = ref.watch(currentUserDocProvider);

        return userDocAsync.when(
          data: (doc) {
            final gender = doc?['gender'];
            if (gender != null && gender.toString().trim().isNotEmpty) {
              return const GuestEntryGate(child: BootstrapGate());
            }
            // Signed-in but no gender → show presurvey.
            return const PresurveySplashScreen();
          },
          loading:
              () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
          error: (_, __) => const PresurveySplashScreen(),
        );
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const PresurveySplashScreen(),
    );
  }
}
