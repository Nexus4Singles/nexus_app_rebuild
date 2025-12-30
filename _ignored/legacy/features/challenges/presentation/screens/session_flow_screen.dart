import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/journey_model.dart';
import '../../../../core/providers/journey_provider.dart';
import '../../../../core/widgets/app_loading_states.dart';

/// Premium Session Flow Screen with gamification
/// Supports all response types from JSON config:
/// - scale_3: 3-point pulse check (Low/Neutral/High)
/// - single_select: Tap-to-select chips
/// - short_text: Reflection text input
/// - challenge: Start challenge → reminder → complete
class SessionFlowScreen extends ConsumerStatefulWidget {
  final String productId;
  final int sessionNumber;

  const SessionFlowScreen({
    super.key,
    required this.productId,
    required this.sessionNumber,
  });

  @override
  ConsumerState<SessionFlowScreen> createState() => _SessionFlowScreenState();
}

class _SessionFlowScreenState extends ConsumerState<SessionFlowScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late ConfettiController _confettiController;

  // State
  int _currentStep = 0; // 0 = intro, 1 = response, 2 = check-in, 3 = complete
  String? _selectedOption;
  List<String> _selectedMultiple = [];
  int? _scaleValue;
  String _textResponse = '';
  bool _isSubmitting = false;
  int? _checkInValue;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Start the session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionNotifierProvider.notifier).startSession(
            widget.productId,
            widget.sessionNumber,
          );
    });
  }

  @override
  void dispose() {
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
    final productAsync = ref.watch(productByIdProvider(widget.productId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          productAsync.when(
            data: (product) {
              if (product == null) {
                return const AppErrorState(
                  title: 'Session Not Found',
                  message: 'This session may no longer be available.',
                );
              }

              final sessionIndex = widget.sessionNumber - 1;
              if (sessionIndex < 0 || sessionIndex >= product.sessions.length) {
                return const AppErrorState(
                  title: 'Invalid Session',
                  message: 'This session number is not valid.',
                );
              }

              final session = product.sessions[sessionIndex];
              return _buildContent(context, product, session);
            },
            loading: () => const AppLoadingScreen(),
            error: (e, _) => AppErrorState(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(productByIdProvider(widget.productId)),
            ),
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
                AppColors.tierFree,
                AppColors.secondary,
              ],
              numberOfParticles: 50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, JourneyProduct product, JourneySession session) {
    switch (_currentStep) {
      case 0:
        return _IntroStep(
          session: session,
          sessionNumber: widget.sessionNumber,
          totalSessions: product.sessions.length,
          onStart: () {
            _resetAnimations();
            setState(() => _currentStep = 1);
          },
          onClose: () => _showExitConfirmation(context),
        );
      case 1:
        return _ResponseStep(
          session: session,
          sessionNumber: widget.sessionNumber,
          totalSessions: product.sessions.length,
          selectedOption: _selectedOption,
          selectedMultiple: _selectedMultiple,
          scaleValue: _scaleValue,
          textResponse: _textResponse,
          onOptionSelected: (option) =>
              setState(() => _selectedOption = option),
          onMultipleSelected: (options) =>
              setState(() => _selectedMultiple = options),
          onScaleSelected: (value) => setState(() => _scaleValue = value),
          onTextChanged: (text) => setState(() => _textResponse = text),
          onNext: () {
            _resetAnimations();
            setState(() => _currentStep = 2);
          },
          onClose: () => _showExitConfirmation(context),
        );
      case 2:
        return _CheckInStep(
          session: session,
          checkInValue: _checkInValue,
          onValueSelected: (value) => setState(() => _checkInValue = value),
          isSubmitting: _isSubmitting,
          onSubmit: () => _submitSession(product, session),
          onClose: () => _showExitConfirmation(context),
        );
      case 3:
        return _CompletionStep(
          session: session,
          productId: widget.productId,
          sessionNumber: widget.sessionNumber,
          totalSessions: product.sessions.length,
        );
      default:
        return const SizedBox();
    }
  }

  void _submitSession(JourneyProduct product, JourneySession session) async {
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    // Save response
    await ref.read(sessionNotifierProvider.notifier).submitResponse(
          productId: widget.productId,
          sessionNumber: widget.sessionNumber,
          responseType: session.responseType,
          selectedOption: _selectedOption,
          selectedMultiple: _selectedMultiple,
          scaleValue: _scaleValue,
          textResponse: _textResponse,
          checkInValue: _checkInValue,
        );

    // Play confetti
    _confettiController.play();

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      _resetAnimations();
      setState(() {
        _isSubmitting = false;
        _currentStep = 3;
      });
    }
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Session?'),
        content: const Text(
          'Your progress in this session will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Stay',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: Text(
              'Leave',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INTRO STEP
// ============================================================================

class _IntroStep extends StatelessWidget {
  final JourneySession session;
  final int sessionNumber;
  final int totalSessions;
  final VoidCallback onStart;
  final VoidCallback onClose;

  const _IntroStep({
    required this.session,
    required this.sessionNumber,
    required this.totalSessions,
    required this.onStart,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          _buildHeader(context),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  
                  // Session badge
                  Row(
                    children: [
                      _TierBadge(tier: session.tier),
                      const SizedBox(width: 12),
                      if (session.lockRule == LockRule.free)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tierFreeLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'FREE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tierFree,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description preview
                  Text(
                    session.prompt.split('.').first + '.',
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // What to expect
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What to expect',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ExpectationItem(
                          icon: Icons.timer_outlined,
                          text: '3-5 minutes to complete',
                        ),
                        _ExpectationItem(
                          icon: Icons.psychology_outlined,
                          text: 'Honest self-reflection',
                        ),
                        _ExpectationItem(
                          icon: Icons.edit_note_outlined,
                          text: 'A practical next step',
                        ),
                      ],
                    ),
                  ),
                  
                  if (session.gamificationHook != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.goldLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              session.gamificationHook!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.goldDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Bottom action
          _BottomAction(
            label: 'Begin Session',
            icon: Icons.play_arrow,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
          ),
          Expanded(
            child: Text(
              'Session $sessionNumber of $totalSessions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ============================================================================
// RESPONSE STEP
// ============================================================================

class _ResponseStep extends StatelessWidget {
  final JourneySession session;
  final int sessionNumber;
  final int totalSessions;
  final String? selectedOption;
  final List<String> selectedMultiple;
  final int? scaleValue;
  final String textResponse;
  final ValueChanged<String> onOptionSelected;
  final ValueChanged<List<String>> onMultipleSelected;
  final ValueChanged<int> onScaleSelected;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onNext;
  final VoidCallback onClose;

  const _ResponseStep({
    required this.session,
    required this.sessionNumber,
    required this.totalSessions,
    required this.selectedOption,
    required this.selectedMultiple,
    required this.scaleValue,
    required this.textResponse,
    required this.onOptionSelected,
    required this.onMultipleSelected,
    required this.onScaleSelected,
    required this.onTextChanged,
    required this.onNext,
    required this.onClose,
  });

  bool get canContinue {
    switch (session.responseType) {
      case ResponseType.shortText:
        return textResponse.trim().isNotEmpty;
      case ResponseType.singleSelect:
        return selectedOption != null;
      case ResponseType.multiSelect:
        return selectedMultiple.isNotEmpty;
      case ResponseType.scale3:
        return scaleValue != null;
      case ResponseType.challenge:
        return true;
      case ResponseType.ranking:
        return selectedMultiple.length == (session.options?.length ?? 0);
      case ResponseType.scriptChoice:
        return selectedOption != null;
      case ResponseType.scheduler:
        return selectedOption != null; // Scheduler uses selection
      case ResponseType.compound:
        // For compound types, require at least one selection
        return selectedOption != null || textResponse.trim().isNotEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header with progress
          _buildHeader(context),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tier badge
                  _TierBadge(tier: session.tier),
                  const SizedBox(height: 20),
                  
                  // Title
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Prompt
                  Text(
                    session.prompt,
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Response input
                  _buildResponseInput(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          
          // Bottom action
          _BottomAction(
            label: 'Continue',
            icon: Icons.arrow_forward,
            onPressed: canContinue ? onNext : null,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(
                  'Session $sessionNumber',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5, // 50% - halfway through session
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseInput(BuildContext context) {
    switch (session.responseType) {
      case ResponseType.scale3:
        return _buildScale3Input();
      case ResponseType.singleSelect:
        return _buildSingleSelectInput();
      case ResponseType.multiSelect:
        return _buildMultiSelectInput();
      case ResponseType.shortText:
        return _buildTextInput();
      case ResponseType.challenge:
        return _buildChallengeInput();
      case ResponseType.ranking:
        return _buildRankingInput();
      case ResponseType.scriptChoice:
        return _buildScriptChoiceInput();
      case ResponseType.scheduler:
        return _buildSchedulerInput();
      case ResponseType.compound:
        return _buildCompoundInput();
    }
  }

  /// Script choice - select from pre-written scripts
  Widget _buildScriptChoiceInput() {
    final options = session.options ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a script:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = selectedOption == index;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onOptionSelected(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySoft : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '"',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Scheduler - select time/day for activity
  Widget _buildSchedulerInput() {
    final options = session.options ?? ['Morning', 'Afternoon', 'Evening', 'Custom'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When will you do this?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = selectedOption == index;
            
            IconData icon;
            if (option.toLowerCase().contains('morning')) {
              icon = Icons.wb_sunny;
            } else if (option.toLowerCase().contains('afternoon')) {
              icon = Icons.wb_twilight;
            } else if (option.toLowerCase().contains('evening')) {
              icon = Icons.nights_stay;
            } else {
              icon = Icons.schedule;
            }
            
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onOptionSelected(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Compound input - combination of selection + text
  Widget _buildCompoundInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First show selection
        _buildSingleSelectInput(),
        const SizedBox(height: 24),
        // Then show text input for additional notes
        Text(
          'Add your thoughts (optional):',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            onChanged: onTextChanged,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Write your reflection...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScale3Input() {
    final options = session.options ?? ['Low', 'Neutral', 'High'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do you feel?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(options.length, (index) {
            final option = options[index];
            final isSelected = scaleValue == index;
            
            Color optionColor;
            IconData optionIcon;
            if (index == 0) {
              optionColor = AppColors.error;
              optionIcon = Icons.sentiment_dissatisfied;
            } else if (index == 1) {
              optionColor = AppColors.warning;
              optionIcon = Icons.sentiment_neutral;
            } else {
              optionColor = AppColors.success;
              optionIcon = Icons.sentiment_satisfied;
            }
            
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < options.length - 1 ? 12 : 0),
                child: _PulseOption(
                  label: option,
                  icon: optionIcon,
                  color: optionColor,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onScaleSelected(index);
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSingleSelectInput() {
    final options = session.options ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose one:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        ...options.map((option) {
          final isSelected = selectedOption == option;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SelectOption(
              label: option,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.lightImpact();
                onOptionSelected(option);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMultiSelectInput() {
    final options = session.options ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select all that apply:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = selectedMultiple.contains(option);
            return _ChipOption(
              label: option,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.lightImpact();
                final newList = List<String>.from(selectedMultiple);
                if (isSelected) {
                  newList.remove(option);
                } else {
                  newList.add(option);
                }
                onMultipleSelected(newList);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your reflection:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            maxLines: 5,
            maxLength: 280,
            onChanged: onTextChanged,
            decoration: InputDecoration(
              hintText: 'Write your thoughts here...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterStyle: TextStyle(color: AppColors.textMuted),
            ),
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            '🎯 24-Hour Challenge',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Complete this challenge within 24 hours and come back to mark it done!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ChallengeButton(
                  label: 'Start',
                  icon: Icons.play_arrow,
                  isSelected: selectedOption == 'Start',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onOptionSelected('Start');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChallengeButton(
                  label: 'Remind Me',
                  icon: Icons.notifications,
                  isSelected: selectedOption == 'Remind me',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onOptionSelected('Remind me');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankingInput() {
    // Simplified ranking - use multi-select for now
    return _buildMultiSelectInput();
  }
}

// ============================================================================
// CHECK-IN STEP
// ============================================================================

class _CheckInStep extends StatelessWidget {
  final JourneySession session;
  final int? checkInValue;
  final ValueChanged<int> onValueSelected;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  const _CheckInStep({
    required this.session,
    required this.checkInValue,
    required this.onValueSelected,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                ),
                const Expanded(
                  child: Text(
                    'Post-Session Check-in',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          // Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  
                  const Text(
                    '🤔',
                    style: TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text(
                    'How confident do you feel after this session?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Check-in options
                  _CheckInOption(
                    label: 'Low',
                    description: 'I need more time with this',
                    icon: Icons.sentiment_dissatisfied,
                    color: AppColors.error,
                    isSelected: checkInValue == 0,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onValueSelected(0);
                    },
                  ),
                  const SizedBox(height: 12),
                  _CheckInOption(
                    label: 'Neutral',
                    description: 'I\'m processing this',
                    icon: Icons.sentiment_neutral,
                    color: AppColors.warning,
                    isSelected: checkInValue == 1,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onValueSelected(1);
                    },
                  ),
                  const SizedBox(height: 12),
                  _CheckInOption(
                    label: 'High',
                    description: 'I feel good about this!',
                    icon: Icons.sentiment_satisfied,
                    color: AppColors.success,
                    isSelected: checkInValue == 2,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onValueSelected(2);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Submit button
          _BottomAction(
            label: isSubmitting ? 'Completing...' : 'Complete Session',
            icon: Icons.check_circle_outline,
            onPressed: checkInValue != null && !isSubmitting ? onSubmit : null,
            isLoading: isSubmitting,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPLETION STEP
// ============================================================================

class _CompletionStep extends StatelessWidget {
  final JourneySession session;
  final String productId;
  final int sessionNumber;
  final int totalSessions;

  const _CompletionStep({
    required this.session,
    required this.productId,
    required this.sessionNumber,
    required this.totalSessions,
  });

  @override
  Widget build(BuildContext context) {
    final hasMoreSessions = sessionNumber < totalSessions;
    
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Congrats text
              const Text(
                'Amazing! 🎉',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You completed "${session.title}"',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Stats
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SuccessStat(icon: '🔥', value: '+1', label: 'Streak'),
                    Container(width: 1, height: 50, color: AppColors.border),
                    _SuccessStat(icon: '⭐', value: '+10', label: 'Points'),
                    Container(width: 1, height: 50, color: AppColors.border),
                    _SuccessStat(
                      icon: '📊',
                      value: '${((sessionNumber / totalSessions) * 100).round()}%',
                      label: 'Progress',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Actions
              if (hasMoreSessions)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/journey/$productId/session/${sessionNumber + 1}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Next Session',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/journey/$productId'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: const Text(
                    'Back to Journey',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  'Go Home',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================

class _TierBadge extends StatelessWidget {
  final SessionTier tier;

  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final tierName = tier.name[0].toUpperCase() + tier.name.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getTierLightColor(tierName),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tierName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.getTierColor(tierName),
        ),
      ),
    );
  }
}

class _ExpectationItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExpectationItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _PulseOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PulseOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textMuted, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectOption({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.textMuted, width: 2),
              ),
              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChipOption({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ChallengeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChallengeButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? AppColors.primary : Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CheckInOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
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
          color: isSelected ? color.withOpacity(0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textMuted, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isSelected ? color : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: isSelected ? color.withOpacity(0.8) : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _BottomAction({required this.label, required this.icon, this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.primary : AppColors.surfaceDark,
          foregroundColor: isEnabled ? Colors.white : AppColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isEnabled ? 4 : 0,
          shadowColor: AppColors.primary.withOpacity(0.3),
        ),
        child: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Icon(icon, size: 20),
                ],
              ),
      ),
    );
  }
}

class _SuccessStat extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _SuccessStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
