import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app_v2/features/dating_search/application/market_phase_provider.dart';
import 'package:nexus_app_v2/features/dating_search/application/market_country_utils.dart';
import 'package:nexus_app_v2/features/dating_search/application/waiting_list_provider.dart';
import 'package:nexus_app_v2/features/dating_search/presentation/screens/waiting_list_screen.dart';

void main() {
  group('MarketCountryUtils staged launch markets', () {
    test('classifies US, Canada, and Europe as prelaunch carousel markets', () {
      expect(MarketCountryUtils.isPrelaunchCarouselMarket('United States'), isTrue);
      expect(MarketCountryUtils.isPrelaunchCarouselMarket('Canada'), isTrue);
      expect(MarketCountryUtils.isPrelaunchCarouselMarket('France'), isTrue);
    });

    test('keeps UK and African markets on their existing paths', () {
      expect(MarketCountryUtils.isPrelaunchCarouselMarket('United Kingdom'), isFalse);
      expect(MarketCountryUtils.isAfricanMarket('Nigeria'), isTrue);
      expect(MarketCountryUtils.marketCodeForCountry('United States'), 'us');
      expect(MarketCountryUtils.marketCodeForCountry('Canada'), 'canada');
      expect(MarketCountryUtils.marketCodeForCountry('France'), 'france');
    });
  });

  group('countUkUsers', () {
    test('counts current UK users by gender across supported schemas', () {
      final stats = countUkUsers([
        {'countryOfResidence': 'United Kingdom', 'gender': 'male'},
        {'country': 'United Kingdom', 'gender': 'female'},
        {
          'dating': {
            'countryOfResidence': 'UK',
            'gender': 'FEMALE',
          },
        },
        {'countryOfResidence': 'Nigeria', 'gender': 'female'},
      ]);

      expect(stats.totalCount, 3);
      expect(stats.maleCount, 1);
      expect(stats.femaleCount, 2);
    });

    test('recalculates when a UK user appears after the initial snapshot', () {
      final initialStats = countUkUsers([
        {'countryOfResidence': 'United Kingdom', 'gender': 'male'},
      ]);
      final laterStats = countUkUsers([
        {'countryOfResidence': 'United Kingdom', 'gender': 'male'},
        {'countryOfResidence': 'United Kingdom', 'gender': 'female'},
      ]);

      expect(initialStats.totalCount, 1);
      expect(laterStats.totalCount, 2);
      expect(laterStats.femaleCount, 1);
    });
  });

  group('countVerifiedUkProfiles', () {
    test('counts verified UK users from the live profile schema', () {
      final counts = countVerifiedUkProfiles([
        {
          'dating': {
            'verificationStatus': 'verified',
            'gender': 'male',
            'profile': {'country': 'United Kingdom'},
          },
        },
        {
          'countryOfResidence': 'United Kingdom',
          'verificationStatus': 'verified',
          'gender': 'female',
        },
        {
          'dating': {
            'verificationStatus': 'pending',
            'gender': 'female',
            'profile': {'country': 'United Kingdom'},
          },
        },
        {
          'dating': {
            'verificationStatus': 'verified',
            'gender': 'female',
            'profile': {'country': 'Nigeria'},
          },
        },
      ]);

      expect(counts.total, 2);
      expect(counts.male, 1);
      expect(counts.female, 1);
    });
  });

  group('shouldShowProfilesForUkMarket', () {
    test('returns false when market is null', () {
      expect(shouldShowProfilesForUkMarket(null), isFalse);
    });

    test('returns false when launch date is still in the future', () {
      final nowUtc = DateTime(2026, 8, 1, 10, 0).toUtc();
      final market = MarketData(
        country: 'United Kingdom',
        phase: MarketPhase.active,
        launchDate: DateTime(2026, 9, 5, 12, 30),
        approvedProfileCount: 0,
        maleCount: 0,
        femaleCount: 0,
      );

      expect(shouldShowProfilesForUkMarket(market, nowUtc: nowUtc), isFalse);
    });

    test('returns true when launch date has already passed', () {
      final nowUtc = DateTime(2026, 9, 6, 10, 0).toUtc();
      final market = MarketData(
        country: 'United Kingdom',
        phase: MarketPhase.prelaunch,
        launchDate: DateTime(2026, 9, 5, 0, 0),
        approvedProfileCount: 0,
        maleCount: 0,
        femaleCount: 0,
      );

      expect(shouldShowProfilesForUkMarket(market, nowUtc: nowUtc), isTrue);
    });
  });

  group('shouldBypassUkLaunchGate', () {
    test('returns true for the configured admin email', () {
      expect(
        shouldBypassUkLaunchGate('nexus4singles@gmail.com'),
        isTrue,
      );
    });

    test('returns false for other emails', () {
      expect(shouldBypassUkLaunchGate('someone@example.com'), isFalse);
    });
  });

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
