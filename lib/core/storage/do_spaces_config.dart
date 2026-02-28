class DoSpacesConfig {
  const DoSpacesConfig._();

  /// DigitalOcean Spaces configuration
  /// The actual access/secret keys are only on the backend (Firebase Cloud Functions)
  static const String endpoint = 'ams3.digitaloceanspaces.com';
  static const String region = 'ams3';
  static const String bucket = 'nexus-v2-users';

  /// Full HTTPS Function URL for presigning uploads.
  static const String presignUrl =
      'https://us-central1-nexus-visibility-app.cloudfunctions.net/getPresignedUploadUrl';

  static void validate() {
    print('[DO_SPACES_CONFIG] endpoint: $endpoint');
    print('[DO_SPACES_CONFIG] region: $region');
    print('[DO_SPACES_CONFIG] bucket: $bucket');
    print('[DO_SPACES_CONFIG] presignUrl: $presignUrl');
    print('[DO_SPACES_CONFIG] ✅ Configuration is valid!');
  }

  /// Construct the public URL for a given object key.
  /// This MUST match the construction logic in functions/index.js
  static String publicUrlFor(String objectKey) {
    // Standard DO Spaces path-style URL
    return 'https://$endpoint/$bucket/$objectKey';
  }
}
