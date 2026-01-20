import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String title;
  final String summary;
  final String? coverImageUrl;
  final DateTime? publishedAt;
  final bool isCurrent;

  const Story({
    required this.id,
    required this.title,
    required this.summary,
    this.coverImageUrl,
    this.publishedAt,
    required this.isCurrent,
  });

  factory Story.fromMap(String id, Map<String, dynamic> data) {
    final raw = data['publishedAt'];
    DateTime? published;

    if (raw is Timestamp) {
      published = raw.toDate();
    } else if (raw is DateTime) {
      published = raw;
    }

    return Story(
      id: id,
      title: (data['title'] as String?) ?? '',
      summary: (data['summary'] as String?) ?? '',
      coverImageUrl: data['coverImageUrl'] as String?,
      publishedAt: published,
      isCurrent: (data['isCurrent'] as bool?) ?? false,
    );
  }
}
