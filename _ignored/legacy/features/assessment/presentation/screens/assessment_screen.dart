import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/models/assessment_model.dart';

/// Premium Assessment Screen with one question per page
/// Features:
/// - Smooth page transitions
/// - Progress bar
/// - Animated option cards
/// - Haptic feedback
/// - Confetti on completion
class AssessmentScreen extends ConsumerStatefulWidget {
  final AssessmentType? assessmentType;

  const AssessmentScreen({super.key, this.assessmentType});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late ConfettiController _confettiController;

  int _currentPage = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Start assessment when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.assessmentType != null) {
        ref.read(assessmentNotifierProvider.notifier).startAssessment(widget.assessmentType!);
      } else {
        final recommendedType = ref.read(recommendedAssessmentTypeProvider);
        if (recommendedType != null) {
          ref.read(assessmentNotifierProvider.notifier).startAssessment(recommendedType);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _resetAnimations() {
    _fadeController.reset();
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assessmentNotifierProvider);
    final notifier = ref.read(assessmentNotifierProvider.notifier);

    // Navigate to results when completed
    if (state.result != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confettiController.play();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) context.go(AppRoutes.assessmentResult);
        });
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: state.config == null
                ? _buildLoading()
                : _buildContent(context, state, notifier),
          ),
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [
                AppColors.primary,
                AppColors.gold,
                AppColors.success,
                AppColors.secondary,
              ],
              numberOfParticles: 50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Preparing your assessment...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AssessmentState state,
    AssessmentNotifier notifier,
  ) {
    return Column(
      children: [
        // Header with progress
        _buildHeader(context, state, notifier),
        
        // Question pages
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Disable swipe, use buttons
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _resetAnimations();
            },
            itemCount: state.totalQuestions,
            itemBuilder: (context, index) {
              final question = state.config!.questions[index];
              final answer = state.answers[index];
              
              return _QuestionPage(
                question: question,
                questionIndex: index,
                totalQuestions: state.totalQuestions,
                selectedOptionId: answer?.selectedOptionId,
                fadeAnimation: _fadeController,
                slideAnimation: _slideController,
                onOptionSelected: (optionId) {
                  HapticFeedback.lightImpact();
                  notifier.answerQuestion(optionId);
                },
              );
            },
          ),
        ),
        
        // Navigation buttons
        _buildNavigation(context, state, notifier),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AssessmentState state,
    AssessmentNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        children: [
          // Top row with close and question counter
          Row(
            children: [
              IconButton(
                onPressed: () => _showExitConfirmation(context, notifier),
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(
                  'Question ${state.currentQuestionIndex + 1} of ${state.totalQuestions}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance close button
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Progress bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            width: constraints.maxWidth * state.progress,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                
                // Percentage text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(state.progress * 100).toInt()}% complete',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '${state.answeredCount}/${state.totalQuestions} answered',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation(
    BuildContext context,
    AssessmentState state,
    AssessmentNotifier notifier,
  ) {
    final isLastQuestion = state.currentQuestionIndex == state.totalQuestions - 1;
    final currentAnswer = state.answers[state.currentQuestionIndex];
    final hasAnswer = currentAnswer != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          if (state.canGoBack)
            Expanded(
              child: OutlinedButton(
                onPressed: _isTransitioning ? null : () => _goToPrevious(notifier),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Back',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          
          if (state.canGoBack) const SizedBox(width: 12),
          
          // Next/Submit button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: hasAnswer && !_isTransitioning
                  ? () {
                      if (isLastQuestion) {
                        _submitAssessment(notifier);
                      } else {
                        _goToNext(notifier);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasAnswer ? AppColors.primary : AppColors.surfaceDark,
                foregroundColor: hasAnswer ? Colors.white : AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: hasAnswer ? 4 : 0,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: state.isSubmitting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLastQuestion ? 'See Results' : 'Next',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isLastQuestion ? Icons.check_circle_outline : Icons.arrow_forward,
                          size: 18,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToNext(AssessmentNotifier notifier) async {
    if (_isTransitioning) return;
    setState(() => _isTransitioning = true);
    
    notifier.nextQuestion();
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    
    setState(() => _isTransitioning = false);
  }

  void _goToPrevious(AssessmentNotifier notifier) async {
    if (_isTransitioning) return;
    setState(() => _isTransitioning = true);
    
    notifier.previousQuestion();
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    
    setState(() => _isTransitioning = false);
  }

  void _submitAssessment(AssessmentNotifier notifier) {
    HapticFeedback.heavyImpact();
    notifier.submitAssessment();
  }

  Future<void> _showExitConfirmation(
    BuildContext context,
    AssessmentNotifier notifier,
  ) async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Assessment?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Continue',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Exit',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (exit == true && context.mounted) {
      notifier.reset();
      context.pop();
    }
  }
}

// ============================================================================
// QUESTION PAGE
// ============================================================================

class _QuestionPage extends StatelessWidget {
  final AssessmentQuestion question;
  final int questionIndex;
  final int totalQuestions;
  final String? selectedOptionId;
  final AnimationController fadeAnimation;
  final AnimationController slideAnimation;
  final ValueChanged<String> onOptionSelected;

  const _QuestionPage({
    required this.question,
    required this.questionIndex,
    required this.totalQuestions,
    required this.selectedOptionId,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: slideAnimation,
          curve: Curves.easeOut,
        )),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dimension badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDimension(question.dimension),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Question text
              Text(
                question.text,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 32),
              
              // Options
              ...question.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isSelected = selectedOptionId == option.id;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OptionCard(
                    option: option,
                    index: index,
                    isSelected: isSelected,
                    onTap: () => onOptionSelected(option.id),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDimension(String dimension) {
    return dimension
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : word)
        .join(' ');
  }
}

// ============================================================================
// OPTION CARD
// ============================================================================

class _OptionCard extends StatefulWidget {
  final AssessmentOption option;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Option letter (A, B, C, D)
    final letter = String.fromCharCode(65 + widget.index);
    
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? AppColors.primarySoft 
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected 
                  ? AppColors.primary 
                  : AppColors.border,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Letter circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.isSelected 
                      ? AppColors.primary 
                      : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                  border: widget.isSelected
                      ? null
                      : Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: widget.isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                          letter,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Option text
              Expanded(
                child: Text(
                  widget.option.text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: widget.isSelected 
                        ? FontWeight.w600 
                        : FontWeight.w500,
                    color: widget.isSelected 
                        ? AppColors.primary 
                        : AppColors.textPrimary,
                    height: 1.4,
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
