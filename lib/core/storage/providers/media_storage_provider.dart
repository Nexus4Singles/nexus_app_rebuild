import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/storage/do_spaces_storage_stub.dart';
import 'package:nexus_app_min_test/core/storage/media_storage_service.dart';

final mediaStorageProvider = Provider<MediaStorageService>((ref) {
  // ✅ Stub service (DO Spaces real implementation later)
  return DoSpacesStorageStub();
});
