import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  /// Checks if a given URL string is empty or a dummy placeholder.
  static bool isDummyUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final lower = url.toLowerCase().trim();
    if (lower.contains('unsplash.com') ||
        lower.contains('placeholder') ||
        lower.contains('dummyimage') ||
        lower.contains('example.com') ||
        lower.contains('via.placeholder')) {
      return true;
    }
    return false;
  }

  /// Extracts bytes from a base64 Data URI or raw base64 string.
  static Uint8List? decodeBase64DataUri(String dataUri) {
    try {
      String base64Str = dataUri.trim();
      if (base64Str.contains(',')) {
        base64Str = base64Str.split(',').last;
      }
      return base64Decode(base64Str.trim());
    } catch (e) {
      debugPrint("Error decoding base64 data URI: $e");
      return null;
    }
  }

  /// Uploads an image file with multi-tier fallbacks:
  /// 1. Primary Firebase Storage upload (putFile on mobile, putData on web)
  /// 2. Fallback Firebase Storage buckets (handling different bucket naming formats)
  /// 3. Ultra-reliable Base64 Data URI fallback if storage is unavailable / rules blocked
  /// NEVER returns dummy / unsplash URLs so user data is never lost or replaced with mock images!
  static Future<String> uploadImage({
    required XFile file,
    required String storagePath,
  }) async {
    // 1. Try Primary Firebase Storage upload
    try {
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'file-name': file.name},
      );

      UploadTask uploadTask;
      if (!kIsWeb && File(file.path).existsSync()) {
        uploadTask = storageRef.putFile(File(file.path), metadata);
      } else {
        final bytes = await file.readAsBytes();
        uploadTask = storageRef.putData(bytes, metadata);
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isNotEmpty) {
        debugPrint("✅ Firebase Storage primary upload success: $downloadUrl");
        return downloadUrl;
      }
    } catch (e) {
      debugPrint("⚠️ Primary Firebase Storage upload failed: $e. Trying fallback buckets...");
    }

    // 2. Try Fallback Storage Buckets
    final fallbackBuckets = [
      'iub-ride-sharing-app.firebasestorage.app',
      'iub-ride-sharing-app.appspot.com',
      'gs://iub-ride-sharing-app.firebasestorage.app',
      'gs://iub-ride-sharing-app.appspot.com',
    ];

    for (final bucket in fallbackBuckets) {
      try {
        final storage = FirebaseStorage.instanceFor(bucket: bucket);
        final ref = storage.ref().child(storagePath);
        final metadata = SettableMetadata(contentType: 'image/jpeg');

        UploadTask uploadTask;
        if (!kIsWeb && File(file.path).existsSync()) {
          uploadTask = ref.putFile(File(file.path), metadata);
        } else {
          final bytes = await file.readAsBytes();
          uploadTask = ref.putData(bytes, metadata);
        }

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        if (downloadUrl.isNotEmpty) {
          debugPrint("✅ Firebase Storage fallback bucket ($bucket) upload success: $downloadUrl");
          return downloadUrl;
        }
      } catch (e) {
        debugPrint("Fallback bucket $bucket error: $e");
      }
    }

    // 3. Ultra-reliable Base64 Data URI fallback
    // Saves actual image bytes directly into Firestore document, guaranteeing real images
    // are visible to admin and driver even without Firebase Storage configured.
    try {
      debugPrint("⚡ Encoding image to Base64 data URI fallback...");
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';
      debugPrint("✅ Base64 Data URI created successfully (size: ${bytes.lengthInBytes} bytes)");
      return dataUri;
    } catch (e) {
      debugPrint("❌ Base64 encoding failed: $e");
      throw Exception("Could not process or upload the selected image: $e");
    }
  }

  /// Returns an [ImageProvider] for any image string (Network, Base64, or null).
  static ImageProvider? getImageProvider(String? imageSource) {
    if (imageSource == null || isDummyUrl(imageSource)) return null;

    final trimmed = imageSource.trim();
    if (trimmed.startsWith('data:image') || trimmed.startsWith('data:')) {
      final bytes = decodeBase64DataUri(trimmed);
      if (bytes != null && bytes.isNotEmpty) {
        return MemoryImage(bytes);
      }
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    if (!kIsWeb && File(trimmed).existsSync()) {
      return FileImage(File(trimmed));
    }

    return null;
  }

  /// Builds a widget that renders any image source (XFile, File, Base64 Data URI, Network URL).
  static Widget buildImageWidget({
    XFile? localXFile,
    File? localFile,
    String? imageSource,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // 1. Local XFile
    if (localXFile != null) {
      return Image.file(
        File(localXFile.path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? _defaultErrorWidget(),
      );
    }

    // 2. Local File
    if (localFile != null) {
      return Image.file(
        localFile,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? _defaultErrorWidget(),
      );
    }

    // 3. String imageSource (Network or Base64)
    if (imageSource != null && !isDummyUrl(imageSource)) {
      final trimmed = imageSource.trim();

      // Base64 Data URI
      if (trimmed.startsWith('data:image') || trimmed.startsWith('data:')) {
        final bytes = decodeBase64DataUri(trimmed);
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) =>
                errorWidget ?? _defaultErrorWidget(),
          );
        }
      }

      // Network URL
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return Image.network(
          trimmed,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? _defaultErrorWidget(),
        );
      }
    }

    return placeholder ?? _defaultPlaceholderWidget();
  }

  static Widget _defaultErrorWidget() {
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28),
    );
  }

  static Widget _defaultPlaceholderWidget() {
    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.grey, size: 28),
    );
  }
}
