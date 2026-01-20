import '../lib/core/constants/app_constants.dart';

void main() {
  for (final s in RelationshipStatus.values) {
    final tabs = NavConfig.getTabsForStatus(s);
    print('STATUS: ${s.name}');
    for (final t in tabs) {
      print('  - ${t.id.name} => ${t.route}');
    }
  }
  final nullTabs = NavConfig.getTabsForStatus(null);
  print('STATUS: null');
  for (final t in nullTabs) {
    print('  - ${t.id.name} => ${t.route}');
  }
}
