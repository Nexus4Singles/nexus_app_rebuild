class DoSpacesConfig {
  const DoSpacesConfig._();

  /// Provide these via --dart-define, e.g.
  /// flutter run --dart-define=DO_SPACES_ENDPOINT=nyc3.digitaloceanspaces.com \
  ///            --dart-define=DO_SPACES_REGION=nyc3 \
  ///            --dart-define=DO_SPACES_BUCKET=my-bucket \
  ///            --dart-define=SPACES_PRESIGN_URL=https://<region>-<project>.cloudfunctions.net/getPresignedUploadUrl
  ///
  /// IMPORTANT:
  /// - The mobile app must NOT hold Spaces access/secret keys.
  /// - Uploads are done via backend-issued presigned URLs.
  static const String endpoint = String.fromEnvironment(
    'DO_SPACES_ENDPOINT',
    defaultValue: '',
  );

  static const String region = String.fromEnvironment(
    'DO_SPACES_REGION',
    defaultValue: '',
  );

  static const String bucket = String.fromEnvironment(
    'DO_SPACES_BUCKET',
    defaultValue: '',
  );

  /// Full HTTPS Function URL for presigning uploads.
  static const String presignUrl = String.fromEnvironment(
    'SPACES_PRESIGN_URL',
    defaultValue: '',
  );

  static void validate() {
    // Debug: print config values
    print('[DO_SPACES_CONFIG] endpoint: $endpoint');
    print('[DO_SPACES_CONFIG] region: $region');
    print('[DO_SPACES_CONFIG] bucket: $bucket');
    print('[DO_SPACES_CONFIG] presignUrl: $presignUrl');

    if (endpoint.isEmpty ||
        region.isEmpty ||
        bucket.isEmpty ||
        presignUrl.isEmpty) {
      throw StateError(
        'DigitalOcean Spaces is not configured. Provide DO_SPACES_ENDPOINT/DO_SPACES_REGION/DO_SPACES_BUCKET and SPACES_PRESIGN_URL via --dart-define.',
      );
    }
    print('[DO_SPACES_CONFIG] ✅ Configuration is valid!');
  }

  static String publicUrlFor(String objectKey) {
    // v1 convention: https://{endpoint}/{bucket}/{objectKey}
    return 'https://$endpoint/$bucket/$objectKey';
  }
}
