import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/photo_booth/domain/photo_booth_document.dart';
import 'package:frontend/features/photo_booth/render/photo_booth_export_service.dart';
import 'package:frontend/features/photo_booth/render/photo_booth_preview.dart';
import 'package:frontend/features/photo_booth/render/photo_booth_renderer.dart';

import 'photo_booth_render_test.dart' show doc, photo;

void main() {
  group('framed crop', () {
    const image = Size(3000, 4000);
    const slot = Size(1040, 600);

    test('centred framing is the plain cover crop', () {
      expect(
        PhotoBoothRenderer.framedSourceRect(
          image,
          slot,
          PhotoFraming.centered,
        ),
        PhotoBoothRenderer.coverSourceRect(image, slot),
      );
    });

    test('zoom shrinks the crop around the focus, keeping the aspect', () {
      final cover = PhotoBoothRenderer.coverSourceRect(image, slot);
      final zoomed = PhotoBoothRenderer.framedSourceRect(
        image,
        slot,
        const PhotoFraming(focus: Offset(0.5, 0.3), zoom: 2),
      );

      expect(zoomed.width, closeTo(cover.width / 2, 1e-9));
      expect(zoomed.height, closeTo(cover.height / 2, 1e-9));
      expect(zoomed.center.dx, closeTo(1500, 1e-9));
      expect(zoomed.center.dy, closeTo(1200, 1e-9));
    });

    test('any focus and zoom stays inside the photo without distortion', () {
      for (final image in const [
        Size(3000, 4000),
        Size(4000, 3000),
        Size(500, 3000),
      ]) {
        for (final slot in const [Size(1040, 600), Size(500, 360)]) {
          for (final focus in const [
            Offset.zero,
            Offset(1, 1),
            Offset(-3, 0.5),
            Offset(0.5, 7),
          ]) {
            for (final zoom in const [1.0, 1.7, 4.0]) {
              final src = PhotoBoothRenderer.framedSourceRect(
                image,
                slot,
                PhotoFraming(focus: focus, zoom: zoom),
              );
              final reason = '$image in $slot, focus $focus x$zoom';

              expect(
                src.width / src.height,
                closeTo(slot.width / slot.height, 1e-9),
                reason: reason,
              );
              expect(src.left, greaterThanOrEqualTo(-1e-9), reason: reason);
              expect(src.top, greaterThanOrEqualTo(-1e-9), reason: reason);
              expect(src.right, lessThanOrEqualTo(image.width + 1e-9));
              expect(src.bottom, lessThanOrEqualTo(image.height + 1e-9));
            }
          }
        }
      }
    });

    testWidgets('a zoomed photo is decoded sharper, never above its own size', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final base = doc('polaroid', [photo(1200, 1200)]);
        final zoomed = base.copyWith(
          photos: [
            base.photos.single.copyWith(
              framing: const PhotoFraming(zoom: 2),
            ),
          ],
        );
        final maxed = base.copyWith(
          photos: [
            base.photos.single.copyWith(
              framing: const PhotoFraming(zoom: 4),
            ),
          ],
        );

        final plain = (await PhotoBoothExportService.decodeForSlots(
          base,
          0.5,
        )).single!;
        final sharp = (await PhotoBoothExportService.decodeForSlots(
          zoomed,
          0.5,
        )).single!;
        final capped = (await PhotoBoothExportService.decodeForSlots(
          maxed,
          0.5,
        )).single!;

        expect(sharp.width, closeTo(plain.width * 2, 2));
        expect(capped.width, 1200);

        plain.dispose();
        sharp.dispose();
        capped.dispose();
      });
    });
  });

  group('adjusting a photo in the preview', () {
    late List<(String, PhotoFraming)> changes;

    setUp(() => changes = []);

    // Polaroid: one big slot at the top, so the middle of it is a photo and the
    // bottom strip is frame.
    Future<PhotoBoothDocument> pumpPreview(
      WidgetTester tester, {
      double width = 300,
    }) async {
      final document = doc('polaroid', [photo(600, 900)]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: PhotoBoothPreview(
                      key: const Key('preview'),
                      document: document,
                      onFramingChanged: (id, f) => changes.add((id, f)),
                    ),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      return document;
    }

    Offset slotCenter(WidgetTester tester, PhotoBoothDocument document) {
      final box = tester.getRect(find.byKey(const Key('preview')));
      final scale = box.width / document.template.canvasSize.width;
      return box.topLeft + document.template.slots.first.center * scale;
    }

    testWidgets('dragging a photo moves it and does not scroll the page', (
      tester,
    ) async {
      final document = await pumpPreview(tester);
      final before = tester.getTopLeft(find.byKey(const Key('preview')));

      // Finger moves up: the photo follows, so more of its lower part shows.
      await tester.timedDragFrom(
        slotCenter(tester, document),
        const Offset(0, -60),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(changes, hasLength(1));
      final (id, framing) = changes.single;
      expect(id, document.photos.single.id);
      expect(framing.focus.dy, greaterThan(0.5));
      expect(framing.focus.dx, closeTo(0.5, 0.02));
      expect(framing.zoom, 1);
      expect(tester.getTopLeft(find.byKey(const Key('preview'))), before);
    });

    testWidgets('dragging outside the photos scrolls the page instead', (
      tester,
    ) async {
      final document = await pumpPreview(tester);
      final box = tester.getRect(find.byKey(const Key('preview')));
      final scale = box.width / document.template.canvasSize.width;
      final slot = document.template.slots.first;
      // On the frame, below the photo.
      final frame = Offset(
        box.center.dx,
        box.top + (slot.bottom * scale + box.bottom) / 2,
      );

      // Gradual, like a real finger: the page's drag wins its slop first.
      await tester.timedDragFrom(
        frame,
        const Offset(0, -100),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(changes, isEmpty);
      expect(
        tester.getTopLeft(find.byKey(const Key('preview'))).dy,
        lessThan(box.top),
      );
    });

    testWidgets('pinching zooms the photo in', (tester) async {
      final document = await pumpPreview(tester);
      final center = slotCenter(tester, document);

      final a = await tester.startGesture(center - const Offset(20, 0));
      final b = await tester.startGesture(center + const Offset(20, 0));
      for (var i = 1; i <= 5; i++) {
        await a.moveTo(center - Offset(20.0 + i * 8, 0));
        await b.moveTo(center + Offset(20.0 + i * 8, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();

      expect(changes, hasLength(1));
      expect(changes.single.$2.zoom, greaterThan(1.5));
    });

    testWidgets('double-tapping a moved photo re-centres it', (tester) async {
      final document = await pumpPreview(tester);
      final moved = document.copyWith(
        photos: [
          document.photos.single.copyWith(
            framing: const PhotoFraming(focus: Offset(0.5, 0.8), zoom: 2),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: PhotoBoothPreview(
                key: const Key('preview'),
                document: moved,
                onFramingChanged: (id, f) => changes.add((id, f)),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      final center = slotCenter(tester, moved);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 100));
      expect(changes, isEmpty, reason: 'a single tap changes nothing');

      await tester.tapAt(center);
      await tester.pumpAndSettle();

      expect(changes.single.$2, PhotoFraming.centered);
    });

    testWidgets('a preview without a callback is read-only', (tester) async {
      final document = doc('polaroid', [photo(600, 900)]);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            child: PhotoBoothPreview(document: document),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(PhotoBoothPreview),
          matching: find.byType(RawGestureDetector),
        ),
        findsNothing,
      );
    });
  });
}
