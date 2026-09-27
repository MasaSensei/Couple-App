import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/memories/data/models/memory_model.dart';

void main() {
  test('MemoryModel parses JSON correctly', () {
    final model = MemoryModel.fromJson({
      'id': 1,
      'couple_id': 10,
      'created_by': 20,
      'date_id': 30,
      'title': 'Dinner Together',
      'description': 'Our dinner date ❤️',
      'memory_date': '2026-09-20',
      'location_name': 'Kemang',
      'location_address': 'Jakarta',
      'latitude': '-6.2000000',
      'longitude': '106.8000000',
      'created_at': '2026-09-20T10:00:00.000000Z',
      'updated_at': '2026-09-20T10:30:00.000000Z',
    });

    expect(model.id, 1);
    expect(model.coupleId, 10);
    expect(model.createdBy, 20);
    expect(model.dateId, 30);

    expect(model.title, 'Dinner Together');
    expect(model.description, 'Our dinner date ❤️');

    expect(model.memoryDate, DateTime.parse('2026-09-20'));

    expect(model.locationName, 'Kemang');
    expect(model.latitude, -6.2);
    expect(model.longitude, 106.8);
  });
}
