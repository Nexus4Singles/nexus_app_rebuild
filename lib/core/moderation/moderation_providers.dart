import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';
import '../providers/firestore_service_provider.dart';
import 'local_moderation_repositories.dart';
import 'moderation_models.dart';

final localBlockRepositoryProvider = Provider<LocalBlockRepository>((ref) {
  return const LocalBlockRepository();
});

final localReportRepositoryProvider = Provider<LocalReportRepository>((ref) {
  return const LocalReportRepository();
});

class BlockedUsersController extends StateNotifier<AsyncValue<Set<String>>> {
  final String viewerKey;
  final LocalBlockRepository repo;

  BlockedUsersController({required this.viewerKey, required this.repo})
    : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final v = await repo.loadBlockedUids(viewerKey);
    state = AsyncValue.data(v);
  }

  bool get isReady => state.hasValue;

  bool isBlocked(String uid) {
    final set = state.maybeWhen(data: (v) => v, orElse: () => <String>{});
    return set.contains(uid);
  }

  Future<void> block(String uid) async {
    final prev = state.maybeWhen(data: (v) => v, orElse: () => <String>{});
    if (prev.contains(uid)) return;

    // optimistic
    state = AsyncValue.data({...prev, uid});
    try {
      await repo.block(viewerKey, uid);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      state = AsyncValue.data(prev); // rollback
    }
  }

  Future<void> unblock(String uid) async {
    final prev = state.maybeWhen(data: (v) => v, orElse: () => <String>{});
    if (!prev.contains(uid)) return;

    final next = {...prev}..remove(uid);
    state = AsyncValue.data(next);
    try {
      await repo.unblock(viewerKey, uid);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      state = AsyncValue.data(prev); // rollback
    }
  }

  Future<void> refresh() async => _load();
}

final blockedUsersProvider = StateNotifierProvider.family<
  BlockedUsersController,
  AsyncValue<Set<String>>,
  String
>((ref, viewerKey) {
  final repo = ref.watch(localBlockRepositoryProvider);
  return BlockedUsersController(viewerKey: viewerKey, repo: repo);
});

final isBlockedProvider =
    Provider.family<bool, ({String viewerKey, String targetUid})>((ref, args) {
      final asyncSet = ref.watch(blockedUsersProvider(args.viewerKey));
      final set = asyncSet.maybeWhen(data: (v) => v, orElse: () => <String>{});
      return set.contains(args.targetUid);
    });

Future<void> submitLocalReport({
  required WidgetRef ref,
  required String reporterKey,
  required String reportedUid,
  required ReportReason reason,
  String? notes,
}) async {
  final repo = ref.read(localReportRepositoryProvider);
  final firestoreService = ref.read(firestoreServiceProvider);

  final record = UserReportRecord(
    reporterKey: reporterKey,
    reportedUid: reportedUid,
    reason: reason,
    notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
  );

  // Save locally
  await repo.submitReport(record);

  // Sync to Firebase if available
  if (firestoreService.isAvailable) {
    try {
      await firestoreService.submitUserReport(
        reporterKey: reporterKey,
        reportedUid: reportedUid,
        reason: reason.wireValue,
        notes: record.notes,
      );
    } catch (e) {
      // Log error but don't fail - local save is already done
      print('Warning: Failed to sync report to Firebase: $e');
    }
  }
}
