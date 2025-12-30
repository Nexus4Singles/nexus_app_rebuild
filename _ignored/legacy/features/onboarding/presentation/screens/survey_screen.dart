import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/user_provider.dart';

// ============================================================================
// SURVEY STATE
// ============================================================================

enum SurveyStep { relationshipStatus, gender, goals }

class SurveyState {
  final SurveyStep currentStep;
  final RelationshipStatus? relationshipStatus;
  final Gender? gender;
  final List<UserGoal> selectedGoals;
  final bool isSubmitting;
  final String? error;

  const SurveyState({
    this.currentStep = SurveyStep.relationshipStatus,
    this.relationshipStatus,
    this.gender,
    this.selectedGoals = const [],
    this.isSubmitting = false,
    this.error,
  });

  SurveyState copyWith({
    SurveyStep? currentStep,
    RelationshipStatus? relationshipStatus,
    Gender? gender,
    List<UserGoal>? selectedGoals,
    bool? isSubmitting,
    String? error,
  }) {
    return SurveyState(
      currentStep: currentStep ?? this.currentStep,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      gender: gender ?? this.gender,
      selectedGoals: selectedGoals ?? this.selectedGoals,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  int get stepIndex => SurveyStep.values.indexOf(currentStep);
  int get totalSteps => SurveyStep.values.length;
  double get progress => (stepIndex + 1) / totalSteps;

  bool get canProceed {
    switch (currentStep) {
      case SurveyStep.relationshipStatus:
        return relationshipStatus != null;
      case SurveyStep.gender:
        return gender != null;
      case SurveyStep.goals:
        return selectedGoals.isNotEmpty;
    }
  }

  bool get canGoBack => stepIndex > 0;
}

class SurveyNotifier extends StateNotifier<SurveyState> {
  final Ref _ref;

  SurveyNotifier(this._ref) : super(const SurveyState());

  void setRelationshipStatus(RelationshipStatus status) {
    HapticFeedback.lightImpact();
    final clearGoals = state.relationshipStatus != null && state.relationshipStatus != status;
    state = state.copyWith(
      relationshipStatus: status,
      selectedGoals: clearGoals ? [] : null,
    );
  }

  void setGender(Gender gender) {
    HapticFeedback.lightImpact();
    state = state.copyWith(gender: gender);
  }

  void toggleGoal(UserGoal goal) {
    HapticFeedback.lightImpact();
    final currentGoals = List<UserGoal>.from(state.selectedGoals);
    if (currentGoals.contains(goal)) {
      currentGoals.remove(goal);
    } else if (currentGoals.length < 3) {
      currentGoals.add(goal);
    }
    state = state.copyWith(selectedGoals: currentGoals);
  }

  void nextStep() {
    if (!state.canProceed) return;
    HapticFeedback.mediumImpact();
    final nextIndex = state.stepIndex + 1;
    if (nextIndex < SurveyStep.values.length) {
      state = state.copyWith(currentStep: SurveyStep.values[nextIndex]);
    }
  }

  void previousStep() {
    if (!state.canGoBack) return;
    final prevIndex = state.stepIndex - 1;
    if (prevIndex >= 0) {
      state = state.copyWith(currentStep: SurveyStep.values[prevIndex]);
    }
  }

  Future<bool> submit() async {
    if (!state.canProceed || state.relationshipStatus == null || state.gender == null) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      await _ref.read(userNotifierProvider.notifier).completeOnboarding(
        relationshipStatus: state.relationshipStatus!,
        gender: state.gender!,
        primaryGoals: state.selectedGoals,
      );
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'Failed to save: $e');
      return false;
    }
  }
}

final surveyProvider = StateNotifierProvider<SurveyNotifier, SurveyState>((ref) {
  return SurveyNotifier(ref);
});

// ============================================================================
// PREMIUM SURVEY SCREEN
// ============================================================================

