class DoSpacesConfig {
  const DoSpacesConfig._();

  /// DigitalOcean Spaces configuration
  /// These are non-secret identifiers - safe to hardcode in the app
  /// The actual access/secret keys are only on the backend (Firebase Cloud Functions)
  static const String endpoint = 'ams3.digitaloceanspaces.com';
  static const String region = 'ams3';
  static const String bucket = 'nexus-v2-users';

  /// Full HTTPS Function URL for presigning uploads.
  static const String presignUrl =
      'https://us-central1-nexus-visibility-app.cloudfunctions.net/getPresignedUploadUrl';

  static void validate() {
    // All config values are hardcoded - always valid
    // Logging for debugging purposes
    print('[DO_SPACES_CONFIG] endpoint: $endpoint');
    print('[DO_SPACES_CONFIG] region: $region');
    print('[DO_SPACES_CONFIG] bucket: $bucket');
    print('[DO_SPACES_CONFIG] presignUrl: $presignUrl');
    print('[DO_SPACES_CONFIG] ✅ Configuration is valid!');
  }

  static String publicUrlFor(String objectKey) {
    // v1 convention: https://{endpoint}/{bucket}/{objectKey}
    return 'https://$endpoint/$bucket/$objectKey';
  }
}
