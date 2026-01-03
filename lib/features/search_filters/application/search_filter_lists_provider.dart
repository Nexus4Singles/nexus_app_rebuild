import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/search_filter_lists.dart';
import '../data/search_filter_lists_loader.dart';

final searchFilterListsLoaderProvider = Provider<SearchFilterListsLoader>((
  ref,
) {
  return SearchFilterListsLoader();
});

final searchFilterListsProvider = FutureProvider<SearchFilterLists>((
  ref,
) async {
  final loader = ref.read(searchFilterListsLoaderProvider);
  return loader.load();
});
