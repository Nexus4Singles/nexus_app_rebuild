import 'dart:convert';
import 'package:flutter/services.dart';

import 'search_filter_lists.dart';

class SearchFilterListsLoader {
  static const _assetPath = 'assets/data/nexus1_onboarding_lists.v1.json';

  Future<SearchFilterLists> load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final jsonMap = json.decode(raw) as Map<String, dynamic>;
    final lists = (jsonMap['lists'] as Map<String, dynamic>?) ?? const {};

    List<String> _list(String key) {
      final v = lists[key];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return SearchFilterLists(
      countriesOfResidence: _list('countryOfResidenceFilters'),
      educationLevels: _list('educationLevelFilters'),
      incomeSources: _list('incomeSourceFilters'),
      relationshipDistances: _list('relationshipDistanceFilters'),
      maritalStatuses: _list('maritalStatusFilters'),
      hasKids: _list('hasKidsFilters'),
      genotypes: _list('genotypeFilters'),
    );
  }
}
