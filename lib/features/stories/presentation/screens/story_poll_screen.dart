import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/models/story_model.dart' as remote;
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/core/providers/firestore_service_provider.dart';
import 'package:nexus_app_v2/core/router/safe_nav.dart';
import 'package:nexus_app_v2/core/services/firestore_service.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/widgets/guest_guard.dart';
import 'package:nexus_app_v2/features/stories/data/poll_repository.dart';
import 'package:nexus_app_v2/features/stories/data/story_repository.dart';
import 'package:nexus_app_v2/features/stories/domain/poll_models.dart';

class StoryPollScreen extends ConsumerStatefulWidget {
  final String storyId;
  const StoryPollScreen({super.key, required this.storyId});

  @override
  ConsumerState<StoryPollScreen> createState() => _StoryPollScreenState();
}

class _StoryPollScreenState extends ConsumerState<StoryPollScreen> {
  final _storyRepo = const StoryRepository();
  final _pollRepo = const PollRepository();

  late final FirestoreService _firestore;

  bool _loading = true;
  String? _error;

  Poll? _poll;

  String? _selectedOptionId;
  String? _userId;

  /// Signed-in users: existing vote or new vote in this session unlocks results.
  bool _hasVotedThisSession = false;
  remote.PollVote? _existingVote;
  remote.PollAggregate? _aggregate;
  StreamSubscription<remote.PollAggregate?>? _aggSub;

  @override
  void initState() {
    super.initState();
    _firestore = ref.read(firestoreServiceProvider);
    _bootstrap();
  }

  @override
  void dispose() {
    _aggSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final story = await _storyRepo.loadStoryById(widget.storyId);
      if (story == null) {
        setState(() {
          _loading = false;
          _error = 'Story not found.';
        });
        return;
      }

      final pollId = story.pollId;
      final poll = await _pollRepo.loadPollById(pollId);
      if (poll == null) {
        setState(() {
          _loading = false;
          _error = 'Poll not found for story.';
        });
        return;
      }

      _userId = ref.read(currentUserIdProvider);

      remote.PollVote? existing;
      if (_userId != null) {
        existing = await _firestore.getUserPollVote(_userId!, poll.id);
      }

      _aggSub = _firestore.watchPollAggregate(poll.id).listen((agg) {
        if (!mounted) return;
        setState(() => _aggregate = agg);
      });

      setState(() {
        _poll = poll;
        _selectedOptionId = existing?.selectedOptionId;
        _existingVote = existing;
        _hasVotedThisSession = existing != null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool get _allowVoting => _userId != null;

  bool get _canShowResults =>
      _allowVoting && (_hasVotedThisSession || _existingVote != null);

  @override
  Widget build(BuildContext context) {
    final poll = _poll;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => navigateBackToHome(context),
        ),
        title: Text(
          'Weekly Poll',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null)
              ? _ErrorState(error: _error!)
              : (poll == null)
              ? const Center(child: Text('Poll unavailable.'))
              : Padding(
                padding: const EdgeInsets.all(16),
                child:
                    _canShowResults
                        ? _ResultsView(
                          poll: poll,
                          votedOptionId:
                              _selectedOptionId ??
                              _existingVote?.selectedOptionId ??
                              '',
                          aggregate: _aggregate,
                        )
                        : _VoteView(
                          poll: poll,
                          selectedOptionId: _selectedOptionId,
                          onSelect:
                              (v) => setState(() => _selectedOptionId = v),
                          onVote: _onVotePressed,
                        ),
              ),
    );
  }

  void _onVotePressed() {
    if (_selectedOptionId == null || _selectedOptionId!.isEmpty) return;

    if (!_allowVoting) {
      GuestGuard.requireSignedIn(
        context,
        ref,
        title: 'Create an account to vote',
        message:
            'You\'re currently in guest mode. Create an account to vote and see poll results.',
        primaryText: 'Create an account',
        onCreateAccount: () => Navigator.of(context).pushNamed('/signup'),
        onAllowed: () async {
          await _voteAndPersist();
        },
      );
      return;
    }

    if (_existingVote != null) {
      setState(() => _hasVotedThisSession = true);
      return;
    }

    _voteAndPersist();
  }

  Future<void> _voteAndPersist() async {
    final poll = _poll;
    final selected = _selectedOptionId;
    final uid = _userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (poll == null || selected == null || selected.isEmpty || uid == null) {
      return;
    }

    final vote = remote.PollVote(
      visitorId: uid,
      pollId: poll.id,
      storyId: widget.storyId,
      userId: uid,
      selectedOptionId: selected,
      inferredTags: const [],
      createdAt: DateTime.now(),
    );

    await _firestore.savePollVote(vote);

    if (!mounted) return;
    setState(() {
      _existingVote = vote;
      _hasVotedThisSession = true;
    });
  }
}

class _VoteView extends StatelessWidget {
  final Poll poll;
  final String? selectedOptionId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onVote;

