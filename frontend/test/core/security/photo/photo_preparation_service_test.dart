import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:frontend/core/security/photo/photo_preparation_service.dart';

Uint8List _jpegWithGps({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 100, 50));

  image.exif.imageIfd['Make'] = 'SecretPhoneMaker';
  image.exif.gpsIfd.gpsLatitude = 6.1754;
  image.exif.gpsIfd.gpsLongitude = 106.8272;

  return img.encodeJpg(image);
}

void main() {
  const service = PhotoPreparationService(maxDimension: 64);

  test('test fixture really contains EXIF GPS data', () {
    final decoded = img.decodeJpg(_jpegWithGps(width: 10, height: 10))!;

    expect(decoded.exif.gpsIfd.isEmpty, isFalse);
  });

  test('strips EXIF metadata including GPS', () async {
    final prepared = await service.prepare(
      _jpegWithGps(width: 32, height: 32),
    );

    final decoded = img.decodeJpg(prepared.bytes)!;

    expect(decoded.exif.isEmpty, isTrue);
    expect(
      String.fromCharCodes(prepared.bytes).contains('SecretPhoneMaker'),
      isFalse,
    );
  });

  test('resizes large photos keeping aspect ratio', () async {
    final prepared = await service.prepare(
      _jpegWithGps(width: 256, height: 128),
    );

    expect(prepared.width, 64);
    expect(prepared.height, 32);
  });

  test('keeps small photos at their size and outputs JPEG', () async {
    final prepared = await service.prepare(
      _jpegWithGps(width: 40, height: 20),
    );

    expect(prepared.width, 40);
    expect(prepared.height, 20);
    expect(prepared.bytes.sublist(0, 2), [0xFF, 0xD8]);
  });

  test('rejects data that is not an image', () async {
    await expectLater(
      service.prepare(Uint8List.fromList(List.filled(100, 7))),
      throwsFormatException,
    );
  });

  test('rejects empty input', () async {
    await expectLater(service.prepare(Uint8List(0)), throwsFormatException);
  });
}
