import 'package:flutter_riverpod/flutter_riverpod.dart';

class SafeChallengeItem {
  final String title;
  final String subtitle;
  final String description;

  const SafeChallengeItem({
    required this.title,
    required this.subtitle,
    required this.description,
  });
}

final safeChallengesProvider = Provider<List<SafeChallengeItem>>((ref) {
  return const [
    SafeChallengeItem(
      title: 'Attraction Pulse',
      subtitle: '3 min • FREE',
      description:
          'Pulse check: How clear are you about what you’re looking for in a partner?',
    ),
    SafeChallengeItem(
      title: 'Communication Sprint',
      subtitle: '5 min • Beginner',
      description: 'Improve communication with simple daily prompts.',
    ),
    SafeChallengeItem(
      title: 'Conflict Reset',
      subtitle: '7 min • Intermediate',
      description: 'Learn to reset after tension and rebuild connection.',
    ),
    SafeChallengeItem(
      title: 'Trust Builder',
      subtitle: '4 min • Beginner',
      description: 'Build trust with small consistent actions.',
    ),
  ];
});
