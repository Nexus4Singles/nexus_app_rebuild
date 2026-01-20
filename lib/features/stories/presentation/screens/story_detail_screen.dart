import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/story_repository.dart';
import '../../domain/story_models.dart';

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
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final story = snapshot.data;
          if (story == null) {
            return const Center(child: Text('Story not found.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                story.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text('${story.category} • ${story.readTimeMins} min read'),
              const SizedBox(height: 16),
              Text(story.intro, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _share(story),
                icon: const Icon(Icons.ios_share),
                label: const Text('Share story'),
              ),
            ],
          );
        },
      ),
    );
  }

  static void _share(Story story) {
    final text =
        'Story: ${story.title}\\n\\n'
        '${story.intro}\\n\\n'
        'Shared from Nexus.';
    Share.share(text);
  }
}