class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _resetAnimation() {
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(surveyProvider);
    final notifier = ref.read(surveyProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.secondary.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(context, state, notifier),

                // Step Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: _buildStepContent(state, notifier),
                    ),
                  ),
                ),

                // Footer
                _buildFooter(context, state, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SurveyState state, SurveyNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          // Top row
          Row(
            children: [
              if (state.canGoBack)
                GestureDetector(
                  onTap: () {
                    notifier.previousStep();
                    _resetAnimation();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
                  ),
                )
              else
                const SizedBox(width: 44),
              Expanded(
                child: Text(
                  'Step ${state.stepIndex + 1} of ${state.totalSteps}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 20),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(3),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * state.progress,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(SurveyState state, SurveyNotifier notifier) {
    switch (state.currentStep) {
      case SurveyStep.relationshipStatus:
        return _RelationshipStep(
          selected: state.relationshipStatus,
          onSelect: (status) {
            notifier.setRelationshipStatus(status);
          },
        );
      case SurveyStep.gender:
        return _GenderStep(
          selected: state.gender,
          onSelect: notifier.setGender,
        );
      case SurveyStep.goals:
        return _GoalsStep(
          relationshipStatus: state.relationshipStatus!,
          selectedGoals: state.selectedGoals,
          onToggle: notifier.toggleGoal,
        );
    }
  }

  Widget _buildFooter(BuildContext context, SurveyState state, SurveyNotifier notifier) {
    final isLastStep = state.currentStep == SurveyStep.goals;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: state.canProceed
            ? () async {
                if (isLastStep) {
                  final success = await notifier.submit();
                  if (success && context.mounted) {
                    context.go(AppRoutes.home);
                  }
                } else {
                  notifier.nextStep();
                  _resetAnimation();
                }
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: state.canProceed ? AppColors.primaryGradient : null,
            color: state.canProceed ? null : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            boxShadow: state.canProceed
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
                : null,
          ),
          child: Center(
            child: state.isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLastStep ? 'Get Started' : 'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: state.canProceed ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLastStep ? Icons.check : Icons.arrow_forward,
                        size: 20,
                        color: state.canProceed ? Colors.white : AppColors.textMuted,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STEP 1: RELATIONSHIP STATUS
// ============================================================================

class _RelationshipStep extends StatelessWidget {
  final RelationshipStatus? selected;
  final ValueChanged<RelationshipStatus> onSelect;

  const _RelationshipStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = [
      _StatusOption(
        status: RelationshipStatus.singleNeverMarried,
        emoji: '💍',
        title: 'Single',
        subtitle: 'Never been married, preparing for a godly relationship',
      ),
      _StatusOption(
        status: RelationshipStatus.divorcedWidowed,
        emoji: '🌱',
        title: 'Divorced / Widowed',
        subtitle: 'Ready for a fresh start and new beginning',
      ),
      _StatusOption(
        status: RelationshipStatus.married,
        emoji: '❤️',
        title: 'Married',
        subtitle: 'Looking to strengthen and enrich my marriage',
      ),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What\'s your\nrelationship status?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            'This helps us personalize your journey.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 36),
          ...options.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SelectionCard(
                  emoji: opt.emoji,
                  title: opt.title,
                  subtitle: opt.subtitle,
                  isSelected: selected == opt.status,
                  onTap: () => onSelect(opt.status),
                ),
              )),
        ],
      ),
    );
  }
}

class _StatusOption {
  final RelationshipStatus status;
  final String emoji;
  final String title;
  final String subtitle;

  _StatusOption({required this.status, required this.emoji, required this.title, required this.subtitle});
}

// ============================================================================
// STEP 2: GENDER
// ============================================================================

class _GenderStep extends StatelessWidget {
  final Gender? selected;
  final ValueChanged<Gender> onSelect;

