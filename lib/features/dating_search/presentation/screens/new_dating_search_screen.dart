import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/dating/dating_profile_status_provider.dart';
import '../../application/dating_preferences_provider.dart';
import '../../domain/dating_preferences.dart';
import 'dating_preferences_setup_screen.dart';
import 'search_results_grid_screen.dart';

/// Main dating search screen
/// Routes to:
/// 1. First-time users → preferences setup
/// 2. Users with saved preferences → search results
/// 3. Users without preferences → preferences setup
class NewDatingSearchScreen extends ConsumerStatefulWidget {
  const NewDatingSearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NewDatingSearchScreen> createState() =>
      _NewDatingSearchScreenState();
}

class _NewDatingSearchScreenState extends ConsumerState<NewDatingSearchScreen>
    with AutomaticKeepAliveClientMixin {
  bool? _isFirstSearch;
  bool? _completedSetupAfterStatusChange;
  bool? _showSetupScreenCached;
  bool _didMarkFirstSearchComplete = false;
  bool _didClearStatusChangeSetupFlag = false;

  @override
  void initState() {
    super.initState();
    _checkIfFirstSearch();
    _checkIfCompletedSetupAfterStatusChange();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkIfFirstSearch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSearchedBefore =
        prefs.getBool('dating_search_first_completed') ?? false;
    if (mounted) {
      setState(() => _isFirstSearch = !hasSearchedBefore);
    }
  }

  Future<void> _checkIfCompletedSetupAfterStatusChange() async {
    final prefs = await SharedPreferences.getInstance();
    final completedSetup =
        prefs.getBool('preferences_setup_after_status_change') ?? false;
    if (mounted) {
      setState(() => _completedSetupAfterStatusChange = completedSetup);
    }
  }

  Future<void> _markFirstSearchAsComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dating_search_first_completed', true);
  }

  Future<void> _clearStatusChangeSetupFlagAsync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('preferences_setup_after_status_change');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Still loading first search check or status change setup check
    if (_isFirstSearch == null || _completedSetupAfterStatusChange == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final preferencesAsync = ref.watch(datingPreferencesProvider);

    if (preferencesAsync.hasValue) {
      final preferences = preferencesAsync.valueOrNull;
      _showSetupScreenCached = _resolveShowSetup(preferences);
    }

    if (_showSetupScreenCached == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return IndexedStack(
      index: _showSetupScreenCached! ? 0 : 1,
      children: const [
        DatingPreferencesSetupScreen(onComplete: _emptyCallback),
        SearchResultsGridScreen(),
      ],
    );
  }

  bool _resolveShowSetup(DatingPreferences? preferences) {
    if (_completedSetupAfterStatusChange == true && preferences != null) {
      if (!_didClearStatusChangeSetupFlag) {
        _didClearStatusChangeSetupFlag = true;
        Future(() => _clearStatusChangeSetupFlagAsync());
      }
      return false;
    }

    if (_isFirstSearch == true) {
      if (!_didMarkFirstSearchComplete) {
        _didMarkFirstSearchComplete = true;
        Future(() => _markFirstSearchAsComplete());
      }
      return true;
    }

    if (preferences == null) {
      return true;
    }
    return false;
  }

  @override
  bool get wantKeepAlive => true;

  static void _emptyCallback() {}
}
