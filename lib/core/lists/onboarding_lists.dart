import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingLists {
  final List<String> hobbies;
  final List<String> desiredQualities;
  final List<String> professions;
  final List<String> educationalLevels;
  final List<String> churches;

  const OnboardingLists({
    required this.hobbies,
    required this.desiredQualities,
    required this.professions,
    required this.educationalLevels,
    required this.churches,
  });

  factory OnboardingLists.fromJson(Map<String, dynamic> json) {
    final lists = (json['lists'] as Map).cast<String, dynamic>();

    List<String> _asStringList(String key) {
      final v = lists[key];
      if (v is List) return v.map((e) => '$e').toList();
      return const [];
    }

    final churches =
        _asStringList('church').where((e) => e.trim().isNotEmpty).toList();
    if (!churches.map((e) => e.toLowerCase()).contains('other')) {
      churches.add('Other');
    }

    return OnboardingLists(
      hobbies: _asStringList('hobbies'),
      desiredQualities: _asStringList('desireQualities'),
      professions: _asStringList('professions'),
      educationalLevels: _asStringList('educationalLevels'),
      churches: churches,
    );
  }
}

final onboardingListsProvider = FutureProvider<OnboardingLists>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/data/nexus1_onboarding_lists.v1.json',
  );
  final decoded = json.decode(raw) as Map<String, dynamic>;
  return OnboardingLists.fromJson(decoded);
});
