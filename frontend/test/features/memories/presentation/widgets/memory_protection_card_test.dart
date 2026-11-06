import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/data/models/memory_protection_summary.dart';
import 'package:frontend/features/memories/presentation/widgets/memory_protection_card.dart';

void main() {
  MemoryProtectionSummary summary(Map<String, dynamic> json) =>
      MemoryProtectionSummary.fromJson(json);

  Future<void> pump(WidgetTester tester, MemoryProtectionSummary data) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MemoryProtectionCard(summary: data))),
    );
  }

  test('parses the server summary', () {
    final s = summary({
      'photos': 24,
      'protected': 22,
      'backing_up': 2,
      'restoring': 0,
      'needs_attention': 0,
      'uploading': 1,
      'upload_failed': 0,
      'state': 'backing_up',
      'last_integrity_check_at': '2026-11-06T09:30:00.000000Z',
      'last_verified_backup_at': null,
    });

    expect(s.photos, 24);
    expect(s.protected, 22);
    expect(s.backingUp, 2);
    expect(s.uploading, 1);
    expect(s.isFullyProtected, isFalse);
    expect(s.lastIntegrityCheckAt, DateTime.utc(2026, 11, 6, 9, 30));
    expect(s.lastVerifiedBackupAt, isNull);
  });

  testWidgets('pending backups are shown and never called fully protected', (
    tester,
  ) async {
    await pump(
      tester,
      summary({'photos': 24, 'protected': 22, 'backing_up': 2, 'state': 'backing_up'}),
    );

    expect(find.text('Memory Protection ❤️'), findsOneWidget);
    expect(find.text('Some photos are still being backed up'), findsOneWidget);
    expect(find.text('All your photos are safely backed up'), findsNothing);
    expect(find.text('Backing up'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('Last verified backup: not yet'), findsOneWidget);
  });

  testWidgets('fully protected only when the server says so', (tester) async {
    await pump(tester, summary({'photos': 3, 'protected': 3, 'state': 'protected'}));

    expect(find.text('All your photos are safely backed up'), findsOneWidget);
    expect(find.text('Backing up'), findsNothing);
  });

  testWidgets('problems are surfaced without technical details', (tester) async {
    await pump(
      tester,
      summary({'photos': 3, 'protected': 2, 'needs_attention': 1, 'state': 'needs_attention'}),
    );

    expect(find.text('Some photos need attention'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.textContaining('checksum'), findsNothing);
    expect(find.textContaining('storage'), findsNothing);
  });

  testWidgets('a failed upload says the photo is still on the phone', (
    tester,
  ) async {
    await pump(
      tester,
      summary({'photos': 1, 'protected': 1, 'upload_failed': 1, 'state': 'needs_attention'}),
    );

    expect(find.textContaining('still on your phone'), findsOneWidget);
  });

  test('formats check times relative to today', () {
    final now = DateTime(2026, 11, 6, 12);

    expect(MemoryProtectionCard.formatWhen(DateTime(2026, 11, 6, 9, 30), now: now), 'Today, 09:30');
    expect(MemoryProtectionCard.formatWhen(DateTime(2026, 11, 5, 23, 5), now: now), 'Yesterday, 23:05');
    expect(MemoryProtectionCard.formatWhen(DateTime(2026, 10, 1, 8, 0), now: now), '1/10/2026, 08:00');
  });

  test('photo model reads protection fields and tolerates a deleted uploader', () {
    final photo = MemoryPhotoModel.fromJson({
      'id': 1,
      'memory_id': 2,
      'uploaded_by': null,
      'mime_type': 'image/jpeg',
      'file_size': 10,
      'status': 'verified',
      'sort_order': 0,
      'protection_status': 'backing_up',
      'restorable_until': '2026-12-06T00:00:00.000000Z',
    });

    expect(photo.uploadedBy, isNull);
    expect(photo.protectionStatus, 'backing_up');
    expect(photo.restorableUntil, DateTime.utc(2026, 12, 6));
  });
}
