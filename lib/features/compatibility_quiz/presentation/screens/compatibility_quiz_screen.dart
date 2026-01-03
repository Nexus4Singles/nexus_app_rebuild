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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Compatibility Quiz', style: AppTextStyles.headlineLarge),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProgressBar(step: step),
            const SizedBox(height: 18),
            Text(
              'Question ${step + 1} of ${_quizSteps.length}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _QuizStepView(
                key: ValueKey(step),
                step: step,
                selected: selected,
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
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            (!canNext || state.isSubmitting)
                                ? null
                                : () async {
                                  if (step < _quizSteps.length - 1) {
                                    notifier.goNext();
                                  } else {
                                    await notifier.submit();
                                    if (context.mounted) Navigator.pop(context);
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
        Text(q.title, style: AppTextStyles.titleLarge),
        const SizedBox(height: 18),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: Wrap(
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
    final border = selected ? AppColors.primary : AppColors.border;
    final txt = selected ? AppColors.primary : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: txt,
              fontWeight: FontWeight.w600,
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
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: AppColors.border.withOpacity(0.4),
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
