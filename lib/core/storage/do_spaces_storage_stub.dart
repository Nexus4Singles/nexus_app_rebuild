import 'dart:io';

import 'package:nexus_app_min_test/core/storage/media_storage_service.dart';

class DoSpacesStorageStub implements MediaStorageService {
  @override
  Future<String> uploadImage({
    required String localPath,
    required String objectKey,
  }) async {
    // ✅ Stub: do not upload yet. Just verify file exists and return fake URL.
    final f = File(localPath);
    if (!await f.exists()) {
      throw StateError('File does not exist: $localPath');
    }

    // TODO(Spaces): replace with DigitalOcean Spaces upload and real URL.
    return 'https://stub-spaces.local/$objectKey';
  }

  @override
  Future<void> deleteObject({required String objectKey}) async {
    // TODO(Spaces): implement real delete call.
  }
}
