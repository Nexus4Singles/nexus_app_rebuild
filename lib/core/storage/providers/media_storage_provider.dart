import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/storage/do_spaces_storage.dart';
import 'package:nexus_app_v2/core/storage/media_storage_service.dart';

final mediaStorageProvider = Provider<MediaStorageService>((ref) {
  // ✅ Stub service (DO Spaces real implementation later)
  return DoSpacesStorageStub();
});