  const _GenderStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What\'s your gender?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            'This helps us show you relevant content.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  emoji: '👨',
                  label: 'Male',
                  isSelected: selected == Gender.male,
                  onTap: () => onSelect(Gender.male),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GenderCard(
                  emoji: '👩',
                  label: 'Female',
                  isSelected: selected == Gender.female,
                  onTap: () => onSelect(Gender.female),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({required this.emoji, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STEP 3: GOALS
// ============================================================================

class _GoalsStep extends StatelessWidget {
  final RelationshipStatus relationshipStatus;
  final List<UserGoal> selectedGoals;
  final ValueChanged<UserGoal> onToggle;

  const _GoalsStep({required this.relationshipStatus, required this.selectedGoals, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final goals = _getGoalsForStatus(relationshipStatus);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What are your goals?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            'Select up to 3 that resonate with you.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Selection counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${selectedGoals.length} of 3 selected',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ...goals.map((goal) {
            final isSelected = selectedGoals.contains(goal.value);
            final canSelect = isSelected || selectedGoals.length < 3;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalCard(
                emoji: goal.emoji,
                title: goal.title,
                subtitle: goal.subtitle,
                isSelected: isSelected,
                enabled: canSelect,
                onTap: () => onToggle(goal.value),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<_GoalOption> _getGoalsForStatus(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return [
          _GoalOption(value: UserGoal.findPartner, emoji: '💑', title: 'Find a Life Partner', subtitle: 'Meet someone who shares my faith and values'),
          _GoalOption(value: UserGoal.developEmotionally, emoji: '🧠', title: 'Develop Emotionally', subtitle: 'Build emotional intelligence and maturity'),
          _GoalOption(value: UserGoal.strengthenFaith, emoji: '🙏', title: 'Strengthen My Faith', subtitle: 'Grow deeper in my relationship with God'),
          _GoalOption(value: UserGoal.buildCommunity, emoji: '👥', title: 'Build Community', subtitle: 'Connect with like-minded believers'),
          _GoalOption(value: UserGoal.prepareForMarriage, emoji: '💍', title: 'Prepare for Marriage', subtitle: 'Learn what it takes to build a lasting union'),
        ];
      case RelationshipStatus.divorcedWidowed:
        return [
          _GoalOption(value: UserGoal.healAndRecover, emoji: '💚', title: 'Heal & Recover', subtitle: 'Process past hurts and find wholeness'),
          _GoalOption(value: UserGoal.findPartner, emoji: '💑', title: 'Find a Life Partner', subtitle: 'When ready, meet someone special'),
          _GoalOption(value: UserGoal.coParentWell, emoji: '👨‍👩‍👧', title: 'Co-Parent Well', subtitle: 'Navigate parenting after separation'),
          _GoalOption(value: UserGoal.strengthenFaith, emoji: '🙏', title: 'Strengthen My Faith', subtitle: 'Lean on God through this season'),
          _GoalOption(value: UserGoal.buildCommunity, emoji: '👥', title: 'Build Community', subtitle: 'Find support and encouragement'),
        ];
      case RelationshipStatus.married:
        return [
          _GoalOption(value: UserGoal.strengthenMarriage, emoji: '❤️', title: 'Strengthen Our Bond', subtitle: 'Deepen intimacy and connection'),
          _GoalOption(value: UserGoal.improveCommunication, emoji: '💬', title: 'Improve Communication', subtitle: 'Learn to understand each other better'),
          _GoalOption(value: UserGoal.parentTogether, emoji: '👨‍👩‍👧', title: 'Parent Together', subtitle: 'Align on raising godly children'),
          _GoalOption(value: UserGoal.manageFinances, emoji: '💰', title: 'Manage Finances', subtitle: 'Build financial unity and wisdom'),
          _GoalOption(value: UserGoal.growSpiritually, emoji: '🙏', title: 'Grow Spiritually Together', subtitle: 'Build a Christ-centered home'),
        ];
    }
  }
}

class _GoalOption {
  final UserGoal value;
  final String emoji;
  final String title;
  final String subtitle;

  _GoalOption({required this.value, required this.emoji, required this.title, required this.subtitle});
}

class _GoalCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _GoalCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED SELECTION CARD
// ============================================================================

class _SelectionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