  const _VoteView({
    required this.poll,
    required this.selectedOptionId,
    required this.onSelect,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = selectedOptionId != null && selectedOptionId!.isNotEmpty;

    return ListView(
      children: [
        // ── Header card with icon + question ──
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.poll_rounded,
                      size: 22,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Weekly Poll',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                poll.question,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Option tiles ──
        ...poll.options.map((o) {
          final isCurrent = o.id == selectedOptionId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => onSelect(o.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color:
                      isCurrent
                          ? cs.primary.withOpacity(0.08)
                          : AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isCurrent
                            ? cs.primary
                            : AppColors.getBorder(context).withOpacity(0.4),
                    width: isCurrent ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isCurrent
                                  ? cs.primary
                                  : AppColors.getBorder(context),
                          width: isCurrent ? 6 : 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        o.text,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.w400,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),

        // ── Vote button ──
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isSelected ? onVote : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Vote to see results'),
          ),
        ),
      ],
    );
  }
}

class _ResultsView extends StatelessWidget {
  final Poll poll;
  final String votedOptionId;
  final remote.PollAggregate? aggregate;

  const _ResultsView({
    required this.poll,
    required this.votedOptionId,
    required this.aggregate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = aggregate?.optionCounts ?? const <String, int>{};
    var total = aggregate?.totalVotes ?? 0;

    if (total == 0 && counts.isNotEmpty) {
      total = counts.values.fold(0, (sum, count) => sum + count);
    }
    if (total == 0 && poll.seedCounts.isNotEmpty) {
      total = poll.seedCounts.values.fold(0, (sum, count) => sum + count);
    }

    final safeTotal = total == 0 ? 1 : total;
    final insight = poll.insights[votedOptionId] ?? 'Thanks for sharing.';

    return ListView(
      children: [
        // ── Header card ──
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.bar_chart_rounded,
                      size: 22,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Poll Results',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          total == 0 ? 'Be the first to vote.' : '$total votes',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                poll.question,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextPrimary(context),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Result bars ──
        _Card(
          child: Column(
            children: [
              ...poll.options.map((o) {
                var c = counts[o.id] ?? poll.seedCounts[o.id] ?? 0;
                final isMine = o.id == votedOptionId;

                if (isMine && c == 0 && counts[o.id] == null && total >= 1) {
                  c = 1;
                }

                final pct =
                    safeTotal > 0
                        ? ((c / safeTotal) * 100).clamp(0.0, 100.0)
                        : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isMine)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.check_circle,
                                size: 16,
                                color: cs.primary,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              o.text,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight:
                                    isMine ? FontWeight.w700 : FontWeight.w500,
                                color:
                                    isMine
                                        ? cs.primary
                                        : AppColors.getTextPrimary(context),
                              ),
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  isMine
                                      ? cs.primary
                                      : AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.getBorder(
                                  context,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (pct / 100).clamp(0.0, 1.0),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      isMine
                                          ? cs.primary
                                          : cs.primary.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Insight card ──
        _Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  size: 18,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.getBorder(context).withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Failed to load poll.\n\n$error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
