import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/features/stories/data/story_repository.dart';
import 'package:nexus_app_min_test/features/stories/domain/story_models.dart';
import 'package:nexus_app_min_test/features/stories/presentation/screens/story_poll_screen.dart';

class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

          return _StoryOfWeekView(story: story);
        },
      ),
    );
  }
}

class _StoryOfWeekView extends StatelessWidget {
  final Story story;
  const _StoryOfWeekView({required this.story});

  @override
  Widget build(BuildContext context) {
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
          height: 48,
          child: ElevatedButton(
            onPressed: () {
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
          'Guests can read stories. Voting/results are for signed-in users (dev bypass available).',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
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
          // Subtle gradient to improve text readability on bright images.
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String text;
  const _CheckRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String text;
  const _ChipPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
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
