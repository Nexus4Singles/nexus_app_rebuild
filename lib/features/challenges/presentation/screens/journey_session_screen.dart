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
            title: Text(
              'Activity ${m.missionNumber}',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: AppColors.background,
            surfaceTintColor: AppColors.background,
            elevation: 0,
            actions: [
              if (totalCards > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.18),
                    ),
                  ),
                  child: Text(
                    '$progressIndex/$totalCards',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
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
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        totalCards == 0
                            ? const Center(
                              child: Text('No cards found for this activity.'),
                            )
                            : _CardShell(
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
              if (showProgress)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$index/$total',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.88),
              height: 1.35,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (!isFirst) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Back'),
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
              child: Text(isLast ? 'Complete' : 'Next'),
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
          text: card.text ?? '',
          bullets: card.bullets,
        );

      case 'choice_card':
        final key = 'card_$cardIndex';
        final selected = choiceSelections[key];
        return _ChoiceCard(
          title: card.title,
          prompt: card.prompt ?? '',
          options: card.options ?? const [],
          selected: selected,
          onSelected: onChoiceSelected,
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
  final String text;
  final List<String>? bullets;

  const _InfoCard({required this.title, required this.text, this.bullets});

  List<String> _splitParagraphs(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const [];
    // Split on blank lines OR single line breaks
    // (we treat each line as a paragraph for breathing space)
    return trimmed
        .split(RegExp(r'\n+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasBullets = bullets != null && bullets!.isNotEmpty;
    final paragraphs = _splitParagraphs(text);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 10),

          if (paragraphs.isNotEmpty)
            ...paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  p,
                  style: AppTextStyles.bodyMedium.copyWith(
                    height: 1.55,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

          if (hasBullets) ...[
            if (paragraphs.isNotEmpty) const SizedBox(height: 2),
            ...bullets!.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        b.trim(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          height: 1.55,
                          color: AppColors.textPrimary,
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
  final String prompt;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ChoiceCard({
    required this.title,
    required this.prompt,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bodyStyle = AppTextStyles.bodyMedium.copyWith(
      height: 1.45,
      color: AppColors.textPrimary,
    );

    final parsedPrompt = _parseRichContent(prompt);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
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
                            ? AppColors.primary.withOpacity(0.14)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.primary.withOpacity(0.55)
                              : AppColors.border,
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.25,
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
                                    : AppColors.border,
                          ),
                        ),
                        child:
                            isSelected
                                ? const Icon(
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
  final lines = raw.split('\n');

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

    // blank line -> paragraph break
    if (trimmed.trim().isEmpty) {
      flushParagraph();
      continue;
    }

    // bullet line?
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

/// Inline renderer supports:
/// ✅ "Label:" bolding at start of line
/// ✅ **bold**
/// ✅ *italic*
List<TextSpan> _buildInlineSpans(String text, TextStyle baseStyle) {
  // First: split by newline so we can bold "Label:" per line
  final lines = text.split('\n');
  final spans = <TextSpan>[];

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];

    final match = RegExp(
      r'^([A-Za-z0-9\s\*\-\(\)]+):\s*(.*)$',
    ).firstMatch(raw.trim());

    if (match != null) {
      final label = match.group(1)!.trim();
      final rest = match.group(2) ?? '';

      spans.add(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: baseStyle.copyWith(fontWeight: FontWeight.w900),
            ),
            ..._buildEmphasisSpans(rest, baseStyle),
          ],
        ),
      );
    } else {
      spans.addAll(_buildEmphasisSpans(raw, baseStyle));
    }

    if (i != lines.length - 1) {
      spans.add(const TextSpan(text: '\n'));
    }
  }

  return spans;
}

/// Supports **bold** and *italic* inline emphasis.
List<TextSpan> _buildEmphasisSpans(String input, TextStyle baseStyle) {
  final spans = <TextSpan>[];

  // Tokenize by **bold** or *italic*
  final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*)');
  final matches = regex.allMatches(input);

  var lastIndex = 0;

  for (final m in matches) {
    if (m.start > lastIndex) {
      spans.add(
        TextSpan(text: input.substring(lastIndex, m.start), style: baseStyle),
      );
    }

    final token = input.substring(m.start, m.end);

    if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
      final inner = token.substring(2, token.length - 2);
      spans.add(
        TextSpan(
          text: inner,
          style: baseStyle.copyWith(fontWeight: FontWeight.w900),
        ),
      );
    } else if (token.startsWith('*') &&
        token.endsWith('*') &&
        token.length > 2) {
      final inner = token.substring(1, token.length - 1);
      spans.add(
        TextSpan(
          text: inner,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    } else {
      spans.add(TextSpan(text: token, style: baseStyle));
    }

    lastIndex = m.end;
  }

  if (lastIndex < input.length) {
    spans.add(TextSpan(text: input.substring(lastIndex), style: baseStyle));
  }

  return spans;
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
