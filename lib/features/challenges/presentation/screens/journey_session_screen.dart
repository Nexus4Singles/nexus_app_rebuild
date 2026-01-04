import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/config_loader_service.dart';
import '../../../../core/session/effective_relationship_status_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/guest_guard.dart';
import '../../../../core/models/journey_model.dart';

class JourneySessionScreen extends ConsumerStatefulWidget {
  final String journeyId;
  final int sessionNumber;

  const JourneySessionScreen({
    super.key,
    required this.journeyId,
    required this.sessionNumber,
  });

  @override
  ConsumerState<JourneySessionScreen> createState() =>
      _JourneySessionScreenState();
}

class _JourneySessionScreenState extends ConsumerState<JourneySessionScreen> {
  final Map<String, dynamic> _answers = {};

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(effectiveRelationshipStatusProvider) ??
        RelationshipStatus.singleNeverMarried;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Session ${widget.sessionNumber}'),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: ConfigLoaderService().getJourneyCatalogForStatus(status),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Unable to load session'));
          }

          final catalog = snapshot.data!;
          final product = catalog.findProduct(widget.journeyId);

          if (product == null) {
            return const Center(child: Text('Challenge not found'));
          }

          final session = product.getSession(widget.sessionNumber);

          if (session == null) {
            return const Center(child: Text('Session not found'));
          }

          final isFree = session.isFree;
          final steps = session.steps;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ Do NOT show session.prompt — steps already contain the prompt(s).
                Expanded(
                  child: ListView.separated(
                    itemCount: steps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      return _SessionStepRendererWidget(
                        step: step,
                        onChanged: (value) {
                          setState(() {
                            _answers[step.stepId] = value;
                          });
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (isFree || widget.sessionNumber <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Completed (TODO)')),
                        );
                        return;
                      }

                      GuestGuard.requireSignedIn(
                        context,
                        ref,
                        title: 'Create an account to continue',
                        message:
                            'You’re in guest mode. Create an account to unlock sessions and track progress.',
                        primaryText: 'Create an account',
                        onCreateAccount: () =>
                            Navigator.of(context).pushNamed('/signup'),
                        onAllowed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Completed (TODO)')),
                          );
                        },
                      );
                    },
                    child: Text(
                      isFree ? 'Complete session' : 'Unlock + complete',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


class _SessionStepRendererWidget extends StatefulWidget {
  final SessionStep step;
  final void Function(dynamic value)? onChanged;

  const _SessionStepRendererWidget({
    required this.step,
    this.onChanged,
    super.key,
  });

  @override
  State<_SessionStepRendererWidget> createState() => _SessionStepRendererWidgetState();
}

class _SessionStepRendererWidgetState extends State<_SessionStepRendererWidget> {
  dynamic selected;

  List<String> _normalizeOptions(List<String>? raw) {
    if (raw == null) return [];

    final out = <String>[];

    for (final item in raw) {
      final text = item.trim();
      if (text.isEmpty) continue;

      // split (A) ...(B) ... style
      final matches = RegExp(r'\([A-Za-z0-9]+\)\s*([^()]+)').allMatches(text);
      if (matches.isNotEmpty) {
        for (final m in matches) {
          out.add(m.group(1)!.trim());
        }
        continue;
      }

      // split pipe format: A | B | C
      if (text.contains('|')) {
        out.addAll(
          text.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
        continue;
      }

      out.add(text);
    }

    
  // Remove list prefixes like "1)", "1.", "(1)", "-", "•"
  final cleaned = out.map((s) {
    var t = s.trim();
    t = t.replaceFirst(RegExp(r"^(\(?\d+\)?[\.)]\s*)"), "");
    t = t.replaceFirst(RegExp(r"^[-•]\s*"), "");
    return t.trim();
  }).where((s) => s.isNotEmpty).toList();

  return cleaned;
}

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final ui = (step.ui ?? step.responseType ?? '').toLowerCase();
    final prompt = (step.content ?? '').trim();

    final options = _normalizeOptions(step.options);

    // Prompt text
    final promptWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((step.title).trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                step.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          if (prompt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                prompt,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
              ),
            ),
        ],
      );

    // === SCALE 3 ===
    if (ui.contains('scale_3')) {
      final scaleOptions = options.isNotEmpty ? options : ['Low', 'Neutral', 'High'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          promptWidget,
          ...scaleOptions.map(
            (o) => RadioListTile<String>(
              value: o,
              groupValue: selected,
              onChanged: (v) {
                setState(() => selected = v);
                widget.onChanged?.call(v);
              },
              title: Text(o),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      );
    }

    // === SINGLE SELECT ===
    if (ui.contains('single') || ui.contains('radio')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          promptWidget,
          ...options.map(
            (o) => RadioListTile<String>(
              value: o,
              groupValue: selected,
              onChanged: (v) {
                setState(() => selected = v);
                widget.onChanged?.call(v);
              },
              title: Text(o),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      );
    }

    // === MULTI SELECT ===
    if (ui.contains('multi') || ui.contains('chips')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          promptWidget,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options
                .map(
                  (o) => ChoiceChip(
                    label: Text(o),
                    selected: false,
                    onSelected: (_) => widget.onChanged?.call(o),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    // === TEXT INPUT ===
    if (ui.contains('text') || ui.contains('reflection') || ui.contains('journal')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          promptWidget,
          TextField(
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: step.placeholder ?? 'Write here...',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => widget.onChanged?.call(v),
          ),
        ],
      );
    }

    // Fallback
    return Text(prompt.isNotEmpty ? prompt : '(No content)');
  }
}
