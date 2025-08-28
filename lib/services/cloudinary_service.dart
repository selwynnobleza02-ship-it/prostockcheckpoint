import 'dart:developer';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../utils/error_logger.dart';

class CloudinaryService {
  static final CloudinaryService instance = CloudinaryService._init();
  CloudinaryService._init();

  static const String _cloudName = 'dnhynbh5i';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    'ml_default', // This can be configured in your Cloudinary account
    cache: false,
  );

  Future<String?> uploadImage(File imageFile) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } on CloudinaryException catch (e, s) {
      ErrorLogger.logError(
        'Error uploading to Cloudinary',
        error: e,
        stackTrace: s,
        context: 'CloudinaryService.uploadImage',
        metadata: {'statusCode': e.statusCode, 'message': e.message},
      );
      return null;
    }
  }

  Future<void> deleteImage(String publicId) async {
    try {
      // The cloudinary_public package does not support image deletion directly.
      // You would typically need to make a signed API request from your backend
      // to delete images. For now, this method will be a placeholder.
      log('Deleting image with publicId: $publicId');
      // In a real app, you would make a call to your backend here.
    } catch (e, s) {
      ErrorLogger.logError(
        'Error deleting image from Cloudinary',
        error: e,
        stackTrace: s,
        context: 'CloudinaryService.deleteImage',
      );
    }
  }

  String? getPublicIdFromUrl(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2) {
        final publicIdWithExtension = pathSegments.last;
        final publicId = publicIdWithExtension.split('.').first;
        return publicId;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
