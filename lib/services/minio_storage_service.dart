// services/minio_storage_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class MinioStorageService {
  final String _minioUrl = 'http://localhost:9000';
  final String _accessKey = 'minioadminshikaku';
  final String _secretKey = 'minioadminshikaku';
  final String _bucketName = 'shikaku';

  static const List<int> _encryptionKey = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
  ];

  Future<String> uploadUserAvatar(File image, String userId) async {
    try {
      // Vérifier si le bucket existe, sinon le créer
      await _ensureBucketExists();

      final String fileName = 'user_avatars/$userId.jpg';
      final List<int> fileBytes = await image.readAsBytes();
      
      // Générer les headers d'authentification AWS v4
      final DateTime now = DateTime.now().toUtc();
      final String amzDate = _formatAmzDate(now);
      final String dateStamp = _formatDateStamp(now);

      // Préparer la requête
      final Uri uri = Uri.parse('$_minioUrl/$_bucketName/$fileName');
      
      final Map<String, String> headers = {
        'Host': uri.host,
        'x-amz-date': amzDate,
        'x-amz-content-sha256': _sha256Hash(fileBytes),
        'Content-Type': 'image/jpeg',
        'Content-Length': fileBytes.length.toString(),
      };

      // Calculer la signature AWS v4
      final String signature = _calculateSignature(
        method: 'PUT',
        uri: uri,
        headers: headers,
        payloadHash: _sha256Hash(fileBytes),
        amzDate: amzDate,
        dateStamp: dateStamp,
      );

      // Ajouter l'autorisation
      headers['Authorization'] = _buildAuthorizationHeader(
        signature: signature,
        amzDate: amzDate,
        dateStamp: dateStamp,
      );

      // Effectuer l'upload
      final response = await http.put(
        uri,
        headers: headers,
        body: fileBytes,
      );

      if (response.statusCode == 200) {
        return '$_minioUrl/$_bucketName/$fileName';
      } else {
        throw MinioException(
          'Erreur upload MinIO: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw MinioException('Erreur upload image: $e', 0);
    }
  }

  Future<Uint8List?> getUserAvatar(String userId) async {
    try {
      final String fileName = 'user_avatars/$userId.jpg';
      final Uri uri = Uri.parse('$_minioUrl/$_bucketName/$fileName');

      final DateTime now = DateTime.now().toUtc();
      final String amzDate = _formatAmzDate(now);
      final String dateStamp = _formatDateStamp(now);

      final Map<String, String> headers = {
        'Host': uri.host,
        'x-amz-date': amzDate,
        'x-amz-content-sha256': _sha256Hash([]), // Empty body for GET
      };

      final String signature = _calculateSignature(
        method: 'GET',
        uri: uri,
        headers: headers,
        payloadHash: _sha256Hash([]),
        amzDate: amzDate,
        dateStamp: dateStamp,
      );

      headers['Authorization'] = _buildAuthorizationHeader(
        signature: signature,
        amzDate: amzDate,
        dateStamp: dateStamp,
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        return null; // Avatar non trouvé
      } else {
        throw MinioException(
          'Erreur récupération avatar: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw MinioException('Erreur récupération image: $e', 0);
    }
  }

  Future<void> deleteUserAvatar(String userId) async {
    try {
      final String fileName = 'user_avatars/$userId.jpg';
      final Uri uri = Uri.parse('$_minioUrl/$_bucketName/$fileName');

      final DateTime now = DateTime.now().toUtc();
      final String amzDate = _formatAmzDate(now);
      final String dateStamp = _formatDateStamp(now);

      final Map<String, String> headers = {
        'Host': uri.host,
        'x-amz-date': amzDate,
        'x-amz-content-sha256': _sha256Hash([]),
      };

      final String signature = _calculateSignature(
        method: 'DELETE',
        uri: uri,
        headers: headers,
        payloadHash: _sha256Hash([]),
        amzDate: amzDate,
        dateStamp: dateStamp,
      );

      headers['Authorization'] = _buildAuthorizationHeader(
        signature: signature,
        amzDate: amzDate,
        dateStamp: dateStamp,
      );

      final response = await http.delete(uri, headers: headers);

      if (response.statusCode != 204) {
        throw MinioException(
          'Erreur suppression avatar: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw MinioException('Erreur suppression avatar: $e', 0);
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$_minioUrl/minio/health/live'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // === IMPLÉMENTATION AWS v4 SIGNATURE ===

  String _calculateSignature({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String payloadHash,
    required String amzDate,
    required String dateStamp,
  }) {
    final String canonicalRequest = _buildCanonicalRequest(
      method: method,
      uri: uri,
      headers: headers,
      payloadHash: payloadHash,
    );

    final String stringToSign = _buildStringToSign(
      amzDate: amzDate,
      dateStamp: dateStamp,
      canonicalRequest: canonicalRequest,
    );

    final List<int> signingKey = _getSignatureKey(
      dateStamp: dateStamp,
    );

    return _hmacSha256(signingKey, stringToSign);
  }

  String _buildCanonicalRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String payloadHash,
  }) {
    final String canonicalUri = uri.path;
    final String canonicalQueryString = '';
    
    final List<String> canonicalHeaders = headers.entries
        .map((e) => '${e.key.toLowerCase()}:${e.value.trim()}')
        .toList();
    canonicalHeaders.sort();
    
    final List<String> signedHeadersList = headers.keys
        .map((key) => key.toLowerCase())
        .toList();
    signedHeadersList.sort();
    final String signedHeaders = signedHeadersList.join(';');

    return [
      method,
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders.join('\n') + '\n',
      signedHeaders,
      payloadHash,
    ].join('\n');
  }

  String _buildStringToSign({
    required String amzDate,
    required String dateStamp,
    required String canonicalRequest,
  }) {
    final String algorithm = 'AWS4-HMAC-SHA256';
    final String credentialScope = '$dateStamp/us-east-1/s3/aws4_request';

    return [
      algorithm,
      amzDate,
      credentialScope,
      _sha256Hash(utf8.encode(canonicalRequest)),
    ].join('\n');
  }

  List<int> _getSignatureKey({required String dateStamp}) {
    final List<int> kDate = _hmacSha256Bytes(
      utf8.encode('AWS4$_secretKey'),
      utf8.encode(dateStamp),
    );
    
    final List<int> kRegion = _hmacSha256Bytes(kDate, utf8.encode('us-east-1'));
    final List<int> kService = _hmacSha256Bytes(kRegion, utf8.encode('s3'));
    final List<int> kSigning = _hmacSha256Bytes(kService, utf8.encode('aws4_request'));
    
    return kSigning;
  }

  String _buildAuthorizationHeader({
    required String signature,
    required String amzDate,
    required String dateStamp,
  }) {
    final String credentialScope = '$dateStamp/us-east-1/s3/aws4_request';
    
    return 'AWS4-HMAC-SHA256 '
        'Credential=$_accessKey/$credentialScope, '
        'SignedHeaders=host;x-amz-content-sha256;x-amz-date, '
        'Signature=$signature';
  }

  // === UTILITAIRES ===

  Future<void> _ensureBucketExists() async {
    try {
      final Uri uri = Uri.parse('$_minioUrl/$_bucketName');
      final response = await http.head(uri);
      
      if (response.statusCode == 404) {
        await _createBucket();
      }
    } catch (e) {
      await _createBucket();
    }
  }

  Future<void> _createBucket() async {
    final DateTime now = DateTime.now().toUtc();
    final String amzDate = _formatAmzDate(now);
    final String dateStamp = _formatDateStamp(now);
    final Uri uri = Uri.parse('$_minioUrl/$_bucketName');

    final Map<String, String> headers = {
      'Host': uri.host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': _sha256Hash([]),
    };

    final String signature = _calculateSignature(
      method: 'PUT',
      uri: uri,
      headers: headers,
      payloadHash: _sha256Hash([]),
      amzDate: amzDate,
      dateStamp: dateStamp,
    );

    headers['Authorization'] = _buildAuthorizationHeader(
      signature: signature,
      amzDate: amzDate,
      dateStamp: dateStamp,
    );

    final response = await http.put(uri, headers: headers);
    
    if (response.statusCode != 200) {
      throw MinioException(
        'Erreur création bucket: ${response.statusCode}',
        response.statusCode,
      );
    }
  }

  String _formatAmzDate(DateTime date) {
    return DateFormat('yyyyMMddTHHmmss\'Z\'').format(date);
  }

  String _formatDateStamp(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  String _sha256Hash(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  String _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).toString();
  }

  List<int> _hmacSha256Bytes(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }
}

class MinioException implements Exception {
  final String message;
  final int statusCode;

  MinioException(this.message, this.statusCode);

  @override
  String toString() => 'MinioException: $message (Status: $statusCode)';
}