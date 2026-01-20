import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nexus_app_min_test/features/stories/data/story_repository.dart';
import 'package:nexus_app_min_test/features/stories/domain/story_models.dart';
import 'package:nexus_app_min_test/features/stories/presentation/screens/story_poll_screen.dart';
import 'package:nexus_app_min_test/features/stories/providers/story_reactions_provider.dart';

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const repo = StoryRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Story of the Week')),
      body: FutureBuilder<Story?>(
        future: repo.loadCurrentStory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }
          final story = snapshot.data;
          if (story == null) {
            return const Center(child: Text('No story published yet.'));
          }

          // TODO: Replace this with your real signed-in/guest detection.
          // For now, keeping it FALSE prevents guest interactions (like/comment/share).
          final canInteract = false;

          return _StoryOfWeekView(story: story, canInteract: canInteract);
        },
      ),
    );
  }
}

class _StoryOfWeekView extends ConsumerWidget {
  final Story story;
  final bool canInteract;

  const _StoryOfWeekView({required this.story, required this.canInteract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _HeroCover(
          imageAsset: story.heroImageAsset,
          title: story.title,
          chips: Row(
            children: [
              _ChipPill(text: story.category),
              const SizedBox(width: 8),
              _ChipPill(text: '${story.readTimeMins} min read'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        _Card(
          child: Text(
            story.intro,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ),
        const SizedBox(height: 14),

        ...story.sections.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SectionCard(heading: s.heading, body: s.body),
          ),
        ),

        const SizedBox(height: 6),
        Text(
          story.takeawayTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child:
              story.takeaways.isEmpty
                  ? Text('Coming soon.', style: theme.textTheme.bodyMedium)
                  : Column(
                    children:
                        story.takeaways.map((t) => _CheckRow(text: t)).toList(),
                  ),
        ),

        const SizedBox(height: 18),
        Text(
          'Reflection',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(story.reflectionPrompt, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              TextField(
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Write your thoughts here…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tip: you can keep this private. Later we’ll save it on-device (and sync when you sign in).',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // ✅ Reactions card placed AFTER story content, BEFORE poll
        const SizedBox(height: 18),
        _StoryActionsCard(story: story, canInteract: canInteract),

        const SizedBox(height: 18),
        Text(
          'Weekly Poll',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.poll),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  canInteract
                      ? 'Share your answer (vote to see results).'
                      : 'Create an account to vote and see results.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (!canInteract) {
                _showGuestGateDialog(context);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryPollScreen(storyId: story.id),
                ),
              );
            },
            child: Text(story.pollCtaText),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Guests can read stories. Voting/results are for signed-in users.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StoryActionsCard extends ConsumerWidget {
  final Story story;
  final bool canInteract;

  const _StoryActionsCard({required this.story, required this.canInteract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions = ref.watch(storyReactionsProvider);
    final controller = ref.read(storyReactionsProvider.notifier);

    final liked = reactions.likedStoryIds.contains(story.id);
    final commentsCount =
        (reactions.commentsByStoryId[story.id] ?? const []).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Did you enjoy this story?',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionChip(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  label: liked ? 'Liked' : 'Like',
                  onTap: () {
                    if (!canInteract) {
                      _showGuestGateDialog(context);
                      return;
                    }
                    controller.toggleLike(story.id);
                  },
                ),
                const SizedBox(width: 10),
                _ActionChip(
                  icon: Icons.mode_comment_outlined,
                  label:
                      commentsCount == 0
                          ? 'Comment'
                          : 'Comments ($commentsCount)',
                  onTap:
                      () =>
                          _showCommentsSheet(context, ref, story, canInteract),
                ),
                const SizedBox(width: 10),
                _ActionChip(
                  icon: Icons.ios_share,
                  label: 'Share',
                  onTap: () {
                    if (!canInteract) {
                      _showGuestGateDialog(context);
                      return;
                    }
                    _shareStory(story);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              canInteract
                  ? 'Likes and comments will become public when accounts are fully enabled.'
                  : 'Create an account to like, comment, share, and vote.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static void _shareStory(Story story) {
    final text =
        'Story of the Week: ${story.title}\n\n'
        '${story.intro}\n\n'
        'Shared from Nexus.';
    Share.share(text);
  }

  static Future<void> _showCommentsSheet(
    BuildContext context,
    WidgetRef ref,
    Story story,
    bool canInteract,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final controller = ref.read(storyReactionsProvider.notifier);
            final reactions = ref.watch(storyReactionsProvider);
            final comments = reactions.commentsByStoryId[story.id] ?? const [];

            final input = TextEditingController();

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Comments',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'No comments yet.',
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: comments.length,
                          separatorBuilder:
                              (_, __) => const Divider(height: 18),
                          itemBuilder: (c, i) {
                            final cm = comments[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.account_circle_outlined,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(cm.text),
                                      const SizedBox(height: 4),
                                      Text(
                                        _fmtTime(cm.createdAt),
                                        style:
                                            Theme.of(ctx).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed:
                                      canInteract
                                          ? () => controller.deleteComment(
                                            story.id,
                                            cm.id,
                                          )
                                          : null,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!canInteract)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showGuestGateDialog(context);
                          },
                          child: const Text('Create an account to comment'),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: input,
                              decoration: const InputDecoration(
                                hintText: 'Write a comment…',
                                border: OutlineInputBorder(),
                              ),
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () {
                              controller.addComment(story.id, input.text);
                              input.clear();
                              FocusScope.of(ctx).unfocus();
                            },
                            child: const Text('Send'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m';
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Error: $error'));
  }
}

Future<void> _showGuestGateDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Create an account'),
          content: const Text(
            'Create an account to like, comment, share, and vote on polls.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed('/signup');
              },
              child: const Text('Create account'),
            ),
          ],
        ),
  );
}

class _HeroCover extends StatelessWidget {
  final String imageAsset;
  final String title;
  final Widget chips;

  const _HeroCover({
    required this.imageAsset,
    required this.title,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chips,
                const SizedBox(height: 10),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String heading;
  final String body;
  const _SectionCard({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String text;
  const _ChipPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String text;
  const _CheckRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
