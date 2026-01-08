import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/providers/assessment_provider.dart';

class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  late final PageController _page;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _page = PageController();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _startIfNeeded() {
    if (_started) return;
    _started = true;
    final type =
        ref.read(recommendedAssessmentTypeProvider) ??
        AssessmentType.singlesReadiness;
    ref.read(assessmentNotifierProvider.notifier).startAssessment(type);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assessmentNotifierProvider);
    final notifier = ref.read(assessmentNotifierProvider.notifier);

    _startIfNeeded();

    if (state.result != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoutes.assessmentResult);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child:
            state.config == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    _TopProgress(
                      index: state.currentQuestionIndex,
                      total: state.totalQuestions,
                      onExit: () => _confirmExit(context, notifier),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _page,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.totalQuestions,
                        itemBuilder: (_, i) {
                          final q = state.config!.questions[i];
                          final selected = state.answers[i]?.selectedOptionId;

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q.text,
                                  style: AppTextStyles.headlineSmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ListView(
                                    children:
                                        q.options.map((o) {
                                          final isSelected = selected == o.id;
                                          return _OptionTile(
                                            title: o.text,
                                            isSelected: isSelected,
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              notifier.answerQuestion(o.id);
                                              setState(() {});
                                            },
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    _BottomNav(
                      canBack: state.canGoBack,
                      canNext:
                          state.currentQuestionAnswered && !state.isSubmitting,
                      isSubmitting: state.isSubmitting,
                      isLast: !state.canGoNext,
                      onBack: () {
                        notifier.previousQuestion();
                        _page.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                      onNext: () {
                        if (!state.currentQuestionAnswered) return;
                        if (state.canGoNext) {
                          notifier.nextQuestion();
                          _page.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        } else {
                          notifier.submitAssessment();
                        }
                      },
                    ),
                  ],
                ),
      ),
    );
  }

  Future<void> _confirmExit(
    BuildContext context,
    AssessmentNotifier notifier,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Exit assessment?'),
            content: const Text('Your progress will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (ok == true && mounted) {
      notifier.reset();
      Navigator.pop(context);
    }
  }
}

class _TopProgress extends StatelessWidget {
  final int index;
  final int total;
  final VoidCallback onExit;

  const _TopProgress({
    required this.index,
    required this.total,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (index + 1) / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Question ${index + 1} of $total',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceDark,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 1.2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          title,
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing:
            isSelected
                ? Icon(Icons.check_circle, color: AppColors.primary)
                : Icon(Icons.circle_outlined, color: AppColors.textMuted),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final bool canBack;
  final bool canNext;
  final bool isLast;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNav({
    required this.canBack,
    required this.canNext,
    required this.isLast,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canBack ? onBack : null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: canNext ? onNext : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(
                  isSubmitting ? "Submitting..." : (isLast ? "Finish" : "Next"),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
