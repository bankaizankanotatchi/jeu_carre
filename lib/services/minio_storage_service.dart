import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';           // pour détecter le type d'image automatiquement
import 'package:minio/minio.dart';

class MinioStorageService {
  final _minio = Minio(
    endPoint: 'minio.f2mb.xyz',
    port: 443,
    useSSL: true,
    accessKey: 'mVsel1QD8kq6anqvssBF',
    secretKey: 'mcJjROQxqqOoK7mbKyOL97ZxHgw8lj10Eq0LWY7a',
  );

  final String _bucketName = 'shikaku';

  /// Convert Stream<List<int>> -> Stream<Uint8List>
  Stream<Uint8List> _toUint8ListStream(Stream<List<int>> stream) {
    return stream.map((chunk) => Uint8List.fromList(chunk));
  }

  /// Vérifie si le bucket existe, sinon le crée
  Future<void> _ensureBucketExists() async {
    bool exists = await _minio.bucketExists(_bucketName);
    if (!exists) {
      await _minio.makeBucket(_bucketName);
    }
  }

  /// Upload image (jpeg, png, webp, heic, etc.)
  Future<String> uploadUserAvatar(File image, String userId) async {
    await _ensureBucketExists();

    // Détecte automatiquement le format et le type MIME
    final mimeType = lookupMimeType(image.path) ?? "application/octet-stream";
    final extension = image.path.split('.').last;
    final String fileName = "user_avatars/$userId.$extension";

    await _minio.putObject(
      _bucketName,
      fileName,
      _toUint8ListStream(image.openRead()),
      size: await image.length(),
      metadata: {"Content-Type": mimeType},
    );

    return "https://minio.f2mb.xyz/$_bucketName/$fileName";
  }

  /// Récupérer avatar utilisateur
  Future<Uint8List?> getUserAvatar(String userId, {String extension = "jpg"}) async {
    try {
      final fileName = "user_avatars/$userId.$extension";

      final stream = await _minio.getObject(_bucketName, fileName);

      final bytesBuilder = BytesBuilder();
      await for (final chunk in stream) {
        bytesBuilder.add(chunk);
      }

      return bytesBuilder.toBytes();
    } catch (e) {
      return null;
    }
  }

  /// Supprimer avatar
  Future<void> deleteUserAvatar(String userId, {String extension = "jpg"}) async {
    final fileName = "user_avatars/$userId.$extension";
    await _minio.removeObject(_bucketName, fileName);
  }

  /// Update = delete + upload
  Future<String> updateUserAvatar(File newImage, String userId) async {
    await deleteUserAvatar(userId);
    return await uploadUserAvatar(newImage, userId);
  }

  /// URL directe
  String getAvatarUrl(String userId, {String extension = "jpg"}) {
    return "https://minio.f2mb.xyz/$_bucketName/user_avatars/$userId.$extension";
  }
}
