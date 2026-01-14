import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'do_spaces_config.dart';
import 'media_storage_service.dart';

class DoSpacesStorageService implements MediaStorageService {
  DoSpacesStorageService() {
    DoSpacesConfig.validate();
  }

  static const String _service = 's3';

  @override
  Future<String> uploadImage({
    required String localPath,
    required String objectKey,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('File does not exist: $localPath');
    }

    final bytes = await file.readAsBytes();
    final url = Uri.parse(DoSpacesConfig.publicUrlFor(objectKey));

    // Path-style: https://{endpoint}/{bucket}/{objectKey}
    // Canonical URI must be "/{bucket}/{objectKey}"
    final canonicalPath = url.path; // already includes /bucket/key
    final contentSha256 = _sha256Hex(bytes);
    final amzDate = _amzDateNowUtc();
    final dateStamp = amzDate.substring(0, 8);

    final headers = <String, String>{
      'host': url.host,
      'x-amz-acl': 'public-read',
      'x-amz-content-sha256': contentSha256,
      'x-amz-date': amzDate,
      // content-type is optional for Spaces; add if you want stricter handling later
    };

    final auth = _sign(
      method: 'PUT',
      canonicalUri: _uriEncodePath(canonicalPath),
      canonicalQueryString: '',
      headers: headers,
      payloadHashHex: contentSha256,
      dateStamp: dateStamp,
      amzDate: amzDate,
      region: DoSpacesConfig.region,
    );

    final reqHeaders = <String, String>{
      // Send with normal casing; signing uses lowercase internally
      'Host': url.host,
      'x-amz-acl': 'public-read',
      'x-amz-content-sha256': contentSha256,
      'x-amz-date': amzDate,
      'Authorization': auth,
    };

    final resp = await http.put(url, headers: reqHeaders, body: bytes);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Spaces upload failed (${resp.statusCode}): ${resp.body}',
      );
    }

    log(url.toString(), name: 'DoSpaces upload URL');
    return url.toString();
  }

  @override
  Future<void> deleteObject({required String objectKey}) async {
    final url = Uri.parse(DoSpacesConfig.publicUrlFor(objectKey));
    final canonicalPath = url.path;
    final payloadHash = _sha256Hex(const <int>[]); // empty payload
    final amzDate = _amzDateNowUtc();
    final dateStamp = amzDate.substring(0, 8);

    final headers = <String, String>{
      'host': url.host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
    };

    final auth = _sign(
      method: 'DELETE',
      canonicalUri: _uriEncodePath(canonicalPath),
      canonicalQueryString: '',
      headers: headers,
      payloadHashHex: payloadHash,
      dateStamp: dateStamp,
      amzDate: amzDate,
      region: DoSpacesConfig.region,
    );

    final reqHeaders = <String, String>{
      'Host': url.host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      'Authorization': auth,
    };

    final resp = await http.delete(url, headers: reqHeaders);
    if (resp.statusCode == 404) {
      // treat missing object as success for delete semantics
      return;
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Spaces delete failed (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  // -----------------------
  // SigV4 helpers
  // -----------------------

  String _sign({
    required String method,
    required String canonicalUri,
    required String canonicalQueryString,
    required Map<String, String> headers,
    required String payloadHashHex,
    required String dateStamp,
    required String amzDate,
    required String region,
  }) {
    final lowerHeaders = <String, String>{};
    headers.forEach((k, v) => lowerHeaders[k.toLowerCase()] = v.trim());

    final sortedHeaderKeys = lowerHeaders.keys.toList()..sort();
    final canonicalHeaders =
        sortedHeaderKeys
            .map((k) => '$k:${_compressSpaces(lowerHeaders[k] ?? '')}\n')
            .join();

    final signedHeaders = sortedHeaderKeys.join(';');

    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      payloadHashHex,
    ].join('\n');

    final algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope = '$dateStamp/$region/$_service/aws4_request';
    final stringToSign = [
      algorithm,
      amzDate,
      credentialScope,
      _sha256Hex(utf8.encode(canonicalRequest)),
    ].join('\n');

    final signingKey = _getSignatureKey(
      secretKey: DoSpacesConfig.secretKey,
      dateStamp: dateStamp,
      region: region,
      service: _service,
    );

    final signature = _hmacSha256Hex(signingKey, utf8.encode(stringToSign));

    return '$algorithm '
        'Credential=${DoSpacesConfig.accessKey}/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';
  }

  List<int> _getSignatureKey({
    required String secretKey,
    required String dateStamp,
    required String region,
    required String service,
  }) {
    final kDate = _hmacSha256(
      utf8.encode('AWS4$secretKey'),
      utf8.encode(dateStamp),
    );
    final kRegion = _hmacSha256(kDate, utf8.encode(region));
    final kService = _hmacSha256(kRegion, utf8.encode(service));
    final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
    return kSigning;
  }

  List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

  String _hmacSha256Hex(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).toString();
  }

  String _sha256Hex(List<int> data) {
    return sha256.convert(data).toString();
  }

  String _amzDateNowUtc() {
    final now = DateTime.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}'
        '${two(now.month)}'
        '${two(now.day)}'
        'T'
        '${two(now.hour)}'
        '${two(now.minute)}'
        '${two(now.second)}'
        'Z';
  }

  String _compressSpaces(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Encode each path segment, keep slashes.
  String _uriEncodePath(String path) {
    final segments = path.split('/');
    final encoded = segments.map((seg) => Uri.encodeComponent(seg)).join('/');
    // Preserve leading slash if present
    if (path.startsWith('/') && !encoded.startsWith('/')) return '/$encoded';
    return encoded;
  }
}
