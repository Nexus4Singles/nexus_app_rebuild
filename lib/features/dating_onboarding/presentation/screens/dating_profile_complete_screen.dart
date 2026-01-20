import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/data/compatibility_quiz_service.dart';

class DatingProfileCompleteScreen extends ConsumerStatefulWidget {
  const DatingProfileCompleteScreen({super.key});

  @override
  ConsumerState<DatingProfileCompleteScreen> createState() =>
      _DatingProfileCompleteScreenState();
}

class _DatingProfileCompleteScreenState
    extends ConsumerState<DatingProfileCompleteScreen> {
  bool _checked = false;
  bool _quizComplete = false;

  @override
  void initState() {
    super.initState();
    // Defer to after first frame so Navigator is safe.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkQuiz());
  }

  Future<void> _checkQuiz() async {
    if (_checked) return;
    _checked = true;

    final authAsync = ref.read(authStateProvider);
    final uid = authAsync.maybeWhen(
      data: (a) => a.user?.uid,
      orElse: () => null,
    );

    if (uid == null || uid.isEmpty) {
      // If not signed in, we can't verify quiz status. Keep the screen but do not lock the user.
      if (mounted) setState(() => _quizComplete = true);
      return;
    }

    final svc = ref.read(compatibilityQuizServiceProvider);
    bool ok = false;
    try {
      ok = await svc.isQuizComplete(uid);
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    setState(() => _quizComplete = ok);

    // If quiz already done, NEVER keep prompting: leave immediately.
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/profile', (r) => false);
    }
  }

  void _goToQuiz() {
    Navigator.of(context).pushReplacementNamed('/compatibility-quiz');
  }

  @override
  Widget build(BuildContext context) {
    // While checking, assume incomplete (locks are safer) ONLY for signed-in users.
    final authAsync = ref.watch(authStateProvider);
    final signedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );

    final isLocked = signedIn && !_quizComplete;

    return PopScope(
      canPop: !isLocked,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed:
                isLocked
                    ? null
                    : () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
          title: Text('Dating Profile', style: AppTextStyles.titleLarge),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 8 of 8', style: AppTextStyles.caption),
              const SizedBox(height: 10),
              Text('Profile completed 🎉', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  isLocked
                      ? 'Before you can view other users in the pool, please take a short compatibility quiz. '
                          'This helps Nexus recommend better matches and improves the quality of the community.'
                      : 'Your profile is complete. You’re all set!',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      isLocked
                          ? _goToQuiz
                          : () {
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/profile', (r) => false);
                          },
                  child: Text(
                    isLocked ? 'Take Compatibility Quiz' : 'Continue',
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
