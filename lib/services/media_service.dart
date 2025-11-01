// services/media_service.dart
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:jeu_carre/services/minio_storage_service.dart';

class MediaService {
  final ImagePicker _imagePicker = ImagePicker();
  final MinioStorageService _minioStorage = MinioStorageService();

  Future<File?> pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      throw Exception('Erreur sélection image: $e');
    }
  }

  Future<String> uploadImage(File image, String userId) async {
    return await _minioStorage.uploadUserAvatar(image, userId);
  }

  Future<void> deleteImage(String userId) async {
    await _minioStorage.deleteUserAvatar(userId);
  }
}