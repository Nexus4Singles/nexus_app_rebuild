import 'dating_profile.dart';

class DatingSearchResult {
  final List<DatingProfile> items;

  /// Human-friendly hint about which filter likely eliminated results.
  /// Example: "Long distance: No"
  final String? emptyHint;

  const DatingSearchResult({required this.items, this.emptyHint});

  bool get isEmpty => items.isEmpty;
}
