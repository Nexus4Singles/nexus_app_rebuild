import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchFilterLists {
  final List<String> countryOfResidence;
  final List<String> educationLevels;
  final List<String> incomeSources;
  final List<String> relationshipDistance;
  final List<String> maritalStatus;
  final List<String> hasKids;
  final List<String> genotypes;

  const SearchFilterLists({
    required this.countryOfResidence,
    required this.educationLevels,
    required this.incomeSources,
    required this.relationshipDistance,
    required this.maritalStatus,
    required this.hasKids,
    required this.genotypes,
  });

  factory SearchFilterLists.fromJson(Map<String, dynamic> json) {
    final lists = (json['lists'] as Map).cast<String, dynamic>();

    List<String> _asStringList(String key) {
      final v = lists[key];
      if (v is List) return v.map((e) => '$e').toList();
      return const [];
    }

    return SearchFilterLists(
      countryOfResidence: _asStringList('countryOfResidenceFilters'),
      educationLevels: _asStringList('educationLevelFilters'),
      incomeSources: _asStringList('incomeSourceFilters'),
      relationshipDistance: _asStringList('relationshipDistanceFilters'),
      maritalStatus: _asStringList('maritalStatusFilters'),
      hasKids: _asStringList('hasKidsFilters'),
      genotypes: _asStringList('genotypeFilters'),
    );
  }
}

final searchFilterListsProvider = FutureProvider<SearchFilterLists>((
  ref,
) async {
  final raw = await rootBundle.loadString(
    'assets/data/nexus1_onboarding_lists.v1.json',
  );
  final decoded = json.decode(raw) as Map<String, dynamic>;
  return SearchFilterLists.fromJson(decoded);
});
