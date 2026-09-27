import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';

void main() {
  test('MemoryPhotoModel parses JSON correctly', () {
    final model = MemoryPhotoModel.fromJson({
      'id': 1,
      'memory_id': 10,
      'uploaded_by': 20,
      'original_filename': 'dinner.jpg',
      'mime_type': 'image/jpeg',
      'file_size': 102400,
      'width': 1920,
      'height': 1080,
      'status': 'verified',
      'sort_order': 0,
      'created_at': '2026-09-20T10:00:00.000000Z',
      'updated_at': '2026-09-20T10:01:00.000000Z',
    });

    expect(model.id, 1);
    expect(model.memoryId, 10);
    expect(model.uploadedBy, 20);
    expect(model.originalFilename, 'dinner.jpg');
    expect(model.mimeType, 'image/jpeg');
    expect(model.fileSize, 102400);
    expect(model.width, 1920);
    expect(model.height, 1080);
    expect(model.status, 'verified');
  });
}
