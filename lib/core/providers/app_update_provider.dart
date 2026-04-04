import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/services/app_update_service.dart';

/// Provider to check for app updates
final appUpdateProvider = FutureProvider<AppUpdateResult>((ref) async {
  return await AppUpdateService.checkForUpdate();
});

/// Manually trigger update check (for retry or refresh)
final appUpdateNotifierProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
      return AppUpdateNotifier();
    });

class AppUpdateState {
  final AppUpdateResult? result;
  final bool isLoading;
  final bool hasError;

  const AppUpdateState({
    this.result,
    this.isLoading = false,
    this.hasError = false,
  });

  AppUpdateState copyWith({
    AppUpdateResult? result,
    bool? isLoading,
    bool? hasError,
  }) {
    return AppUpdateState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  AppUpdateNotifier() : super(const AppUpdateState());

  Future<void> checkForUpdate() async {
    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final result = await AppUpdateService.checkForUpdate();
      state = state.copyWith(result: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(hasError: true, isLoading: false);
    }
  }
}
