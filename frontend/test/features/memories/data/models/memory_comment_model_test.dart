import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/memories/data/models/memory_comment_model.dart';

void main() {
  test('MemoryCommentModel parses nested user correctly', () {
    final model = MemoryCommentModel.fromJson({
      'id': 1,
      'memory_id': 10,
      'user': {'id': 20, 'name': 'Test User'},
      'body': 'This was a beautiful day ❤️',
      'created_at': '2026-09-20T10:00:00.000000Z',
      'updated_at': '2026-09-20T10:00:00.000000Z',
    });

    expect(model.id, 1);
    expect(model.memoryId, 10);
    expect(model.userId, 20);
    expect(model.userName, 'Test User');
    expect(model.body, 'This was a beautiful day ❤️');
  });
}
