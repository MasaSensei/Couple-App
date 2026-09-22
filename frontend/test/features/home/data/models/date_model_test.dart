import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/data/models/date_model.dart';

void main() {
  group('DateModel', () {
    test('parses valid JSON correctly', () {
      final json = {
        'id': 1,
        'couple_id': 10,
        'created_by': 20,
        'title': 'Dinner together',
        'description': 'A nice dinner',
        'location': 'Jakarta',
        'scheduled_at': '2026-09-25T19:00:00.000Z',
        'status': 'planned',
        'completed_at': null,
        'created_at': '2026-09-20T10:00:00.000Z',
        'updated_at': '2026-09-20T10:00:00.000Z',
      };

      final date = DateModel.fromJson(json);

      expect(date.id, 1);
      expect(date.coupleId, 10);
      expect(date.createdBy, 20);
      expect(date.title, 'Dinner together');
      expect(date.description, 'A nice dinner');
      expect(date.location, 'Jakarta');
      expect(date.status, 'planned');
      expect(date.completedAt, isNull);
      expect(date.scheduledAt.toUtc(), isNotNull);
    });

    test('parses nullable fields correctly', () {
      final json = {
        'id': 2,
        'couple_id': 10,
        'created_by': 20,
        'title': 'Walk together',
        'description': null,
        'location': null,
        'scheduled_at': '2026-09-26T08:00:00.000Z',
        'status': 'completed',
        'completed_at': '2026-09-26T10:00:00.000Z',
        'created_at': null,
        'updated_at': null,
      };

      final date = DateModel.fromJson(json);

      expect(date.description, isNull);
      expect(date.location, isNull);
      expect(date.completedAt, isNotNull);
      expect(date.createdAt, isNull);
      expect(date.updatedAt, isNull);
    });
  });
}
