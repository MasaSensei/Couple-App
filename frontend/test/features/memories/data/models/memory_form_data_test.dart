import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/memories/data/models/memory_form_data.dart';

void main() {
  group('MemoryFormData', () {
    test('converts data to API payload', () {
      final data = MemoryFormData(
        title: 'Our First Date',
        description: 'A wonderful day together.',
        memoryDate: DateTime(2026, 9, 19),
        locationName: 'Jakarta',
        locationAddress: 'Central Jakarta',
        latitude: -6.2,
        longitude: 106.816666,
        dateId: 10,
      );

      expect(data.toJson(), {
        'title': 'Our First Date',
        'description': 'A wonderful day together.',
        'memory_date': '2026-09-19',
        'location_name': 'Jakarta',
        'location_address': 'Central Jakarta',
        'latitude': -6.2,
        'longitude': 106.816666,
        'date_id': 10,
      });
    });

    test('allows optional fields to be null', () {
      final data = MemoryFormData(
        title: 'Simple Memory',
        memoryDate: DateTime(2026, 9, 19),
      );

      final json = data.toJson();

      expect(json['title'], 'Simple Memory');
      expect(json['memory_date'], '2026-09-19');
      expect(json['description'], isNull);
      expect(json['location_name'], isNull);
      expect(json['location_address'], isNull);
      expect(json['latitude'], isNull);
      expect(json['longitude'], isNull);
      expect(json['date_id'], isNull);
    });
  });
}
