import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nexus_app_min_test/core/models/story_model.dart' hide Story;
import 'package:nexus_app_min_test/core/theme/theme.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 20,
        title: Text(
          'Story of the Week',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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

          // Check if user is signed in via Firebase Auth
          final canInteract = FirebaseAuth.instance.currentUser != null;

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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _HeroCover(
          imagePath: story.heroImageAsset,
          title: story.title,
          chips: Row(
            children: [
              _ChipPill(text: story.category),
              const SizedBox(width: 8),
              _ChipPill(text: '${story.readTimeMins} min read'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _Card(
          child: Text(
            story.intro,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 16),

        ...story.sections.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _SectionCard(heading: s.heading, body: s.body),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          story.takeawayTitle,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child:
              story.takeaways.isEmpty
                  ? Text(
                    'Coming soon.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                  : Column(
                    children:
                        story.takeaways.map((t) => _CheckRow(text: t)).toList(),
                  ),
        ),

        // ✅ Reactions card placed AFTER story content, BEFORE poll
        const SizedBox(height: 18),
        _StoryActionsCard(story: story, canInteract: canInteract),

        const SizedBox(height: 18),
        Text(
          'Weekly Poll',
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
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
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
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
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
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

    controller.ensureStory(story.id);

    final liked = controller.isLiked(story.id);
    final likeCount = reactions.engagementByStoryId[story.id]?.likeCount ?? 0;
    final commentsCount =
        reactions.engagementByStoryId[story.id]?.commentCount ??
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
                  label:
                      liked
                          ? 'Liked ($likeCount)'
                          : likeCount > 0
                              ? 'Like ($likeCount)'
                              : 'Like',
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
                    controller.incrementShare(story.id);
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

            controller.ensureStory(story.id);

            final input = TextEditingController();
            final replyTarget = ValueNotifier<StoryComment?>(null);
            final expandedReplies = ValueNotifier<Set<String>>({});

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
                    ValueListenableBuilder<StoryComment?>(
                      valueListenable: replyTarget,
                      builder: (context, replyTo, __) {
                        List<StoryComment> topLevel = comments
                            .where((c) => !c.isReply)
                            .toList()
                          ..sort((a, b) {
                            final likeCmp = b.likeCount.compareTo(a.likeCount);
                            if (likeCmp != 0) return likeCmp;
                            return b.createdAt.compareTo(a.createdAt);
                          });
                        final repliesByParent = <String, List<StoryComment?>>{};
                        for (final cm in comments.where((c) => c.isReply)) {
                          final key = cm.parentId ?? '';
                          repliesByParent.putIfAbsent(key, () => []);
                          repliesByParent[key]!.add(cm);
                        }
                        for (final entry in repliesByParent.entries) {
                          entry.value.sort(
                            (a, b) => (a?.createdAt ?? DateTime.now())
                                .compareTo(b?.createdAt ?? DateTime.now()),
                          );
                        }

                        return Column(
                          children: [
                            if (comments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  'No comments yet.',
                                  style: Theme.of(ctx).textTheme.bodyMedium,
                                ),
                              )
                            else
                              SizedBox(
                                height: MediaQuery.of(ctx).size.height * 0.6,
                                child: ListView.separated(
                                  itemCount: topLevel.length,
                                  separatorBuilder:
                                      (_, __) => const Divider(height: 18),
                                  itemBuilder: (c, i) {
                                    final cm = topLevel[i];
                                    final replies = repliesByParent[cm.id] ?? [];
                                    final liked = controller.isCommentLiked(
                                      story.id,
                                      cm.id,
                                    );
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                  Text(
                                                    cm.userName,
                                                    style: Theme.of(ctx)
                                                        .textTheme
                                                        .labelLarge,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(cm.text),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        _fmtTime(cm.createdAt),
                                                        style: Theme.of(ctx)
                                                            .textTheme
                                                            .bodySmall,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        '${cm.likeCount} likes',
                                                        style: Theme.of(ctx)
                                                            .textTheme
                                                            .bodySmall,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      TextButton(
                                                        style: TextButton
                                                            .styleFrom(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          minimumSize:
                                                              Size.zero,
                                                          tapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                        ),
                                                        onPressed: () {
                                                          if (!canInteract) {
                                                            _showGuestGateDialog(
                                                              context,
                                                            );
                                                            return;
                                                          }
                                                          replyTarget.value = cm;
                                                        },
                                                        child: const Text(
                                                          'Reply',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      TextButton.icon(
                                                        style: TextButton
                                                            .styleFrom(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          minimumSize:
                                                              Size.zero,
                                                          tapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                        ),
                                                        onPressed: () {
                                                          if (!canInteract) {
                                                            _showGuestGateDialog(
                                                              context,
                                                            );
                                                            return;
                                                          }
                                                          controller
                                                              .toggleCommentLike(
                                                            story.id,
                                                            cm.id,
                                                          );
                                                        },
                                                        icon: Icon(
                                                          liked
                                                              ? Icons.favorite
                                                              : Icons
                                                                  .favorite_border,
                                                          size: 16,
                                                        ),
                                                        label: const Text('Like'),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (canInteract)
                                              IconButton(
                                                tooltip: 'Delete',
                                                onPressed: () => controller
                                                    .deleteComment(
                                                  story.id,
                                                  cm.id,
                                                ),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (replies.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          ValueListenableBuilder<Set<String>>(
                                            valueListenable: expandedReplies,
                                            builder: (context, expanded, _) {
                                              final isExpanded =
                                                  expanded.contains(cm.id);
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  TextButton(
                                                    style: TextButton.styleFrom(
                                                      padding:
                                                          EdgeInsets.zero,
                                                      minimumSize: Size.zero,
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    onPressed: () {
                                                      final next = Set<String>
                                                          .from(expanded);
                                                      if (isExpanded) {
                                                        next.remove(cm.id);
                                                      } else {
                                                        next.add(cm.id);
                                                      }
                                                      expandedReplies.value =
                                                          next;
                                                    },
                                                    child: Text(
                                                      isExpanded
                                                          ? 'Hide replies'
                                                          : 'View ${replies.length} repl${replies.length == 1 ? 'y' : 'ies'}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(ctx)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isExpanded)
                                                    Column(
                                                      children: replies
                                                          .map(
                                                            (rc) => Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                left: 32,
                                                                top: 8,
                                                              ),
                                                              child: rc == null
                                                                  ? const SizedBox()
                                                                  : Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .account_circle_outlined,
                                                                size: 18,
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      rc.userName,
                                                                      style: Theme
                                                                              .of(
                                                                        ctx,
                                                                      )
                                                                          .textTheme
                                                                          .labelMedium,
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 2,
                                                                    ),
                                                                    Text(
                                                                      rc.text,
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 4,
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        Text(
                                                                          _fmtTime(
                                                                            rc.createdAt,
                                                                          ),
                                                                          style: Theme.of(
                                                                            ctx,
                                                                          )
                                                                              .textTheme
                                                                              .bodySmall,
                                                                        ),
                                                                        const SizedBox(
                                                                          width: 12,
                                                                        ),
                                                                        Text(
                                                                          '${rc.likeCount} likes',
                                                                          style: Theme.of(
                                                                            ctx,
                                                                          )
                                                                              .textTheme
                                                                              .bodySmall,
                                                                        ),
                                                                        const SizedBox(
                                                                          width: 8,
                                                                        ),
                                                                        TextButton
                                                                            .icon(
                                                                          style: TextButton
                                                                              .styleFrom(
                                                                            padding:
                                                                                EdgeInsets.zero,
                                                                            minimumSize:
                                                                                Size.zero,
                                                                            tapTargetSize:
                                                                                MaterialTapTargetSize.shrinkWrap,
                                                                          ),
                                                                          onPressed:
                                                                              () {
                                                                            if (!canInteract) {
                                                                              _showGuestGateDialog(
                                                                                context,
                                                                              );
                                                                              return;
                                                                            }
                                                                            controller.toggleCommentLike(
                                                                              story.id,
                                                                              rc.id,
                                                                            );
                                                                          },
                                                                          icon:
                                                                              Icon(
                                                                            controller.isCommentLiked(
                                                                              story.id,
                                                                              rc.id,
                                                                            )
                                                                                ? Icons.favorite
                                                                                : Icons.favorite_border,
                                                                            size:
                                                                                14,
                                                                          ),
                                                                          label:
                                                                              const Text(
                                                                            'Like',
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                  ),
                                                )
                                                .toList(),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
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
                                  child:
                                      const Text('Create an account to comment'),
                                ),
                              )
                            else ...[
                              if (replyTo != null)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Replying to ${replyTo.userName}',
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () => replyTarget.value = null,
                                      ),
                                    ],
                                  ),
                                ),
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
                                      if (replyTo != null) {
                                        controller.addReply(
                                          story.id,
                                          replyTo.id,
                                          input.text,
                                        );
                                      } else {
                                        controller.addComment(
                                          story.id,
                                          input.text,
                                        );
                                      }
                                      input.clear();
                                      replyTarget.value = null;
                                      FocusScope.of(ctx).unfocus();
                                    },
                                    child: const Text('Send'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
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
  final String imagePath;
  final String title;
  final Widget chips;

  const _HeroCover({
    required this.imagePath,
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
            child: _AdaptiveStoryImage(
              imagePath: imagePath,
              placeholder:
                  'assets/images/stories/placeholder_couple.jpg',
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

class _AdaptiveStoryImage extends StatelessWidget {
  final String imagePath;
  final String placeholder;

  const _AdaptiveStoryImage({required this.imagePath, required this.placeholder});

  bool get _isRemote => imagePath.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isRemote) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          placeholder,
          fit: BoxFit.cover,
        ),
      );
    }

    final asset = imagePath.isNotEmpty ? imagePath : placeholder;
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        placeholder,
        fit: BoxFit.cover,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
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
