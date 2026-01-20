import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nexus_lists_models.dart';

const _assetPath = 'assets/data/nexus1_onboarding_lists.v1.json';

final onboardingListsProvider = FutureProvider<OnboardingListsModel>((
  ref,
) async {
  final raw = await rootBundle.loadString(_assetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final lists = decoded['lists'] as Map<String, dynamic>?;

  if (lists == null) {
    throw StateError('Lists JSON missing "lists" key ($_assetPath)');
  }

  final model = OnboardingListsModel.fromJson(lists);

  // Guards: don't silently ship empty lists.
  if (model.hobbies.isEmpty ||
      model.desiredQualities.isEmpty ||
      model.professions.isEmpty ||
      model.educationalLevels.isEmpty ||
      model.churches.isEmpty) {
    throw StateError('Onboarding lists malformed or empty ($_assetPath)');
  }

  return model;
});

final searchFilterListsProvider = FutureProvider<SearchFilterListsModel>((
  ref,
) async {
  final raw = await rootBundle.loadString(_assetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final lists = decoded['lists'] as Map<String, dynamic>?;

  if (lists == null) {
    throw StateError('Lists JSON missing "lists" key ($_assetPath)');
  }

  final model = SearchFilterListsModel.fromJson(lists);

  // Guards: search filters should not be empty.
  if (model.countryOfResidenceFilters.isEmpty ||
      model.educationLevelFilters.isEmpty ||
      model.incomeSourceFilters.isEmpty ||
      model.relationshipDistanceFilters.isEmpty ||
      model.maritalStatusFilters.isEmpty ||
      model.hasKidsFilters.isEmpty ||
      model.genotypeFilters.isEmpty) {
    throw StateError('Search filter lists malformed or empty ($_assetPath)');
  }

  return model;
});
