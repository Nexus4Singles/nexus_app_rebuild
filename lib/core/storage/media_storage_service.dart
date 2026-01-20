abstract class MediaStorageService {
  /// Uploads a local file and returns a public URL.
  Future<String> uploadImage({
    required String localPath,
    required String objectKey,
  });

  /// Deletes an uploaded file by objectKey.
  Future<void> deleteObject({required String objectKey});
}
