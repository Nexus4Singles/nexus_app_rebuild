import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import '../../application/dating_preferences_provider.dart';
import 'dating_preferences_setup_screen.dart';
import 'search_results_grid_screen.dart';

/// Main dating search screen
/// Routes to either preferences setup or search results based on saved preferences
class NewDatingSearchScreen extends ConsumerStatefulWidget {
  const NewDatingSearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NewDatingSearchScreen> createState() =>
      _NewDatingSearchScreenState();
}

class _NewDatingSearchScreenState extends ConsumerState<NewDatingSearchScreen> {
  // Removed forced invalidation of datingPreferencesProvider in initState

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(datingPreferencesProvider);

    return preferencesAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, st) => Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(datingPreferencesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      data: (preferences) {
        // If no preferences saved, show setup screen
        if (preferences == null) {
          return const DatingPreferencesSetupScreen(onComplete: _emptyCallback);
        }

        // If preferences exist but need refresh, could show indicator
        // For now, just show results
        return const SearchResultsGridScreen();
      },
    );
  }

  static void _emptyCallback() {}
}
