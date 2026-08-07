import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import '../../application/dating_preferences_provider.dart';
import '../../application/market_phase_provider.dart';
import '../../application/market_country_utils.dart';
import '../../domain/dating_preferences.dart';
import 'dating_preferences_setup_screen.dart';
import 'search_results_grid_screen.dart';
import 'waiting_list_screen.dart';
import 'market_coming_soon_screen.dart';
import 'daily_profiles_screen.dart';
import 'package:nexus_app_v2/core/dating/dating_verification_status_provider.dart';

/// Router screen that determines which search results view to show based on:
/// 1. Country of residence
/// 2. Available profile count
/// 3. User's A/B test variant
///
/// Logic:
/// - UK with < 10 profiles → WaitingListScreen
/// - Nigeria → SearchResultsGridScreen (control group)
/// - Other countries → DailyProfilesScreen (A/B test variant)
class SearchResultsRouterScreen extends ConsumerStatefulWidget {
  const SearchResultsRouterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchResultsRouterScreen> createState() =>
      _SearchResultsRouterScreenState();
}

class _SearchResultsRouterScreenState
    extends ConsumerState<SearchResultsRouterScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final preferencesAsync = ref.watch(datingPreferencesProvider);

    return preferencesAsync.when(
      loading:
          () => Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading preferences...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
      error:
          (e, st) => Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.getTextSecondary(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading preferences',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(datingPreferencesProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      data: (preferences) {
        // If no preferences, show setup
        if (preferences == null) {
          print(
            '[SearchResultsRouter] 🆕 No preferences found - showing setup',
          );
          return DatingPreferencesSetupScreen(
            onComplete: () {
              ref.invalidate(datingPreferencesProvider);
            },
          );
        }

        final country = preferences.countryOfResidence;
        print('[SearchResultsRouter] 🌍 Country from preferences: "$country"');

        // If no country selected, show setup
        if (country == null) {
          print('[SearchResultsRouter] ❌ Country is null - showing setup');
          return DatingPreferencesSetupScreen(
            existingPreferences: preferences,
            onComplete: () {
              ref.invalidate(datingPreferencesProvider);
            },
          );
        }

        // Route based on country and availability
        return _buildRouterLogic(context, country, preferences);
      },
    );
  }

  Widget _buildRouterLogic(
    BuildContext context,
    String country,
    DatingPreferences preferences,
  ) {
    // African markets continue to use the grid experience for now.
    if (MarketCountryUtils.isAfricanMarket(country)) {
      print(
        '[SearchResultsRouter] 🌍 African market ($country) - showing grid',
      );
      return const SearchResultsGridScreen();
    }

    final isUkMarket = MarketCountryUtils.isUkMarket(country);

    if (isUkMarket) {
      final authState = ref.watch(authStateProvider);
      final currentUserEmail = authState.asData?.value?.email;
      final bypassUkLaunchGate = shouldBypassUkLaunchGate(currentUserEmail);
      final marketAsync = ref.watch(marketPhaseProvider('uk'));
      return marketAsync.when(
        data: (marketData) {
          final shouldShowProfiles =
              bypassUkLaunchGate || shouldShowProfilesForUkMarket(marketData);

          if (shouldShowProfiles) {
            if (bypassUkLaunchGate) {
              print(
                '[SearchResultsRouter] 🇬🇧 UK launch bypass active for $currentUserEmail - showing daily profiles',
              );
            } else {
              print(
                '[SearchResultsRouter] 🇬🇧 UK market launch date has passed - showing daily profiles',
              );
            }
            return _buildDailyProfilesOrVerificationGate(context, preferences);
          }

          final launchDateUtc = marketData?.launchDate?.toUtc();
          if (launchDateUtc != null) {
            print(
              '[SearchResultsRouter] 🇬🇧 UK market launch date not reached yet; phase is ignored until launch',
            );
          } else {
            print(
              '[SearchResultsRouter] 🇬🇧 UK market has no launch date configured; staying on waitlist until date is set',
            );
          }

          print(
            '[SearchResultsRouter] 🇬🇧 UK market is prelaunch/closed - showing waitlist',
          );
          return const WaitingListScreen();
        },
        loading:
            () => Scaffold(
              backgroundColor: AppColors.getBackground(context),
              body: const Center(child: CircularProgressIndicator()),
            ),
        error: (error, stackTrace) {
          print('[SearchResultsRouter] ⚠️ UK market lookup failed: $error');
          return const WaitingListScreen();
        },
      );
    }

    if (MarketCountryUtils.isPrelaunchCarouselMarket(country)) {
      final marketCode = MarketCountryUtils.marketCodeForCountry(country);
      final marketAsync = ref.watch(marketPhaseProvider(marketCode));
      return marketAsync.when(
        data: (marketData) {
          if (shouldShowProfilesForUkMarket(marketData)) {
            print(
              '[SearchResultsRouter] 🌐 $marketCode launch date has passed - showing carousel',
            );
            return _buildDailyProfilesOrVerificationGate(context, preferences);
          }

          print(
            '[SearchResultsRouter] 🌐 $marketCode is prelaunch - showing coming soon screen',
          );
          return MarketComingSoonScreen(existingPreferences: preferences);
        },
        loading:
            () => Scaffold(
              backgroundColor: AppColors.getBackground(context),
              body: const Center(child: CircularProgressIndicator()),
            ),
        error: (error, stackTrace) {
          print(
            '[SearchResultsRouter] ⚠️ $marketCode market lookup failed: $error',
          );
          return MarketComingSoonScreen(existingPreferences: preferences);
        },
      );
    }

    // Other non-African markets use the carousel-style daily profiles experience.
    print(
      '[SearchResultsRouter] 🌐 Non-African market ($country) - applying verification gate before showing daily profiles',
    );
    return _buildDailyProfilesOrVerificationGate(context, preferences);
  }

  Widget _buildDailyProfilesOrVerificationGate(
    BuildContext context,
    DatingPreferences preferences,
  ) {
    final verificationAsync = ref.watch(datingVerificationStatusProvider);
    return verificationAsync.when(
      loading:
          () => Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: const Center(child: CircularProgressIndicator()),
          ),
      error: (error, stackTrace) {
        print('[SearchResultsRouter] ⚠️ Verification status failed: $error');
        return DatingPreferencesSetupScreen(
          existingPreferences: preferences,
          onComplete: () {
            ref.invalidate(datingPreferencesProvider);
          },
        );
      },
      data: (verificationStatus) {
        if (verificationStatus == 'verified') {
          print(
            '[SearchResultsRouter] ✅ Verified user - showing daily profiles',
          );
          return const DailyProfilesScreen();
        }
        print(
          '[SearchResultsRouter] ⛔ Unverified user - returning to preferences setup',
        );
        return DatingPreferencesSetupScreen(
          existingPreferences: preferences,
          onComplete: () {
            ref.invalidate(datingPreferencesProvider);
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
