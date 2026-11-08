import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/photo_booth/domain/photo_booth_document.dart';
import 'package:frontend/features/photo_booth/presentation/photo_booth_screen.dart';
import 'package:frontend/features/photo_booth/providers/photo_booth_controller.dart';

import 'photo_booth_render_test.dart' show photo;

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Set<String>? available,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: PhotoBoothScreen(availableTemplates: available),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.text('Save to Memory'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ),
  );

  testWidgets('starts empty with save and share disabled', (tester) async {
    await pump(tester);

    expect(find.textContaining('Add photos to start'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(
      find.text('Sharing sends an unencrypted copy to the app you choose.'),
      findsOneWidget,
    );
  });

  testWidgets('offers only the layouts the server lists', (tester) async {
    await pump(tester, available: {'classic_2', 'polaroid'});

    expect(
      find.bySemanticsLabel(RegExp('^Classic 2|^Polaroid')),
      findsNWidgets(2),
    );
    expect(find.bySemanticsLabel(RegExp('^Vintage Film')), findsNothing);
  });

  testWidgets('without a server list every built-in layout is offered', (
    tester,
  ) async {
    await pump(tester);

    // Same matcher as above, so its findsNothing there is meaningful.
    expect(find.bySemanticsLabel(RegExp('^Vintage Film')), findsOneWidget);
  });

  testWidgets('adding photos enables saving and shows the fill count', (
    tester,
  ) async {
    final container = await pump(tester);

    await tester.runAsync(() async {
      container.read(photoBoothControllerProvider.notifier).addPhotos([
        photo(120, 160),
        Uint8List.fromList(photo(160, 120)),
      ], PhotoSourceKind.gallery);
    });
    await tester.pump();

    expect(find.textContaining('2 of 3 spots filled'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.byTooltip('Remove photo 1'), findsOneWidget);
  });
}
