import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/theme_registry.dart';
import 'package:frontend/features/photo_booth/domain/photo_booth_document.dart';
import 'package:frontend/features/photo_booth/domain/photo_booth_templates.dart';
import 'package:frontend/features/photo_booth/render/photo_booth_export_service.dart';
import 'package:frontend/features/photo_booth/render/photo_booth_preview.dart';
import 'package:frontend/features/photo_booth/render/photo_booth_renderer.dart';
import 'package:image/image.dart' as img;

/// A real encoded photo with a gradient, so crops and scaling are visible.
Uint8List photo(int width, int height, {bool jpeg = false}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel
      ..r = pixel.x * 255 ~/ width
      ..g = pixel.y * 255 ~/ height
      ..b = 120;
  }
  return jpeg ? img.encodeJpg(image, quality: 80) : img.encodePng(image);
}

PhotoBoothDocument doc(
  String key,
  List<Uint8List> photos, {
  String caption = 'Us ♡',
}) => PhotoBoothDocument(
  template: PhotoBoothTemplates.byKey(key)!,
  photos: [
    for (final (i, bytes) in photos.indexed)
      PhotoBoothPhoto(id: 'p$i', bytes: bytes, source: PhotoSourceKind.gallery),
  ],
  caption: caption,
  date: DateTime(2026, 11, 7),
);

