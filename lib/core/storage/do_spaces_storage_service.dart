import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'do_spaces_config.dart';
import 'media_storage_service.dart';

/// Robust upload service for DigitalOcean Spaces via backend-issued presigned URLs.
///
/// Features:
/// - Retry with exponential backoff (3 attempts)
/// - Timeouts on both presign and upload requests
/// - Proper Content-Type headers
/// - Connection cleanup
class DoSpacesStorageService implements MediaStorageService {
  DoSpacesStorageService();

  static const int _maxRetries = 3;
  static const Duration _presignTimeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(seconds: 120);

  @override
  Future<String> uploadImage({
    required String localPath,
    required String objectKey,
  }) async {
    return uploadFile(localPath: localPath);
  }

  /// Determine content type from file path.
  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    // Default to JPEG for photos
    return 'image/jpeg';
  }

  /// Determine file type category from path.
  String _fileType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.m4a') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav')) {
      return 'audio';
    }
    return 'photo';
  }

  /// Upload a file via backend-issued presigned URL.
  ///
  /// Retries up to [_maxRetries] times with exponential backoff on transient
  /// failures (socket errors, timeouts, 5xx responses).
  Future<String> uploadFile({
    required String localPath,
    Function(double)? onProgress,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('File does not exist: $localPath');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not authenticated');

    // Read file bytes once — reused across retries.
    final Uint8List fileBytes = await file.readAsBytes();
    final contentType = _contentTypeForPath(localPath);
    final type = _fileType(localPath);

    print(
      '[DO_UPLOAD] Starting upload: type=$type, '
      'size=${fileBytes.length} bytes, contentType=$contentType',
    );
    onProgress?.call(0.05);

    // --- Step 1: Get presigned URL from backend ---
    final idToken = await user.getIdToken();
    onProgress?.call(0.1);

    final presignResp = await http
        .post(
          Uri.parse(DoSpacesConfig.presignUrl),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'type': type, 'contentType': contentType}),
        )
        .timeout(_presignTimeout);

    if (presignResp.statusCode < 200 || presignResp.statusCode >= 300) {
      throw StateError(
        'Presign failed (${presignResp.statusCode}): ${presignResp.body}',
      );
    }

    final decoded = jsonDecode(presignResp.body) as Map<String, dynamic>;
    final uploadUrl = (decoded['uploadUrl'] ?? '').toString();
    final publicUrl = (decoded['publicUrl'] ?? '').toString();

    if (uploadUrl.isEmpty || publicUrl.isEmpty) {
      throw StateError('Backend returned empty uploadUrl or publicUrl');
    }

    print('[DO_UPLOAD] Presigned URL obtained, uploading to DO Spaces…');
    onProgress?.call(0.25);

    // --- Step 2: PUT file bytes to presigned URL with retry ---
    Object? lastError;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .put(
              Uri.parse(uploadUrl),
              headers: {
                'Content-Type': contentType,
                'Content-Length': fileBytes.length.toString(),
                // NOTE: The presigned URL already includes ACL:public-read in the signature
                // from the backend. Don't send x-amz-acl header - it would cause signature
                // verification to fail because it's not part of the signed request.
              },
              body: fileBytes,
            )
            .timeout(_uploadTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print(
            '[DO_UPLOAD] ✅ Upload succeeded on attempt $attempt '
            '(status ${response.statusCode})',
          );
          onProgress?.call(1.0);
          return publicUrl;
        }

        // Non-retryable client error (4xx except 408/429)
        if (response.statusCode >= 400 &&
            response.statusCode < 500 &&
            response.statusCode != 408 &&
            response.statusCode != 429) {
          throw StateError(
            'Upload rejected (${response.statusCode}): ${response.body}',
          );
        }

        // Server error or retryable status — will retry
        lastError = StateError(
          'Upload failed (${response.statusCode}): ${response.body}',
        );
        print(
          '[DO_UPLOAD] ⚠️ Attempt $attempt failed with status '
          '${response.statusCode}, retrying…',
        );
      } on TimeoutException {
        lastError = TimeoutException(
          'Upload timed out on attempt $attempt',
          _uploadTimeout,
        );
        print(
          '[DO_UPLOAD] ⚠️ Attempt $attempt timed out after '
          '${_uploadTimeout.inSeconds}s',
        );
      } on SocketException catch (e) {
        lastError = e;
        print('[DO_UPLOAD] ⚠️ Attempt $attempt socket error: $e');
      } on http.ClientException catch (e) {
        lastError = e;
        print('[DO_UPLOAD] ⚠️ Attempt $attempt client error: $e');
      }

      // Exponential backoff: 2s, 4s, 8s…
      if (attempt < _maxRetries) {
        final delay = Duration(seconds: 2 * (1 << (attempt - 1)));
        print('[DO_UPLOAD] Waiting ${delay.inSeconds}s before retry…');
        onProgress?.call(0.25 + (attempt / _maxRetries) * 0.2);
        await Future.delayed(delay);
      }
    }

    print('[DO_UPLOAD] ❌ All $_maxRetries attempts failed');
    throw StateError(
      'Upload failed after $_maxRetries attempts. Last error: $lastError',
    );
  }

  @override
  Future<void> deleteObject({required String objectKey}) =>
      throw StateError('Not supported');
}
