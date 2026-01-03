import 'package:cloud_firestore/cloud_firestore.dart';

class Journey {
  final String id;
  final String title;
  final String description;
  final String? coverImageUrl;
  final int sessionCount;
  final bool premium;

  const Journey({
    required this.id,
    required this.title,
    required this.description,
    this.coverImageUrl,
    required this.sessionCount,
    required this.premium,
  });

  factory Journey.fromMap(String id, Map<String, dynamic> data) {
    return Journey(
      id: id,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      coverImageUrl: data['coverImageUrl'] as String?,
      sessionCount: (data['sessionCount'] as int?) ?? 1,
      premium: (data['premium'] as bool?) ?? false,
    );
  }
}