void main() {
  final portrait = photo(300, 450);
  final landscape = photo(450, 300);
  final square = photo(320, 320);

  test('the eight layouts are well formed', () {
    expect(PhotoBoothTemplates.all.map((t) => t.key), [
      'classic_2',
      'classic_3',
      'classic_4',
      'vertical_strip',
      'polaroid',
      'vintage_film',
      'romantic_frame',
      'winter_frame',
    ]);

    for (final t in PhotoBoothTemplates.all) {
      final canvas = Offset.zero & t.canvasSize;
      for (final (i, slot) in t.slots.indexed) {
        expect(
          canvas.contains(slot.topLeft) &&
              canvas.contains(slot.bottomRight - const Offset(1, 1)),
          isTrue,
          reason: '${t.key} slot $i',
        );
        for (final other in t.slots.skip(i + 1)) {
          expect(
            slot.intersect(other).isEmpty ||
                slot.intersect(other).width <= 0 ||
                slot.intersect(other).height <= 0,
            isTrue,
            reason: '${t.key}: slots overlap',
          );
        }
      }
      if (t.captionArea != null) {
        expect(
          t.slots.every((s) => s.intersect(t.captionArea!).height <= 0),
          isTrue,
          reason: '${t.key}: caption covers a photo',
        );
      }
    }
  });

  test('photos of any shape fill their slot without distortion', () {
    for (final image in const [
      Size(3000, 4000),
      Size(4000, 3000),
      Size(1000, 1000),
      Size(500, 3000),
    ]) {
      for (final slot in const [
        Size(1040, 600),
        Size(600, 600),
        Size(500, 360),
        Size(940, 940),
      ]) {
        final src = PhotoBoothRenderer.coverSourceRect(image, slot);

        expect(
          src.width / src.height,
          closeTo(slot.width / slot.height, 1e-9),
          reason: '$image in $slot',
        );
        expect((Offset.zero & image).contains(src.topLeft), isTrue);
        expect(src.right, lessThanOrEqualTo(image.width + 1e-9));
        expect(src.bottom, lessThanOrEqualTo(image.height + 1e-9));
      }
    }
  });

  test('photos are decoded no larger than needed to cover their slot', () {
    final target = PhotoBoothExportService.decodeTargetSize(
      const Size(4000, 3000),
      const Size(600, 600),
    );
    expect(target, const Size(800, 600));

    // Never upscaled.
    expect(
      PhotoBoothExportService.decodeTargetSize(
        const Size(300, 200),
        const Size(600, 600),
      ),
      const Size(300, 200),
    );
  });

  test('output resolution follows the configured long side', () {
    for (final t in PhotoBoothTemplates.all) {
      final size = const PhotoBoothExportService().outputSize(t);
      expect(math.max(size.width, size.height), 2048, reason: t.key);
      expect(
        size.width / size.height,
        closeTo(t.aspectRatio, 0.002),
        reason: t.key,
      );
    }
    expect(
      const PhotoBoothExportService(longSide: 1024)
          .outputSize(PhotoBoothTemplates.verticalStrip),
      const Size(341, 1024),
    );
  });

  testWidgets('every template exports with no, some and all photos', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final t in PhotoBoothTemplates.all) {
        for (final count in {0, 1, t.photoCount}) {
          final photos = [
            for (var i = 0; i < count; i++)
              [portrait, landscape, square][i % 3],
          ];
          final result = await const PhotoBoothExportService(longSide: 800)
              .export(doc(t.key, photos));

          expect(
            math.max(result.width, result.height),
            800,
            reason: '${t.key} with $count',
          );
          expect(
            result.bytes.sublist(1, 4),
            utf8.encode('PNG'),
            reason: 'PNG output',
          );
        }
      }
    });
  });

  testWidgets('an unreadable photo becomes an empty slot instead of crashing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final result = await const PhotoBoothExportService(longSide: 400).export(
        doc('classic_2', [
          Uint8List.fromList([1, 2, 3]),
          square,
        ]),
      );

      expect(result.height, 400);
    });
  });

  testWidgets('the exported image matches the preview pixel for pixel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Widths that give whole-pixel heights, so both images have identical sizes.
    for (final (key, previewWidth) in [
      ('polaroid', 540.0),
      ('classic_4', 420.0),
      ('vintage_film', 300.0),
    ]) {
      final document = doc(key, [portrait, landscape, square, portrait]);
      final previewSize = Size(
        previewWidth,
        previewWidth / document.template.aspectRatio,
      );
      final boundary = GlobalKey();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: previewWidth,
              child: RepaintBoundary(
                key: boundary,
                child: PhotoBoothPreview(document: document),
              ),
            ),
          ),
        ),
      );
      // Let the preview decode its photos, then repaint.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      final (preview, exported) = (await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final previewImage = await render.toImage();
        final previewBytes = (await previewImage.toByteData())!.buffer
            .asUint8List();

        final export = await PhotoBoothExportService(
          longSide: math.max(previewSize.width, previewSize.height).round(),
        ).export(document);
        final codec = await ui.instantiateImageCodec(export.bytes);
        final exportImage = (await codec.getNextFrame()).image;
        expect(
          [exportImage.width, exportImage.height],
          [previewImage.width, previewImage.height],
          reason: key,
        );
        final exportBytes = (await exportImage.toByteData())!.buffer
            .asUint8List();

        return (previewBytes, exportBytes);
      }))!;

      var diff = 0;
      for (var i = 0; i < preview.length; i++) {
        diff += (preview[i] - exported[i]).abs();
      }
      expect(
        diff / preview.length,
        lessThan(1.0),
        reason: '$key: mean channel difference',
      );
    }
  });

  testWidgets(
    'four full-size camera photos export without decoding them at full size',
    (tester) async {
      await tester.runAsync(() async {
        final big = photo(3000, 4000, jpeg: true);
        final document = doc('classic_4', [big, big, big, big]);
        const service = PhotoBoothExportService();
        final scale =
            service.outputSize(document.template).width /
            document.template.canvasSize.width;

        final decoded = await PhotoBoothExportService.decodeForSlots(
          document,
          scale,
        );
        try {
          for (final (i, image) in decoded.indexed) {
            final slot = document.template.slots[i];
            expect(image, isNotNull);
            // 12 MP photo decoded to roughly the slot (~0.9 MP), not 12 MP.
            expect(
              image!.width * image.height,
              lessThan(slot.width * scale * slot.height * scale * 1.5),
            );
          }
        } finally {
          for (final image in decoded) {
            image?.dispose();
          }
        }

        final result = await service.export(document);
        expect(result.height, 2048);
      });
    },
  );

  test('templates match the backend catalog', () {
    final catalog = jsonDecode(
      File('../backend/database/data/appearance_catalog.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final entries = (catalog['photo_booth_templates'] as List)
        .cast<Map<String, dynamic>>();

    expect(
      entries.map((e) => e['key']),
      PhotoBoothTemplates.all.map((t) => t.key),
    );
    for (final entry in entries) {
      expect(
        entry['photo_slots'],
        PhotoBoothTemplates.byKey(entry['key'] as String)!.photoCount,
        reason: entry['key'] as String,
      );
    }
  });

  test('every theme suggests only templates that exist', () {
    final keys = PhotoBoothTemplates.all.map((t) => t.key).toSet();

    for (final theme in ThemeRegistry.all) {
      expect(
        keys.containsAll(theme.photoBoothTemplates),
        isTrue,
        reason: theme.key,
      );
    }
  });
}
