import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app_v2/features/dating_search/presentation/screens/waiting_list_screen.dart';

void main() {
  group('resolveLaunchDateForUkMarket', () {
    test('uses the market launch date when it is available', () {
      final marketLaunchDate = DateTime(2026, 10, 1);

      expect(resolveLaunchDateForUkMarket(marketLaunchDate), marketLaunchDate);
    });

    test(
      'falls back to the default launch date when no market date exists',
      () {
        expect(resolveLaunchDateForUkMarket(null), DateTime(2026, 9, 5));
      },
    );
  });
}
