import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/user/current_user_doc_provider.dart';
import '../../guest/guest_entry_gate.dart';
import '../../../core/bootstrap/bootstrap_gate.dart';
import '../../presurvey/presentation/splash/presurvey_splash_screen.dart';

class AppLaunchGate extends ConsumerWidget {
  const AppLaunchGate({super.key});

  bool _hasNonEmptyField(Map<String, dynamic>? doc, List<String> keys) {
    if (doc == null) return false;
    for (final k in keys) {
      final v = doc[k];
      if (v != null && v.toString().trim().isNotEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      data: (user) {
        // Not signed in → start presurvey splash (new user flow).
        if (user == null) {
          return const PresurveySplashScreen();
        }

        // Signed in → require onboarding-critical fields that tailor the experience.
        final userDocAsync = ref.watch(currentUserDocProvider);

        return userDocAsync.when(
          data: (doc) {
            final hasGender = _hasNonEmptyField(doc, const ['gender']);

            final nexus = (doc?['nexus'] as Map?)?.cast<String, dynamic>();
            final nexus2 = (doc?['nexus2'] as Map?)?.cast<String, dynamic>();
            final relationshipStatus =
                (nexus?['relationshipStatus'] ?? nexus2?['relationshipStatus']);

            final hasRelationshipStatus =
                relationshipStatus != null &&
                relationshipStatus.toString().trim().isNotEmpty;

            if (hasGender && hasRelationshipStatus) {
              return const GuestEntryGate(child: BootstrapGate());
            }

            // Signed-in but missing required onboarding fields → take them to presurvey.
            return const PresurveySplashScreen();
          },
          loading:
              () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
          // Best practice: don't block signed-in users on transient Firestore errors.
          // Let them into the app and handle prompts/retry inside.
          error: (_, __) => const GuestEntryGate(child: BootstrapGate()),
        );
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const PresurveySplashScreen(),
    );
  }
}
