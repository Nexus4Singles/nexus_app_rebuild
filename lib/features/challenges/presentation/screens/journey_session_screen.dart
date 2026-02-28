import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/providers/user_provider.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/rich_text_parser.dart';
import '../../../../core/widgets/guest_guard.dart';
import '../../../../core/ui/icon_mapper.dart';
import '../../domain/journey_v1_models.dart';
import '../../providers/journeys_providers.dart';

class JourneySessionScreen extends ConsumerStatefulWidget {
  final String journeyId;
  final String missionId;

  const JourneySessionScreen({
    super.key,
    required this.journeyId,
    required this.missionId,
  });

  @override
  ConsumerState<JourneySessionScreen> createState() =>
      _JourneySessionScreenState();
}

class _JourneySessionScreenState extends ConsumerState<JourneySessionScreen> {
  bool _gateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSignedIn());
  }

  Future<void> _ensureSignedIn() async {
    if (_gateChecked) return;
    _gateChecked = true;

    await GuestGuard.requireSignedIn(
      context,
      ref,
      title: 'Sign in required',
      message: 'Create an account to start Activities and track your progress.',
      primaryText: 'Continue',
      onCreateAccount: () {
        Navigator.of(context).pushNamed(AppRoutes.login);
      },
    );

    final authAsync = ref.read(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );
    if (!isSignedIn && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  bool _failed = false;
  int _cardIndex = 0;

  // cardKey -> selectedOption
  final Map<String, String> _choiceSelections = {};
  final Set<String> _hydratedCardKeys = {};

  String _cardKey(int index) => 'card_$index';

  Future<void> _hydrateChoices(MissionV1 activity) async {
    final svc = ref.read(journeyMissionResponseServiceProvider);

    for (var i = 0; i < activity.cards.length; i++) {
      final c = activity.cards[i];
      if (c.type != 'choice_card') continue;

      final key = _cardKey(i);
      if (_hydratedCardKeys.contains(key)) continue;

      final saved = await svc.loadChoice(
        journeyId: widget.journeyId,
        missionId: widget.missionId,
        cardKey: key,
      );

      if (saved != null) {
        _choiceSelections[key] = saved;
      }
      _hydratedCardKeys.add(key);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );
    if (!isSignedIn) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final catalogAsync = ref.watch(journeyCatalogProvider);

    return catalogAsync.when(
      loading:
          () => Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: Center(child: CircularProgressIndicator()),
          ),
      error:
          (_, __) => _simpleScaffold(
            title: 'Activity',
            body: const Center(child: Text('Unable to load journeys')),
          ),
      data: (catalog) {
        final journey = catalog.findById(widget.journeyId);
        if (journey == null) {
          return _simpleScaffold(
            title: 'Activity',
            body: const Center(child: Text('Journey not found')),
          );
        }

        MissionV1? activity;
        try {
          activity = journey.missions.firstWhere(
            (m) => m.id == widget.missionId,
            orElse: () => journey.missions.first,
          );
        } catch (_) {
          activity = null;
        }

        if (activity == null) {
          return _simpleScaffold(
            title: 'Activity',
            body: const Center(child: Text('Activity not found')),
          );
        }

        final m = activity;

        // Mark as in-progress when user opens the activity
        final currentUserAsync = ref.watch(currentUserProvider);
        currentUserAsync.maybeWhen(
          data: (user) {
            if (user?.id != null) {
              final progressSvc = ref.read(journeyProgressServiceProvider);
              progressSvc.markMissionInProgress(
                widget.journeyId,
                widget.missionId,
                user!.id,
              );
            }
          },
          orElse: () {},
        );

        // hydrate choices once we have activity
        _hydrateChoices(m);

        final totalCards = m.cards.length;
        final progressIndex = (_cardIndex + 1).clamp(1, totalCards);

        return Scaffold(
          backgroundColor: AppColors.getBackground(context),
          appBar: AppBar(
            title: Text(
              'Activity ${m.missionNumber}',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: AppColors.getBackground(context),
            surfaceTintColor: AppColors.getBackground(context),
            elevation: 0,
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SessionHero(
                    title: m.title,
                    subtitle: m.subtitle,
                    index: progressIndex,
                    total: totalCards,
                    progress:
                        totalCards == 0 ? 0.0 : progressIndex / totalCards,
                    icon: iconFromKey(m.icon),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Text(
                      'We recommend using a Journal to document on this journey!',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        totalCards == 0
                            ? const Center(
                              child: Text('No cards found for this activity.'),
                            )
                            : _CardShell(
                              cardIndex: _cardIndex,
                              child: _MissionCardRenderer(
                                card: m.cards[_cardIndex],
                                journeyId: widget.journeyId,
                                missionId: widget.missionId,
                                cardIndex: _cardIndex,
                                choiceSelections: _choiceSelections,
                                onChoiceSelected: (val) {
                                  setState(() {
                                    _choiceSelections[_cardKey(_cardIndex)] =
                                        val;
                                  });
                                },
                              ),
                            ),
                  ),
                  const SizedBox(height: 12),
                  _OutcomeButtons(
                    failed: _failed,
                    isFirst: _cardIndex == 0,
                    isLast: _cardIndex >= totalCards - 1,
                    onBack: () {
                      if (_cardIndex == 0) return;
                      setState(() => _cardIndex -= 1);
                    },
                    onNext: () async {
                      if (totalCards == 0) return;

                      // save choice card if needed
                      final card = m.cards[_cardIndex];
                      if (card.type == 'choice_card') {
                        final key = _cardKey(_cardIndex);
                        final selected = _choiceSelections[key];
                        if (selected != null) {
                          final svc = ref.read(
                            journeyMissionResponseServiceProvider,
                          );
                          await svc.saveChoice(
                            journeyId: widget.journeyId,
                            missionId: widget.missionId,
                            cardKey: key,
                            selectedOption: selected,
                          );
                        }
                      }

                      if (_cardIndex >= totalCards - 1) {
                        // mark completed
                        final currentUserAsync = ref.watch(currentUserProvider);
                        final uid = currentUserAsync.maybeWhen(
                          data: (user) => user?.id ?? '',
                          orElse: () => '',
                        );

                        if (uid.isNotEmpty) {
                          final progressSvc = ref.read(
                            journeyProgressServiceProvider,
                          );
                          await progressSvc.markMissionCompleted(
                            widget.journeyId,
                            m.id,
                            uid,
                          );
                          // Clear in-progress when completed
                          await progressSvc.clearInProgress(widget.journeyId);

                          // CRITICAL: Invalidate provider cache to force UI refresh with checkmark
                          ref.invalidate(
                            completedMissionIdsProvider(widget.journeyId),
                          );
                          ref.invalidate(
                            isJourneyCompletedProvider(widget.journeyId),
                          );
                        }

                        if (!mounted) return;

                        // Check if journey is purchased and if this is the last mission
                        final isPurchasedAsync = ref.watch(
                          isJourneyPurchasedProvider(widget.journeyId),
                        );
                        final isPurchased = isPurchasedAsync.maybeWhen(
                          data: (purchased) => purchased,
                          orElse: () => false,
                        );

                        final isLastMission =
                            m.missionNumber == journey.missions.length;

                        // Determine the appropriate message
                        String snackBarMessage;
                        if (isLastMission && isPurchased) {
                          // User completed the entire journey and has purchased
                          snackBarMessage =
                              '🎉 Activity completed! You\'ve finished this journey!';
                        } else if (!isPurchased && m.isFree) {
                          // User completed the free activity but hasn't purchased
                          snackBarMessage =
                              '✅ Activity completed... Purchase the complete journey to continue your progress';
                        } else {
                          // Standard completion message for intermediate activities
                          snackBarMessage = '✅ Activity completed';
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(snackBarMessage),
                            duration: const Duration(seconds: 3),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.success,
                          ),
                        );
                        Navigator.pop(context);
                        return;
                      }

                      setState(() => _cardIndex += 1);
                    },
                    onReset: () async {
                      final currentUserAsync = ref.watch(currentUserProvider);
                      final uid = currentUserAsync.maybeWhen(
                        data: (user) => user?.id ?? '',
                        orElse: () => '',
                      );

                      if (uid.isNotEmpty) {
                        final progressSvc = ref.read(
                          journeyProgressServiceProvider,
                        );
                        await progressSvc.resetMission(
                          widget.journeyId,
                          m.id,
                          uid,
                        );
                        // Invalidate provider cache to sync UI with reset state
                        ref.invalidate(
                          completedMissionIdsProvider(widget.journeyId),
                        );
                        ref.invalidate(
                          isJourneyCompletedProvider(widget.journeyId),
                        );
                      }

                      final responseSvc = ref.read(
                        journeyMissionResponseServiceProvider,
                      );
                      await responseSvc.clearMission(
                        journeyId: widget.journeyId,
                        missionId: widget.missionId,
                      );

                      if (!mounted) return;
                      setState(() {
                        _failed = false;
                        _cardIndex = 0;
                        _choiceSelections.clear();
                        _hydratedCardKeys.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Scaffold _simpleScaffold({required String title, required Widget body}) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
      ),
      body: body,
    );
  }
}

class _SessionHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final int index;
  final int total;
  final double progress;
  final IconData icon;

  const _SessionHero({
    required this.title,
    required this.subtitle,
    required this.index,
    required this.total,
    required this.progress,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final showProgress = total > 0;
    final surface = AppColors.getSurface(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradient = LinearGradient(
      colors: [
        Color.alphaBlend(
          AppColors.primary.withOpacity(isDark ? 0.90 : 0.12),
          surface,
        ),
        Color.alphaBlend(
          AppColors.primary.withOpacity(isDark ? 0.70 : 0.18),
          surface,
        ),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final textColor =
        isDark
            ? AppColors.getTextOnDark(context)
            : AppColors.getTextPrimary(context);
    final secondary =
        isDark
            ? AppColors.getTextOnDark(context).withOpacity(0.88)
            : AppColors.getTextSecondary(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.getTextOnDark(context).withOpacity(0.16)
                          : AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color:
                      isDark
                          ? AppColors.getTextOnDark(context)
                          : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600, // milder font weight
                    height: 1.28,
                  ),
                ),
              ),
              if (showProgress)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.getTextOnDark(
                                context,
                              ).withOpacity(0.18)
                              : AppColors.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.getTextOnDark(
                                  context,
                                ).withOpacity(0.25)
                                : AppColors.primary.withOpacity(0.20),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.window_outlined,
                          size: 13,
                          color:
                              isDark
                                  ? AppColors.getTextOnDark(context)
                                  : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$index/$total',
                          style: AppTextStyles.labelSmall.copyWith(
                            color:
                                isDark
                                    ? AppColors.getTextOnDark(context)
                                    : AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: secondary,
              height: 1.6,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.primary.withOpacity(0.18),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardShell extends StatefulWidget {
  final Widget child;
  final int cardIndex;

  const _CardShell({required this.child, required this.cardIndex});

  @override
  State<_CardShell> createState() => _CardShellState();
}

class _CardShellState extends State<_CardShell> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the card index changes, reset scroll to top
    if (widget.cardIndex != oldWidget.cardIndex) {
      if (_scrollController.hasClients) {
        try {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } catch (_) {
          // fallback to jump
          _scrollController.jumpTo(0);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadowDark : AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}

class _OutcomeButtons extends StatelessWidget {
  final bool failed;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onReset;

  const _OutcomeButtons({
    required this.failed,
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Row(
        children: [
          if (!isFirst) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.primary.withOpacity(0.18)
                          : AppColors.primary.withOpacity(0.08),
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: Text(isLast ? '🎉 Complete Journey' : 'Next'),
            ),
          ),
          if (failed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: TextButton(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Reset'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionCardRenderer extends StatelessWidget {
  final MissionCardV1 card;
  final String journeyId;
  final String missionId;
  final int cardIndex;
  final Map<String, String> choiceSelections;
  final ValueChanged<String> onChoiceSelected;

  const _MissionCardRenderer({
    required this.card,
    required this.journeyId,
    required this.missionId,
    required this.cardIndex,
    required this.choiceSelections,
    required this.onChoiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    switch (card.type) {
      case 'instruction_card':
      case 'tip_card':
      case 'mission_card':
        return _InfoCard(
          title: card.title,
          flavor: card.flavor,
          text: card.text ?? '',
          bullets: card.bullets,
        );

      case 'choice_card':
      case 'question':
        final key = 'card_$cardIndex';
        final selected = choiceSelections[key];
        // Priority: prompt field → text field (for question cards) → first prompt from array
        final promptText =
            card.prompt ??
            card.text ??
            (card.prompts?.isNotEmpty == true ? card.prompts!.first : '');
        return _ChoiceCard(
          title: card.title,
          flavor: card.flavor,
          prompt: promptText,
          options: card.options ?? const [],
          selected: selected,
          onSelected: onChoiceSelected,
          reflection: card.reflection,
        );

      case 'reflection_card':
      case 'reflection':
        return _ReflectionCard(
          title: card.title,
          flavor: card.flavor ?? 'reflection',
          text: card.text ?? '',
          reflection: card.reflection ?? '',
          responseType: card.responseType ?? 'open-text',
        );

      case 'action':
      case 'action_card':
        return _ActionCard(
          title: card.title,
          flavor: card.flavor ?? 'action',
          text: card.text ?? '',
        );

      default:
        return _InfoCard(
          title: card.title,
          text: card.text ?? '',
          bullets: card.bullets,
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String? flavor;
  final String text;
  final List<String>? bullets;

  const _InfoCard({
    required this.title,
    required this.text,
    this.bullets,
    this.flavor,
  });

  @override
  Widget build(BuildContext context) {
    final hasBullets = bullets != null && bullets!.isNotEmpty;
    final badge = _flavorBadge(flavor);

    // Parse text content with proper line breaks and formatting
    final textBlocks = _parseRichContent(text);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (badge != null) badge,
            ],
          ),

          const SizedBox(height: 12),

          // Use proper rich content parsing for text
          if (textBlocks.isNotEmpty) ...[
            ..._buildBodyWidgets(
              textBlocks,
              AppTextStyles.bodyMedium.copyWith(
                height: 1.65,
                letterSpacing: 0.25,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],

          // Handle bullets separately with proper formatting
          if (hasBullets) ...[
            if (textBlocks.isNotEmpty) const SizedBox(height: 8),
            ...bullets!.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: _buildInlineSpans(
                            b.trim(),
                            AppTextStyles.bodyMedium.copyWith(
                              height: 1.65,
                              letterSpacing: 0.25,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String? flavor;
  final String prompt;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String? reflection; // Optional reflection prompt after selection

  const _ChoiceCard({
    required this.title,
    this.flavor,
    required this.prompt,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.reflection,
  });

  @override
  Widget build(BuildContext context) {
    final bodyStyle = AppTextStyles.bodyMedium.copyWith(
      height: 1.45,
      color: AppColors.getTextPrimary(context),
    );
    final badge = _flavorBadge(flavor ?? 'question');

    final parsedPrompt = _parseRichContent(prompt);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600, // milder font weight
                    height: 1.15,
                  ),
                ),
              ),
              if (badge != null) badge,
            ],
          ),
          const SizedBox(height: 8),

          ..._buildBodyWidgets(parsedPrompt, bodyStyle),

          const SizedBox(height: 14),
          ...options.map((o) {
            final isSelected = selected == o;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelected(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? (isDark
                                ? AppColors.primary.withOpacity(0.20)
                                : AppColors.primary.withOpacity(0.10))
                            : AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.primary
                              : AppColors.getBorder(context),
                      width: isSelected ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.getTextSecondary(context)
                                        : AppColors.getBorder(context)),
                            width: isSelected ? 0 : 1.5,
                          ),
                        ),
                        child:
                            isSelected
                                ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Show reflection prompt if user has selected an option and reflection exists
          if (selected != null &&
              reflection != null &&
              reflection!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Take a moment to reflect:',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildBodyWidgets(
                    _parseRichContent(reflection!),
                    AppTextStyles.bodyMedium.copyWith(
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String? flavor;
  final String text;

  const _ActionCard({required this.title, required this.text, this.flavor});

  @override
  Widget build(BuildContext context) {
    final badge = _flavorBadge(flavor ?? 'action');
    final blocks = _parseRichContent(text);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (badge != null) badge,
            ],
          ),
          const SizedBox(height: 12),
          if (blocks.isNotEmpty)
            ..._buildBodyWidgets(
              blocks,
              AppTextStyles.bodyMedium.copyWith(
                height: 1.65,
                letterSpacing: 0.25,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reflection card for guided reflection exercises
class _ReflectionCard extends StatelessWidget {
  final String title;
  final String flavor;
  final String text;
  final String reflection;
  final String responseType; // 'open-text', 'single-select', 'multiple-select'

  const _ReflectionCard({
    required this.title,
    required this.flavor,
    required this.text,
    required this.reflection,
    required this.responseType,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _flavorBadge(flavor);
    final bgColor = _flavorColor(flavor);

    // Parse content with proper line breaks
    // If reflection is empty, use text as the reflection content
    final effectiveReflectionText = reflection.isNotEmpty ? reflection : text;

    final textBlocks = _parseRichContent(text);
    final reflectionBlocks = _parseRichContent(effectiveReflectionText);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (badge != null) badge,
            ],
          ),
          const SizedBox(height: 12),

          // Instructions/context with proper spacing
          // Only show text section if we have a separate reflection field
          // (if no reflection field, text becomes the main reflection content)
          if (textBlocks.isNotEmpty && reflection.isNotEmpty) ...[
            ..._buildBodyWidgets(
              textBlocks,
              AppTextStyles.bodyMedium.copyWith(
                height: 1.65,
                letterSpacing: 0.25,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorder(context), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: bgColor),
                    const SizedBox(width: 8),
                    Text(
                      'Take a moment to reflect:',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: bgColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._buildBodyWidgets(
                  reflectionBlocks,
                  AppTextStyles.bodyMedium.copyWith(
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.getBorder(context)),
            ),
            child: Text(
              'Response type: $responseType',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// WORLD-CLASS TEXT RENDERER
/// ===============================

enum _BlockType { paragraph, bullet }

class _Block {
  final _BlockType type;
  final String text;
  const _Block(this.type, this.text);
}

/// Parse text into paragraphs and bullet lines.
/// Supports:
/// - "- ..." / "* ..." / "• ..."
/// - blank lines = paragraph breaks
List<_Block> _parseRichContent(String raw) {
  final normalizedRaw = _normalizeOverBoldContent(raw);
  final lines = normalizedRaw.split('\n');

  final blocks = <_Block>[];
  final buffer = <String>[];

  void flushParagraph() {
    if (buffer.isEmpty) return;
    final p = buffer.join('\n').trim();
    if (p.isNotEmpty) {
      blocks.add(_Block(_BlockType.paragraph, p));
    }
    buffer.clear();
  }

  for (final line in lines) {
    final trimmed = line.trimRight();

    if (trimmed.trim().isEmpty) {
      flushParagraph();
      continue;
    }

    final bulletMatch = RegExp(r'^\s*([-*•])\s+(.*)$').firstMatch(trimmed);
    if (bulletMatch != null) {
      flushParagraph();
      blocks.add(_Block(_BlockType.bullet, bulletMatch.group(2) ?? ''));
      continue;
    }

    buffer.add(trimmed);
  }

  flushParagraph();
  return blocks;
}

/// Bible book names used for detecting verse references inside bold segments.
final RegExp _bibleRefPattern = RegExp(
  r'(?:Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|'
  r'[123]\s*Samuel|[123]\s*Kings|[123]\s*Chronicles|'
  r'Ezra|Nehemiah|Esther|Job|Psalms?|Proverbs|Ecclesiastes|'
  r'Song\s*of\s*Solomon|Songs?\s*of\s*Songs?|'
  r'Isaiah|Jeremiah|Lamentations|Ezekiel|Daniel|'
  r'Hosea|Joel|Amos|Obadiah|Jonah|Micah|Nahum|'
  r'Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|'
  r'Matthew|Mark|Luke|John|Acts|Romans|'
  r'[12]\s*Corinthians|Galatians|Ephesians|Philippians|Colossians|'
  r'[12]\s*Thessalonians|[12]\s*Timothy|Titus|Philemon|'
  r'Hebrews|James|[12]\s*Peter|[123]\s*John|Jude|Revelation'
  r')\s+\d+[:\d\-]*',
  caseSensitive: false,
);

/// Returns true when a bold segment should keep its **markers**.
///
/// Bold is preserved when the segment contains:
///  • A Bible verse reference  (e.g. Psalm 34:18)
///  • Quoted speech / key phrase  (contains " quotation marks)
bool _shouldKeepBold(String content) {
  if (_bibleRefPattern.hasMatch(content)) return true;
  if (content.contains('"') ||
      content.contains('\u201C') ||
      content.contains('\u201D')) {
    return true;
  }
  return false;
}

/// Strips unnecessary **bold** markers from journey card text while preserving
/// bold on Bible references and quoted text.
///
/// Also removes orphaned ** markers (from malformed source data) that aren't
/// part of any matched **...** pair, preventing stray ** from showing to users.
///
/// This runs at render-time so it works for both cloud-fetched and local content.
String _normalizeOverBoldContent(String raw) {
  final boldPattern = RegExp(r'\*\*(.+?)\*\*');

  // Step 1: Process matched **...** pairs — strip or keep based on content.
  final afterStep1 = raw.replaceAllMapped(boldPattern, (match) {
    final inner = match.group(1)!;
    if (_shouldKeepBold(inner)) {
      return match.group(0)!; // keep bold markers
    }
    return inner; // strip bold markers, keep the text
  });

  // Step 2: Remove orphaned ** that aren't part of any remaining matched pair.
  // After step 1, remaining matched pairs are intentional (Bible/quotes).
  // Any lone ** leftover is from malformed source data.
  final remainingMatches = boldPattern.allMatches(afterStep1).toList();

  // Build a set of character positions that belong to preserved bold pairs.
  final preservedPositions = <int>{};
  for (final m in remainingMatches) {
    // Mark every character index in the matched range as preserved.
    for (var i = m.start; i < m.end; i++) {
      preservedPositions.add(i);
    }
  }

  // Find ALL ** positions and remove those not inside a preserved range.
  final starPattern = RegExp(r'\*\*');
  final allStars = starPattern.allMatches(afterStep1).toList();
  final orphans =
      allStars.where((m) => !preservedPositions.contains(m.start)).toList();

  if (orphans.isEmpty) return afterStep1;

  // Build result, skipping orphaned ** markers.
  final buf = StringBuffer();
  var cursor = 0;
  for (final orphan in orphans) {
    buf.write(afterStep1.substring(cursor, orphan.start));
    cursor = orphan.end; // skip the 2-char **
  }
  buf.write(afterStep1.substring(cursor));

  return buf.toString();
}

/// Builds widgets from parsed blocks with spacing.
List<Widget> _buildBodyWidgets(List<_Block> blocks, TextStyle style) {
  final widgets = <Widget>[];

  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];

    if (b.type == _BlockType.paragraph) {
      widgets.add(
        RichText(text: TextSpan(children: _buildInlineSpans(b.text, style))),
      );
    } else {
      widgets.add(_BulletLine(text: b.text, style: style));
    }

    if (i != blocks.length - 1) {
      widgets.add(const SizedBox(height: 10));
    }
  }

  return widgets;
}

Color _flavorColor(String? flavor) {
  // Return primary for most cases - this ensures consistent theming
  return AppColors.primary;
}

Widget? _flavorBadge(String? flavor) {
  if (flavor == null || flavor.trim().isEmpty) return null;

  String label;
  IconData icon;
  final f = flavor.toLowerCase();

  if (f.contains('question')) {
    label = 'Question';
    icon = Icons.help_outline;
  } else if (f.contains('reflection')) {
    label = 'Reflection';
    icon = Icons.self_improvement_outlined;
  } else if (f.contains('action')) {
    label = 'Action';
    icon = Icons.bolt;
  } else if (f.contains('teaching')) {
    label = 'Teaching';
    icon = Icons.menu_book_outlined;
  } else if (f.contains('tip')) {
    label = 'Tip';
    icon = Icons.tips_and_updates_outlined;
  } else {
    label = flavor[0].toUpperCase() + flavor.substring(1);
    icon = Icons.description_outlined;
  }
  final bg = _flavorColor(flavor);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: bg.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: bg),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w800,
            color: bg,
          ),
        ),
      ],
    ),
  );
}

/// Delegates to [RichTextParser.buildInlineSpans] which correctly handles:
/// ✅ {red|text} (including multi-line spans — extracted *before* newline splits)
/// ✅ "Label:" bolding at start of line
/// ✅ **bold**
/// ✅ *italic*
List<TextSpan> _buildInlineSpans(String text, TextStyle baseStyle) {
  return RichTextParser.buildInlineSpans(text, baseStyle);
}

class _BulletLine extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _BulletLine({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.75),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: _buildInlineSpans(text, style.copyWith(height: 1.45)),
            ),
          ),
        ),
      ],
    );
  }
}
