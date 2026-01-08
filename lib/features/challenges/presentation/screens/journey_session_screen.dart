import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
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
    final catalogAsync = ref.watch(journeyCatalogProvider);

    return catalogAsync.when(
      loading:
          () => const Scaffold(
            backgroundColor: AppColors.background,
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

        // hydrate choices once we have activity
        _hydrateChoices(m);

        final totalCards = m.cards.length;
        final progressIndex = (_cardIndex + 1).clamp(1, totalCards);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('Activity ${m.missionNumber}'),
            backgroundColor: AppColors.background,
            surfaceTintColor: AppColors.background,
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardsProgressHeader(index: progressIndex, total: totalCards),
                  const SizedBox(height: 14),
                  Text(
                    m.title,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        totalCards == 0
                            ? const Center(
                              child: Text('No cards found for this activity.'),
                            )
                            : _MissionCardRenderer(
                              card: m.cards[_cardIndex],
                              journeyId: widget.journeyId,
                              missionId: widget.missionId,
                              cardIndex: _cardIndex,
                              choiceSelections: _choiceSelections,
                              onChoiceSelected: (val) {
                                setState(() {
                                  _choiceSelections[_cardKey(_cardIndex)] = val;
                                });
                              },
                            ),
                  ),
                  const SizedBox(height: 14),
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
                        final progressSvc = ref.read(
                          journeyProgressServiceProvider,
                        );
                        await progressSvc.markMissionCompleted(
                          widget.journeyId,
                          m.id,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Activity completed')),
                        );
                        Navigator.pop(context);
                        return;
                      }

                      setState(() => _cardIndex += 1);
                    },
                    onReset: () async {
                      final progressSvc = ref.read(
                        journeyProgressServiceProvider,
                      );
                      await progressSvc.resetMission(widget.journeyId, m.id);

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
      ),
      body: body,
    );
  }
}

class _CardsProgressHeader extends StatelessWidget {
  final int index;
  final int total;
  const _CardsProgressHeader({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (index / total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Step $index of $total',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Text(
              '${(pct * 100).round()}%',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: AppColors.border.withOpacity(0.7),
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
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
    return Row(
      children: [
        if (!isFirst)
          Expanded(
            child: OutlinedButton(onPressed: onBack, child: const Text('Back')),
          ),
        if (!isFirst) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onNext,
            child: Text(isLast ? 'Finish' : 'Next'),
          ),
        ),
        if (failed) ...[
          const SizedBox(width: 12),
          Expanded(
            child: TextButton(onPressed: onReset, child: const Text('Reset')),
          ),
        ],
      ],
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
        return _InfoCard(
          iconKey: card.icon,
          title: card.title,
          text: card.text ?? '',
          bullets: card.bullets,
        );

      case 'tip_card':
        return _InfoCard(
          iconKey: card.icon,
          title: card.title,
          text: card.text ?? '',
          bullets: card.bullets,
        );

      case 'choice_card':
        {
          final key = 'card_$cardIndex';
          final selected = choiceSelections[key];

          return _ChoiceCard(
            iconKey: card.icon,
            title: card.title,
            prompt: card.prompt ?? '',
            options: card.options ?? const [],
            selected: selected,
            onSelected: onChoiceSelected,
          );
        }

      case 'mission_card':
      default:
        return _InfoCard(
          iconKey: card.icon,
          title: card.title,
          text: card.text ?? '',
          bullets: card.bullets,
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String iconKey;
  final String title;
  final String text;
  final List<String>? bullets;

  const _InfoCard({
    required this.iconKey,
    required this.title,
    required this.text,
    this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: iconFromKey(iconKey)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: AppTextStyles.bodyMedium.copyWith(height: 1.35)),
          if (bullets != null && bullets!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...bullets!.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(
                      child: Text(
                        b,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.3),
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
  final String iconKey;
  final String title;
  final String prompt;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ChoiceCard({
    required this.iconKey,
    required this.title,
    required this.prompt,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: iconFromKey(iconKey)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(prompt, style: AppTextStyles.bodyMedium.copyWith(height: 1.35)),
          const SizedBox(height: 14),
          ...options.map((o) {
            final isSelected = selected == o;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppColors.primary.withOpacity(0.10)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.22),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  const _IconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.primary),
    );
  }
}
