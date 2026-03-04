import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nexus_app_v2/core/models/story_model.dart' hide Story;
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/router/safe_nav.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'package:nexus_app_v2/features/stories/data/story_repository.dart';
import 'package:nexus_app_v2/features/stories/domain/story_models.dart';
import 'package:nexus_app_v2/features/stories/presentation/screens/story_poll_screen.dart';
import 'package:nexus_app_v2/features/stories/providers/story_reactions_provider.dart';

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const repo = StoryRepository();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        leading: Visibility(
          visible: !ref.watch(userIsMarriedProvider),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => navigateBackToHome(context),
          ),
        ),
        titleSpacing: 20,
        title: Text(
          'Stories',
          style: AppTextStyles.headlineSmall.copyWith(
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeroCover(
          imagePath: story.heroImageAsset,
          title: story.title,
          chips: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...story.tags.map((tag) => _ChipPill(text: tag)),
              if (story.tags.isEmpty) _ChipPill(text: story.category),
              _ChipPill(text: '${story.readTimeMins} min read'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _Card(
          child: Text(
            story.intro,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextPrimary(context),
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 12),

        ...story.sections.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SectionCard(heading: s.heading, body: s.body),
          ),
        ),

        const SizedBox(height: 14),
        Text(
          story.takeawayTitle,
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _Card(
          child:
              story.takeaways.isEmpty
                  ? Text(
                    'Coming soon.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
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

        const SizedBox(height: 14),
        Text(
          'Poll',
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
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
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.poll_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canInteract
                            ? 'Share your perspective'
                            : 'Create an account to vote',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        canInteract
                            ? 'Vote to see how others responded.'
                            : 'Sign up to vote and see poll results.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
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
    final engagementCommentCount =
        reactions.engagementByStoryId[story.id]?.commentCount;
    final actualCommentCount =
        (reactions.commentsByStoryId[story.id] ?? const []).length;
    final commentsCount =
        (engagementCommentCount == null || engagementCommentCount < 0)
            ? actualCommentCount
            : engagementCommentCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Did you enjoy this story?',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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
                        () => _showCommentsSheet(
                          context,
                          ref,
                          story,
                          canInteract,
                        ),
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
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static void _shareStory(Story story) {
    final text =
        'Stories: ${story.title}\n\n'
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
        return _CommentsSheetContent(story: story, canInteract: canInteract);
      },
    );
  }
}

/// Stateful widget for managing comment sheet resources properly
class _CommentsSheetContent extends ConsumerStatefulWidget {
  final Story story;
  final bool canInteract;

  const _CommentsSheetContent({required this.story, required this.canInteract});

  @override
  ConsumerState<_CommentsSheetContent> createState() =>
      _CommentsSheetContentState();
}

class _CommentsSheetContentState extends ConsumerState<_CommentsSheetContent> {
  late final TextEditingController _input;
  late final ValueNotifier<StoryComment?> _replyTarget;
  late final ValueNotifier<Set<String>> _expandedReplies;
  late final ValueNotifier<bool> _isPosting;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController();
    _replyTarget = ValueNotifier<StoryComment?>(null);
    _expandedReplies = ValueNotifier<Set<String>>({});
    _isPosting = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _input.dispose();
    _replyTarget.dispose();
    _expandedReplies.dispose();
    _isPosting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(storyReactionsProvider.notifier);
    final reactions = ref.watch(storyReactionsProvider);
    final comments = reactions.commentsByStoryId[widget.story.id] ?? const [];
    final currentUser = FirebaseAuth.instance.currentUser;

    controller.ensureStory(widget.story.id);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Comments',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<StoryComment?>(
              valueListenable: _replyTarget,
              builder: (innerContext, replyTo, __) {
                List<StoryComment> topLevel =
                    comments.where((c) => !c.isReply).toList()..sort((a, b) {
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
                    (a, b) => (a?.createdAt ?? DateTime.now()).compareTo(
                      b?.createdAt ?? DateTime.now(),
                    ),
                  );
                }

                return Column(
                  children: [
                    if (comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'No comments yet.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              (MediaQuery.of(context).size.height -
                                  MediaQuery.of(context).viewInsets.bottom) *
                              0.5,
                          minHeight: 100,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: topLevel.length,
                          separatorBuilder:
                              (_, __) => const Divider(height: 18),
                          itemBuilder: (c, i) {
                            final cm = topLevel[i];
                            final replies = repliesByParent[cm.id] ?? [];
                            final liked = controller.isCommentLiked(
                              widget.story.id,
                              cm.id,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                          Text(
                                            cm.userName,
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            cm.text,
                                            style: AppTextStyles.bodySmall,
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                _fmtTime(cm.createdAt),
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color:
                                                          AppColors.getTextSecondary(
                                                            context,
                                                          ),
                                                    ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                '${cm.likeCount} likes',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color:
                                                          AppColors.getTextSecondary(
                                                            context,
                                                          ),
                                                    ),
                                              ),
                                              const SizedBox(width: 12),
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                                onPressed: () {
                                                  if (!widget.canInteract) {
                                                    _showGuestGateDialog(
                                                      context,
                                                    );
                                                    return;
                                                  }
                                                  _replyTarget.value = cm;
                                                },
                                                child: Text(
                                                  'Reply',
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                                onPressed: () {
                                                  if (!widget.canInteract) {
                                                    _showGuestGateDialog(
                                                      context,
                                                    );
                                                    return;
                                                  }
                                                  controller.toggleCommentLike(
                                                    widget.story.id,
                                                    cm.id,
                                                  );
                                                },
                                                icon: Icon(
                                                  liked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  'Like',
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (widget.canInteract &&
                                        currentUser?.uid == cm.userId)
                                      IconButton(
                                        tooltip: 'Delete',
                                        iconSize: 18,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            () => controller.deleteComment(
                                              widget.story.id,
                                              cm.id,
                                            ),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: AppColors.getTextSecondary(
                                            context,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (replies.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ValueListenableBuilder<Set<String>>(
                                    valueListenable: _expandedReplies,
                                    builder: (innerContext, expanded, _) {
                                      final isExpanded = expanded.contains(
                                        cm.id,
                                      );
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Center(
                                            child: TextButton(
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              onPressed: () {
                                                final next = Set<String>.from(
                                                  expanded,
                                                );
                                                if (isExpanded) {
                                                  next.remove(cm.id);
                                                } else {
                                                  next.add(cm.id);
                                                }
                                                _expandedReplies.value = next;
                                              },
                                              child: Text(
                                                isExpanded
                                                    ? 'Hide replies'
                                                    : 'View ${replies.length} repl${replies.length == 1 ? 'y' : 'ies'}',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          if (isExpanded)
                                            Column(
                                              children:
                                                  replies
                                                      .map(
                                                        (rc) => Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 32,
                                                                top: 8,
                                                              ),
                                                          child:
                                                              rc == null
                                                                  ? const SizedBox()
                                                                  : Row(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const Icon(
                                                                        Icons
                                                                            .account_circle_outlined,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Expanded(
                                                                        child: Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text(
                                                                              rc.userName,
                                                                              style: AppTextStyles.caption.copyWith(
                                                                                fontWeight:
                                                                                    FontWeight.w700,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(
                                                                              height:
                                                                                  2,
                                                                            ),
                                                                            Text(
                                                                              rc.text,
                                                                              style:
                                                                                  AppTextStyles.caption,
                                                                            ),
                                                                            const SizedBox(
                                                                              height:
                                                                                  4,
                                                                            ),
                                                                            Row(
                                                                              children: [
                                                                                Text(
                                                                                  _fmtTime(
                                                                                    rc.createdAt,
                                                                                  ),
                                                                                  style: AppTextStyles.caption.copyWith(
                                                                                    color: AppColors.getTextSecondary(
                                                                                      context,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(
                                                                                  width:
                                                                                      12,
                                                                                ),
                                                                                Text(
                                                                                  '${rc.likeCount} likes',
                                                                                  style: AppTextStyles.caption.copyWith(
                                                                                    color: AppColors.getTextSecondary(
                                                                                      context,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(
                                                                                  width:
                                                                                      8,
                                                                                ),
                                                                                TextButton.icon(
                                                                                  style: TextButton.styleFrom(
                                                                                    padding:
                                                                                        EdgeInsets.zero,
                                                                                    minimumSize:
                                                                                        Size.zero,
                                                                                    tapTargetSize:
                                                                                        MaterialTapTargetSize.shrinkWrap,
                                                                                  ),
                                                                                  onPressed: () {
                                                                                    if (!widget.canInteract) {
                                                                                      _showGuestGateDialog(
                                                                                        context,
                                                                                      );
                                                                                      return;
                                                                                    }
                                                                                    controller.toggleCommentLike(
                                                                                      widget.story.id,
                                                                                      rc.id,
                                                                                    );
                                                                                  },
                                                                                  icon: Icon(
                                                                                    controller.isCommentLiked(
                                                                                          widget.story.id,
                                                                                          rc.id,
                                                                                        )
                                                                                        ? Icons.favorite
                                                                                        : Icons.favorite_border,
                                                                                    size:
                                                                                        14,
                                                                                  ),
                                                                                  label: Text(
                                                                                    'Like',
                                                                                    style: AppTextStyles.caption.copyWith(
                                                                                      color:
                                                                                          AppColors.primary,
                                                                                      fontWeight:
                                                                                          FontWeight.w600,
                                                                                    ),
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
                    if (!widget.canInteract)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showGuestGateDialog(context);
                          },
                          child: Text(
                            'Create an account to comment',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Replying to ${replyTo.userName}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _replyTarget.value = null,
                              ),
                            ],
                          ),
                        ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isPosting,
                        builder: (innerContext, posting, _) {
                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  enabled: !posting,
                                  style: AppTextStyles.bodySmall,
                                  decoration: InputDecoration(
                                    hintText: 'Write a comment…',
                                    hintStyle: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.getTextMuted(context),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  minLines: 1,
                                  maxLines: 4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed:
                                    posting
                                        ? null
                                        : () async {
                                          if (_input.text.trim().isEmpty) {
                                            return;
                                          }
                                          _isPosting.value = true;
                                          try {
                                            if (replyTo != null) {
                                              await controller.addReply(
                                                widget.story.id,
                                                replyTo.id,
                                                _input.text,
                                              );
                                            } else {
                                              await controller.addComment(
                                                widget.story.id,
                                                _input.text,
                                              );
                                            }
                                            _input.clear();
                                            _replyTarget.value = null;
                                            FocusScope.of(context).unfocus();
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to post comment: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          } finally {
                                            _isPosting.value = false;
                                          }
                                        },
                                child:
                                    posting
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : Text(
                                          'Send',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
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
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.isNegative) return 'just now';
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks${weeks == 1 ? ' week' : ' weeks'} ago';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months${months == 1 ? ' month' : ' months'} ago';
    }
    final years = (diff.inDays / 365).floor();
    return '$years${years == 1 ? ' year' : ' years'} ago';
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
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _AdaptiveStoryImage(
              imagePath: imagePath,
              placeholder: 'assets/images/stories/placeholder_couple.jpg',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                chips,
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

  const _AdaptiveStoryImage({
    required this.imagePath,
    required this.placeholder,
  });

  bool get _isRemote => imagePath.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isRemote) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => Image.asset(placeholder, fit: BoxFit.cover),
      );
    }

    final asset = imagePath.isNotEmpty ? imagePath : placeholder;
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(placeholder, fit: BoxFit.cover),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String heading;
  final String body;
  const _SectionCard({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(body, style: AppTextStyles.bodySmall.copyWith(height: 1.4)),
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

class _ChipPill extends StatelessWidget {
  final String text;
  const _ChipPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: primary,
          fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
