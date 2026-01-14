class DoSpacesConfig {
  const DoSpacesConfig._();

  /// Provide these via --dart-define (recommended), e.g.
  /// flutter run --dart-define=DO_SPACES_ENDPOINT=nyc3.digitaloceanspaces.com \
  ///            --dart-define=DO_SPACES_REGION=nyc3 \
  ///            --dart-define=DO_SPACES_BUCKET=my-bucket \
  ///            --dart-define=DO_SPACES_ACCESS_KEY=... \
  ///            --dart-define=DO_SPACES_SECRET_KEY=...
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
  static const String accessKey = String.fromEnvironment(
    'DO_SPACES_ACCESS_KEY',
    defaultValue: '',
  );
  static const String secretKey = String.fromEnvironment(
    'DO_SPACES_SECRET_KEY',
    defaultValue: '',
  );

  static void validate() {
    if (endpoint.isEmpty ||
        region.isEmpty ||
        bucket.isEmpty ||
        accessKey.isEmpty ||
        secretKey.isEmpty) {
      throw StateError(
        'DigitalOcean Spaces is not configured. Provide DO_SPACES_* via --dart-define.',
      );
    }
  }

  static String publicUrlFor(String objectKey) {
    // v1 convention: https://{endpoint}/{bucket}/{objectKey}
    return 'https://$endpoint/$bucket/$objectKey';
  }
}
