import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import '../../application/compatibility_quiz_provider.dart';

class CompatibilityQuizScreen extends ConsumerWidget {
  const CompatibilityQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(compatibilityQuizProvider);
    final notifier = ref.read(compatibilityQuizProvider.notifier);

    final step = state.step;
    final q = _quizSteps[step];
    final selected = state.answers?.valueFor(q.key);

    final canNext = selected != null && selected.trim().isNotEmpty;

    return WillPopScope(
      onWillPop: () async {
        if (step > 0) {
          notifier.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
          titleSpacing: 20,
          title: Text(
            'Compatibility Quiz',
            style: AppTextStyles.headlineLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (step == 0) {
                Navigator.pop(context);
              } else {
                notifier.goBack();
              }
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProgressBar(step: step),
              const SizedBox(height: 24),
              Text(
                'Question ${step + 1} of ${_quizSteps.length}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _QuizStepView(
                    key: ValueKey(step),
                    step: step,
                    selected: selected,
                  ),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  state.error!,
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.red),
                ),
              ],
              const SizedBox(height: 14),
              SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            disabledBackgroundColor: AppColors.border,
                            disabledForegroundColor: AppColors.textMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed:
                              (!canNext || state.isSubmitting)
                                  ? null
                                  : () async {
                                    if (step < _quizSteps.length - 1) {
                                      notifier.goNext();
                                    } else {
                                      await notifier.submit();
                                      if (context.mounted) {
                                        // Route to user's own dating profile after completion
                                        Navigator.of(
                                          context,
                                        ).pushReplacementNamed('/profile');
                                      }
                                    }
                                  },
                          child:
                              state.isSubmitting
                                  ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    step < _quizSteps.length - 1
                                        ? 'Next'
                                        : 'Finish',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizStepView extends ConsumerWidget {
  final int step;
  final String? selected;
  const _QuizStepView({super.key, required this.step, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(compatibilityQuizProvider.notifier);
    final q = _quizSteps[step];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q.title,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final opt in q.options)
                    _OptionButton(
                      text: opt,
                      selected: selected == opt,
                      onTap: () => notifier.setAnswer(q.key, opt),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _OptionButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? AppColors.primary.withOpacity(0.12) : AppColors.surface;
    final border =
        selected ? AppColors.primary : AppColors.border.withOpacity(0.5);
    final txt = selected ? AppColors.primary : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: selected ? 2 : 1),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
          ),
          child: Text(
            text,
            style: AppTextStyles.bodyLarge.copyWith(
              color: txt,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  const _ProgressBar({required this.step});

  @override
  Widget build(BuildContext context) {
    final progress = (step + 1) / _quizSteps.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        backgroundColor: AppColors.surfaceLight,
        valueColor: AlwaysStoppedAnimation(AppColors.primary),
      ),
    );
  }
}

class _QuizStep {
  final String key;
  final String title;
  final List<String> options;
  const _QuizStep({
    required this.key,
    required this.title,
    required this.options,
  });
}

/// NOTE:
/// Q6–Q10 options come directly from your provided code.
/// Q1–Q5 we’ll update once you paste their exact options like you did for Q6–Q10.
const _quizSteps = <_QuizStep>[
  _QuizStep(
    key: 'maritalStatus',
    title: 'What is your Marital Status?',
    options: ['Never Married', 'Divorced', 'Widow/Widower'],
  ),
  _QuizStep(
    key: 'haveKids',
    title: 'Do you have kids?',
    options: ['Yes', 'No'],
  ),
  _QuizStep(
    key: 'genotype',
    title: 'What is your Genotype?',
    options: ['AA', 'AC', 'AS', 'SS'],
  ),
  _QuizStep(
    key: 'personalityType',
    title: 'What is your Personality type?',
    options: ['Ambivert', 'Extrovert', 'Introvert'],
  ),
  _QuizStep(
    key: 'regularSourceOfIncome',
    title: 'Do you have a stable source of income?',
    options: ['Yes', 'No', 'Sometimes'],
  ),
  _QuizStep(
    key: 'marrySomeoneNotFS',
    title: 'Can you date or marry someone who is not yet financially stable?',
    options: [
      'Yes, as long as they are diligent & responsible',
      'No, due to reasons that are important to me',
    ],
  ),
  _QuizStep(
    key: 'longDistance',
    title: 'Are you open to a long distance relationship?',
    options: ['Yes', 'No'],
  ),
  _QuizStep(
    key: 'believeInCohabiting',
    title: 'Do you believe in cohabiting before marriage?',
    options: ['Yes', 'No'],
  ),
  _QuizStep(
    key: 'shouldChristianSpeakInTongue',
    title: 'What are your thoughts on Christians speaking in tongues?',
    options: [
      'It is a very necessary gift for a Christian',
      'I am not against it, but I don´t believe in it',
    ],
  ),
  _QuizStep(
    key: 'believeInTithing',
    title: 'Do you believe in tithing?',
    options: [
      'Yes, I take it seriously',
      'I am not against it, but I don´t believe in it',
    ],
  ),
];
