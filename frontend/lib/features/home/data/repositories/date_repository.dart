import '../../../../core/network/api_client.dart';
import '../models/date_model.dart';
import '../models/date_comment_model.dart';

class DateRepository {
  DateRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DateModel>> getDates() async {
    final response = await _apiClient.get('/dates');

    final data = response.data['data'] as Map<String, dynamic>;

    final dates = data['dates'] as List<dynamic>? ?? [];

    return dates
        .map((date) => DateModel.fromJson(date as Map<String, dynamic>))
        .toList();
  }

  Future<DateModel> createDate({
    required String title,
    String? description,
    String? location,
    required DateTime scheduledAt,
  }) async {
    final response = await _apiClient.post(
      '/dates',
      data: {
        'title': title,
        'description': description,
        'location': location,
        'scheduled_at': scheduledAt.toIso8601String(),
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;

    final dateData = data['date'] as Map<String, dynamic>;

    return DateModel.fromJson(dateData);
  }

  Future<DateModel> updateDate({
    required int dateId,
    required String title,
    String? description,
    String? location,
    required DateTime scheduledAt,
  }) async {
    final response = await _apiClient.patch(
      '/dates/$dateId',
      data: {
        'title': title,
        'description': description,
        'location': location,
        'scheduled_at': scheduledAt.toIso8601String(),
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;

    final dateData = data['date'] as Map<String, dynamic>;

    return DateModel.fromJson(dateData);
  }

  Future<DateModel> getDateById(int dateId) async {
    final response = await _apiClient.get('/dates/$dateId');

    final data = response.data['data'] as Map<String, dynamic>;

    final dateData = data['date'] as Map<String, dynamic>;

    return DateModel.fromJson(dateData);
  }

  Future<List<DateCommentModel>> getComments(int dateId) async {
    final response = await _apiClient.get('/dates/$dateId/comments');

    final data = response.data['data'] as Map<String, dynamic>;

    final comments = data['comments'] as List<dynamic>? ?? [];

    return comments
        .map(
          (comment) =>
              DateCommentModel.fromJson(comment as Map<String, dynamic>),
        )
        .toList();
  }

  Future<DateCommentModel> createComment({
    required int dateId,
    required String content,
  }) async {
    final response = await _apiClient.post(
      '/dates/$dateId/comments',
      data: {'content': content},
    );

    final data = response.data['data'] as Map<String, dynamic>;

    final commentData = data['comment'] as Map<String, dynamic>;

    return DateCommentModel.fromJson(commentData);
  }

  Future<DateModel> completeDate(int dateId) async {
    final response = await _apiClient.post('/dates/$dateId/complete');

    final data = response.data['data'] as Map<String, dynamic>;

    final dateData = data['date'] as Map<String, dynamic>;

    return DateModel.fromJson(dateData);
  }

  Future<DateModel> cancelDate(int dateId) async {
    final response = await _apiClient.post('/dates/$dateId/cancel');

    final data = response.data['data'] as Map<String, dynamic>;

    final dateData = data['date'] as Map<String, dynamic>;

    return DateModel.fromJson(dateData);
  }
}
