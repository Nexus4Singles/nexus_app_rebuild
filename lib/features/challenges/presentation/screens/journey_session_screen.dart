import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/ui/icon_mapper.dart';
import '../../providers/journeys_providers.dart';
import '../../domain/journey_v1_models.dart';

class JourneySessionScreen extends ConsumerStatefulWidget {
  final String journeyId;
  final String missionId;

  const JourneySessionScreen({
    super.key,
    required this.journeyId,
    required this.missionId,
  });

  @override
  ConsumerState<JourneySessionScreen> createState() => _JourneySessionScreenState();
}

class _JourneySessionScreenState extends ConsumerState<JourneySessionScreen> {
  bool _failed = false;
  int _cardIndex = 0;

  // cardKey -> selectedOption
  final Map<String, String> _choiceSelections = {};
  final Set<String> _hydratedCardKeys = {};

  String _cardKey(int index) => 'card_$index';

  Future<void> _hydrateChoices(MissionV1 mission) async {
    final svc = ref.read(journeyMissionResponseServiceProvider);

    for (var i = 0; i < mission.cards.length; i++) {
      final c = mission.cards[i];
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
    final journey = ref.watch(journeyByIdProvider(widget.journeyId));
    MissionV1? mission;

    if (journey != null) {
      mission = journey.missions.firstWhere(
        (m) => m.id == widget.missionId,
        orElse: () => journey.missions.first,
      );
    }

    if (journey == null || mission == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Mission'),
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
        ),
        body: const Center(child: Text('Mission not found')),
      );
    }

    final m = mission;

    // Hydrate saved choices (index-keyed) once we have mission
    _hydrateChoices(m);

    final totalCards = m.cards.length;
    final hasCards = totalCards > 0;

    final safeIndex = _cardIndex.clamp(0, hasCards ? totalCards - 1 : 0);
    if (safeIndex != _cardIndex) _cardIndex = safeIndex;

    final isLastCard = !hasCards || safeIndex == totalCards - 1;
    final key = _cardKey(safeIndex);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mission ${m.missionNumber}'),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.title,
              style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              m.subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),

            if (m.requiresPartnerPresent)
              _InfoBanner(
                icon: Icons.groups_outlined,
                title: 'Do this with your partner present',
                message: 'This mission works best when your partner is there with you.',
              ),
            if (m.requiresPartnerPresent) const SizedBox(height: 12),

            _InfoBanner(
              icon: Icons.schedule_outlined,
              title: '${m.timeBoxMinutes} minutes',
              message: 'Keep it short. Finish the action, not a long discussion.',
            ),

            const SizedBox(height: 14),

            if (hasCards) _CardsProgressHeader(index: safeIndex, total: totalCards),

            const SizedBox(height: 12),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: hasCards
                    ? _MissionCardRenderer(
                        key: ValueKey('card_$safeIndex'),
                        cardKey: key,
                        journeyId: widget.journeyId,
                        missionId: widget.missionId,
                        card: m.cards[safeIndex],
                        selectedChoice: _choiceSelections[key],
                        onSelectChoice: (cardKey, option) async {
                          final svc = ref.read(journeyMissionResponseServiceProvider);
                          await svc.saveChoice(
                            journeyId: widget.journeyId,
                            missionId: widget.missionId,
                            cardKey: cardKey,
                            selectedOption: option,
                          );
                          setState(() => _choiceSelections[cardKey] = option);
                        },
                      )
                    : _CardShell(
                        child: Text(
                          'No cards found for this mission.',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 14),

            if (!isLastCard) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: safeIndex <= 0 ? null : () => setState(() => _cardIndex = safeIndex - 1),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _cardIndex = safeIndex + 1),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Outcome',
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _OutcomeButtons(
                onDidIt: () async {
                  final svc = ref.read(journeyProgressServiceProvider);
                  await svc.markMissionCompleted(widget.journeyId, m.id);
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                onNotYet: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No worries. Come back when you’re ready.')),
                  );
                },
                onFailed: () => setState(() => _failed = true),
              ),
              if (_failed) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final progressSvc = ref.read(journeyProgressServiceProvider);
                    await progressSvc.resetMission(widget.journeyId, m.id);

                    final responseSvc = ref.read(journeyMissionResponseServiceProvider);
                    await responseSvc.clearMission(journeyId: widget.journeyId, missionId: widget.missionId);

                    if (!mounted) return;
                    setState(() {
                      _failed = false;
                      _choiceSelections.clear();
                      _hydratedCardKeys.clear();
                      _cardIndex = 0;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reset. Try again when you’re ready.')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CardsProgressHeader extends StatelessWidget {
  final int index;
  final int total;

  const _CardsProgressHeader({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    final current = index + 1;

    return Row(
      children: [
        Text(
          'Card $current of $total',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Row(
          children: List.generate(
            total.clamp(0, 8),
            (i) {
              final active = i == index;
              return Container(
                width: active ? 10 : 7,
                height: 7,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OutcomeButtons extends StatelessWidget {
  final VoidCallback onDidIt;
  final VoidCallback onNotYet;
  final VoidCallback onFailed;

  const _OutcomeButtons({
    required this.onDidIt,
    required this.onNotYet,
    required this.onFailed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: onDidIt,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('I did it'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onNotYet,
          icon: const Icon(Icons.schedule_outlined),
          label: const Text('Not yet'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onFailed,
          icon: const Icon(Icons.rotate_left_outlined),
          label: const Text('I didn’t do it'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _MissionCardRenderer extends StatelessWidget {
  final String cardKey;
  final String journeyId;
  final String missionId;
  final MissionCardV1 card;

  final String? selectedChoice;
  final Future<void> Function(String cardKey, String option) onSelectChoice;

  const _MissionCardRenderer({
    super.key,
    required this.cardKey,
    required this.journeyId,
    required this.missionId,
    required this.card,
    required this.selectedChoice,
    required this.onSelectChoice,
  });

  @override
  Widget build(BuildContext context) {
    final title = card.title;
    final leftIcon = iconFromKey(card.icon);

    switch (card.type) {
      case 'mission_card':
      case 'tip_card':
      case 'instruction_card':
        return _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(leftIcon, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              if ((card.text ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(card.text!, style: AppTextStyles.bodyMedium.copyWith(height: 1.35)),
              ],
              if ((card.bullets ?? const []).isNotEmpty) ...[
                const SizedBox(height: 10),
                ...card.bullets!.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(b, style: AppTextStyles.bodyMedium.copyWith(height: 1.35))),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        );

      case 'choice_card':
        final options = (card.options ?? const <String>[]);
        return _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(leftIcon, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              if ((card.prompt ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(card.prompt!, style: AppTextStyles.bodyMedium.copyWith(height: 1.35)),
              ],
              const SizedBox(height: 10),
              ...options.map((o) {
                final isSelected = selectedChoice == o;
                return InkWell(
                  onTap: () => onSelectChoice(cardKey, o),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.55) : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 20,
                          color: isSelected ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(o, style: AppTextStyles.bodyMedium.copyWith(height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );

      default:
        return _CardShell(
          child: Text(
            '[Unsupported card type: ${card.type}]',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          ),
        );
    }
  }
}
