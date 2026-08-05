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

    test(
      'returns the actual stored launch date even when it is in the past',
      () {
        final now = DateTime(2026, 8, 5);
        final storedLaunchDate = DateTime(2026, 7, 29);

        expect(
          resolveLaunchDateForUkMarket(storedLaunchDate, now: now),
          storedLaunchDate,
        );
      },
    );
  });

  group('calculateLaunchCountdown', () {
    test('returns the correct days/hours/minutes for a future launch date', () {
      final now = DateTime(2026, 9, 1, 10, 0);
      final launchDate = DateTime(2026, 9, 5, 12, 30);

      final countdown = calculateLaunchCountdown(launchDate, now);

      expect(countdown.days, 4);
      expect(countdown.hours, 2);
      expect(countdown.minutes, 30);
    });

    test('clamps the countdown to zero for a past launch date', () {
      final now = DateTime(2026, 9, 6, 8, 0);
      final launchDate = DateTime(2026, 9, 5, 0, 0);

      final countdown = calculateLaunchCountdown(launchDate, now);

      expect(countdown.days, 0);
      expect(countdown.hours, 0);
      expect(countdown.minutes, 0);
    });
  });
}
