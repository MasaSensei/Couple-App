import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class PreparedPhoto {
  const PreparedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  static const String mimeType = 'image/jpeg';
}

/// Prepares a picked photo before encryption:
/// validate -> apply orientation -> resize -> strip EXIF -> re-encode as JPEG.
/// Compression must happen here because ciphertext does not compress.
class PhotoPreparationService {
  const PhotoPreparationService({this.maxDimension = 2048, this.quality = 85});

  static const int maxInputBytes = 30 * 1024 * 1024;

  final int maxDimension;
  final int quality;

  Future<PreparedPhoto> prepare(Uint8List original) async {
    if (original.isEmpty || original.length > maxInputBytes) {
      throw const FormatException('Unsupported photo size.');
    }

    // Decoding a 12 MP photo takes a while; keep it off the UI thread.
    return compute(_prepare, (original, maxDimension, quality));
  }
}

PreparedPhoto _prepare((Uint8List, int, int) args) {
  final (original, maxDimension, quality) = args;

  final decoded = img.decodeImage(original);

  if (decoded == null) {
    throw const FormatException('Unsupported image format.');
  }

  // Rotate pixels per EXIF orientation, then drop all metadata (GPS, device, time).
  var image = img.bakeOrientation(decoded);

  if (image.width > maxDimension || image.height > maxDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxDimension)
        : img.copyResize(image, height: maxDimension);
  }

  image.exif = img.ExifData();
  image.iccProfile = null;
  image.textData = null;

  return PreparedPhoto(
    bytes: img.encodeJpg(image, quality: quality),
    width: image.width,
    height: image.height,
  );
}
