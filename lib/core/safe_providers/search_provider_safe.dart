import 'package:flutter_riverpod/flutter_riverpod.dart';

class SafeSearchItem {
  final String title;
  final String subtitle;
  final String routeTitle;

  const SafeSearchItem({
    required this.title,
    required this.subtitle,
    required this.routeTitle,
  });
}

final safeSearchProvider = Provider<List<SafeSearchItem>>((ref) {
  return const [
    SafeSearchItem(
      title: 'Marriage Stories',
      subtitle: 'Weekly content',
      routeTitle: 'Stories',
    ),
    SafeSearchItem(
      title: 'Singles Readiness',
      subtitle: 'Assessments',
      routeTitle: 'Assessment',
    ),
    SafeSearchItem(
      title: 'Challenges',
      subtitle: '3 mins daily',
      routeTitle: 'Challenges',
    ),
  ];
});
