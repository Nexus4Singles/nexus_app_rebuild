import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'do_spaces_config.dart';
import 'media_storage_service.dart';

class DoSpacesStorageService implements MediaStorageService {
  DoSpacesStorageService();

  @override
  Future<String> uploadImage({
    required String localPath,
    required String objectKey,
  }) async {
    // Presigned flow: backend generates objectKey; we return publicUrl.
    return uploadFile(localPath: localPath);
  }

  /// Upload a file via backend-issued presigned URL.
  ///
  /// Steps:
  /// 1) Call Cloud Function with Firebase ID token to get { uploadUrl, publicUrl }.
  /// 2) PUT raw bytes to uploadUrl.
  /// 3) Return publicUrl (store in Firestore).
  Future<String> uploadFile({
    required String localPath,
    Function(double)? onProgress,
  }) async {
    // Validate only when we actually attempt an upload (prevents chat/UI crashes).
    DoSpacesConfig.validate();

    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('File does not exist: $localPath');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    onProgress?.call(0.0);

    final bytes = await file.readAsBytes();
    final contentType = _guessContentType(localPath);
    final type = _guessPresignType(contentType);

    final idToken = await user.getIdToken();

    // 1) presign
    final presignResp = await http.post(
      Uri.parse(DoSpacesConfig.presignUrl),
      headers: <String, String>{
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'type': type, // "photo" | "audio"
        'contentType': contentType,
      }),
    );

    if (presignResp.statusCode < 200 || presignResp.statusCode >= 300) {
      throw StateError(
        'Presign failed (${presignResp.statusCode}): ${presignResp.body}',
      );
    }

    final decoded = jsonDecode(presignResp.body);
    if (decoded is! Map) {
      throw StateError('Presign response invalid JSON: ${presignResp.body}');
    }

    final uploadUrl = (decoded['uploadUrl'] ?? '').toString();
    final publicUrl = (decoded['publicUrl'] ?? '').toString();

    if (uploadUrl.isEmpty || publicUrl.isEmpty) {
      throw StateError(
        'Presign response missing uploadUrl/publicUrl: ${presignResp.body}',
      );
    }

    // 2) upload
    final putResp = await http.put(
      Uri.parse(uploadUrl),
      headers: <String, String>{'Content-Type': contentType},
      body: bytes,
    );

    if (putResp.statusCode < 200 || putResp.statusCode >= 300) {
      throw StateError(
        'Upload failed (${putResp.statusCode}): ${putResp.body}',
      );
    }

    onProgress?.call(1.0);
    log(publicUrl, name: 'Spaces public URL');
    return publicUrl;
  }

  @override
  Future<void> deleteObject({required String objectKey}) async {
    // Client-side delete is intentionally disabled in presigned mode.
    // If/when needed, add a backend function that verifies auth/admin and deletes.
    throw StateError(
      'Spaces delete is not supported from client (presigned mode).',
    );
  }

  String _guessPresignType(String contentType) {
    final ct = contentType.toLowerCase();
    if (ct.startsWith('image/')) return 'photo';
    if (ct.startsWith('audio/')) return 'audio';
    // fallbacks
    return ct.contains('image') ? 'photo' : 'audio';
  }

  String _guessContentType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'm4a':
        // Common for AAC in m4a container:
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        // Reasonable default: backend still decides ext based on contentType.
        return 'application/octet-stream';
    }
  }
}
