import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/features/stories/data/story_repository.dart';
import 'package:nexus_app_min_test/features/stories/domain/story_models.dart';
import 'package:nexus_app_min_test/features/stories/presentation/screens/story_poll_screen.dart';

class StoryDetailScreen extends StatelessWidget {
  final String storyId;
  const StoryDetailScreen({super.key, required this.storyId});

  @override
  Widget build(BuildContext context) {
    const repo = StoryRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Story')),
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

          final theme = Theme.of(context);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: _AdaptiveDetailImage(
                    imagePath: story.heroImageAsset,
                    placeholder: 'assets/images/stories/placeholder_couple.jpg',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Pill(text: story.category),
                  const SizedBox(width: 8),
                  _Pill(text: '${story.readTimeMins} min read'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                story.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(story.intro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 18),

              ...story.sections.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _Section(heading: s.heading, body: s.body),
                );
              }),

              const SizedBox(height: 4),
              Text(
                story.takeawayTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (story.takeaways.isEmpty)
                Text('Coming soon.', style: theme.textTheme.bodyMedium)
              else
                ...story.takeaways.map((t) => _Bullet(text: t)),

              const SizedBox(height: 18),
              Text(
                'Reflection',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.reflectionPrompt,
                      style: theme.textTheme.bodyMedium,
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

              const SizedBox(height: 18),
              Text(
                'Weekly Poll',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _Card(
                child: Row(
                  children: [
                    const Icon(Icons.poll),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Share your answer (vote to see results).',
                        style: theme.textTheme.bodyMedium,
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: theme.textTheme.bodyMedium),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
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

class _AdaptiveDetailImage extends StatelessWidget {
  final String imagePath;
  final String placeholder;
  const _AdaptiveDetailImage({required this.imagePath, required this.placeholder});

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

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
