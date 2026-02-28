import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/app_text_styles.dart';
import 'package:nexus_app_v2/features/stories/data/story_repository.dart';
import 'package:nexus_app_v2/features/stories/domain/story_models.dart';
import 'package:nexus_app_v2/features/stories/presentation/screens/story_poll_screen.dart';

class StoryDetailScreen extends StatelessWidget {
  final String storyId;
  const StoryDetailScreen({super.key, required this.storyId});

  @override
  Widget build(BuildContext context) {
    const repo = StoryRepository();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Story of the Week',
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<Story?>(
        future: repo.loadStoryById(storyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }
          final story = snapshot.data;
          if (story == null) {
            return const Center(child: Text('Story not found.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _AdaptiveDetailImage(
                    imagePath: story.heroImageAsset,
                    placeholder: 'assets/images/stories/placeholder_couple.jpg',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...story.tags.map((tag) => _Pill(text: tag)),
                        if (story.tags.isEmpty) _Pill(text: story.category),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Pill(text: '${story.readTimeMins} min read'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                story.title,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                story.intro,
                style: AppTextStyles.bodySmall.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),

              ...story.sections.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Section(heading: s.heading, body: s.body),
                );
              }),

              Text(
                story.takeawayTitle,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              if (story.takeaways.isEmpty)
                Text('Coming soon.', style: AppTextStyles.bodySmall)
              else
                ...story.takeaways.map((t) => _Bullet(text: t)),

              const SizedBox(height: 12),
              Text(
                'Reflection',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.reflectionPrompt,
                      style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write your thoughts...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'Weekly Poll',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              _Card(
                child: Row(
                  children: [
                    const Icon(Icons.poll),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Share your answer (vote to see results).',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryPollScreen(storyId: storyId),
                      ),
                    );
                  },
                  child: Text(story.pollCtaText),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String heading;
  final String body;
  const _Section({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(body, style: AppTextStyles.bodySmall.copyWith(height: 1.4)),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: AppTextStyles.bodySmall),
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: child,
    );
  }
}

class _AdaptiveDetailImage extends StatelessWidget {
  final String imagePath;
  final String placeholder;
  const _AdaptiveDetailImage({
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

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
      ),
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
          'Failed to load story.\n\n$error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
