import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/models/story_model.dart' as remote;
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';
import 'package:nexus_app_min_test/core/providers/firestore_service_provider.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';
import 'package:nexus_app_min_test/features/stories/data/poll_repository.dart';
import 'package:nexus_app_min_test/features/stories/data/story_repository.dart';
import 'package:nexus_app_min_test/features/stories/domain/poll_models.dart';

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
        title: Text(
          'Weekly Poll',
          style: AppTextStyles.headlineLarge.copyWith(
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
    final theme = Theme.of(context);

    return ListView(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Poll',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(poll.question, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 10),
              Text(
                'Guests can read stories, but voting/results are for signed-in users.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            children: [
              ...poll.options.map(
                (o) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.35),
                    ),
                  ),
                  child: RadioListTile<String>(
                    value: o.id,
                    groupValue: selectedOptionId,
                    onChanged: onSelect,
                    title: Text(o.text),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (selectedOptionId == null || selectedOptionId!.isEmpty)
                          ? null
                          : onVote,
                  child: const Text('Vote to see results'),
                ),
              ),
            ],
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
    final theme = Theme.of(context);
    final counts = aggregate?.optionCounts ?? const <String, int>{};
    final total = aggregate?.totalVotes ?? 0;
    final safeTotal = total == 0 ? 1 : total;
    final insight = poll.insights[votedOptionId] ?? 'Thanks for sharing.';

    return ListView(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Poll Results',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(poll.question, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 6),
              Text(
                total == 0 ? 'Be the first to vote.' : 'Total votes: $total',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            children: [
              ...poll.options.map((o) {
                final c = counts[o.id] ?? 0;
                final pct = (c / safeTotal) * 100;
                final isMine = o.id == votedOptionId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isMine ? '✓ ${o.text}' : o.text,
                              style: TextStyle(
                                fontWeight:
                                    isMine ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text('${pct.toStringAsFixed(0)}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: pct / 100),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(insight, style: theme.textTheme.bodyMedium)),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
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
