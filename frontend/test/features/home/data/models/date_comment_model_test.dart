import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/data/models/date_comment_model.dart';

void main() {
  group('DateCommentModel', () {
    test('parses comment with user correctly', () {
      final json = {
        'id': 1,
        'date_id': 10,
        'user_id': 20,
        'user': {'id': 20, 'name': 'Test User'},
        'content': 'That was a lovely day.',
        'created_at': '2026-09-20T10:00:00.000Z',
        'updated_at': '2026-09-20T10:00:00.000Z',
      };

      final comment = DateCommentModel.fromJson(json);

      expect(comment.id, 1);
      expect(comment.dateId, 10);
      expect(comment.userId, 20);
      expect(comment.userName, 'Test User');
      expect(comment.content, 'That was a lovely day.');
      expect(comment.createdAt, isNotNull);
      expect(comment.updatedAt, isNotNull);
    });

    test('handles missing user correctly', () {
      final json = {
        'id': 2,
        'date_id': 10,
        'user_id': 20,
        'user': null,
        'content': 'Private thought.',
        'created_at': null,
        'updated_at': null,
      };

      final comment = DateCommentModel.fromJson(json);

      expect(comment.userName, isNull);
      expect(comment.createdAt, isNull);
      expect(comment.updatedAt, isNull);
    });
  });
}
