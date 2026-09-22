import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/home/data/repositories/date_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late DateRepository repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = DateRepository(apiClient);
  });

  group('DateRepository', () {
    test('getDates parses dates correctly', () async {
      when(() => apiClient.get<dynamic>('/dates')).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/dates'),
          data: {
            'success': true,
            'message': 'Dates retrieved successfully.',
            'data': {
              'dates': [
                {
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
                },
              ],
            },
          },
          statusCode: 200,
        ),
      );

      final dates = await repository.getDates();

      expect(dates, hasLength(1));
      expect(dates.first.id, 1);
      expect(dates.first.title, 'Dinner together');
      expect(dates.first.location, 'Jakarta');

      verify(() => apiClient.get<dynamic>('/dates')).called(1);
    });

    test('getDateById parses date correctly', () async {
      when(() => apiClient.get<dynamic>('/dates/1')).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/dates/1'),
          data: {
            'success': true,
            'message': 'Date retrieved successfully.',
            'data': {
              'date': {
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
              },
            },
          },
          statusCode: 200,
        ),
      );

      final date = await repository.getDateById(1);

      expect(date.id, 1);
      expect(date.title, 'Dinner together');
      expect(date.status, 'planned');

      verify(() => apiClient.get<dynamic>('/dates/1')).called(1);
    });

    test('createDate sends correct payload', () async {
      final scheduledAt = DateTime.parse('2026-09-25T19:00:00.000Z');

      when(() => apiClient.post<dynamic>('/dates', data: any(named: 'data')))
          .thenAnswer(
            (_) async => Response<dynamic>(
              requestOptions: RequestOptions(path: '/dates'),
              data: {
                'success': true,
                'message': 'Date created successfully.',
                'data': {
                  'date': {
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
                  },
                },
              },
              statusCode: 201,
            ),
          );

      final date = await repository.createDate(
        title: 'Dinner together',
        description: 'A nice dinner',
        location: 'Jakarta',
        scheduledAt: scheduledAt,
      );

      expect(date.id, 1);
      expect(date.title, 'Dinner together');

      final captured =
          verify(
                () => apiClient.post<dynamic>(
                  '/dates',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(captured['title'], 'Dinner together');
      expect(captured['description'], 'A nice dinner');
      expect(captured['location'], 'Jakarta');
      expect(captured['scheduled_at'], scheduledAt.toIso8601String());
    });

    test('completeDate calls correct endpoint', () async {
      when(() => apiClient.post<dynamic>('/dates/1/complete')).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/dates/1/complete'),
          data: {
            'success': true,
            'message': 'Date completed successfully.',
            'data': {
              'date': {
                'id': 1,
                'couple_id': 10,
                'created_by': 20,
                'title': 'Dinner together',
                'description': null,
                'location': null,
                'scheduled_at': '2026-09-25T19:00:00.000Z',
                'status': 'completed',
                'completed_at': '2026-09-25T21:00:00.000Z',
                'created_at': null,
                'updated_at': null,
              },
            },
          },
          statusCode: 200,
        ),
      );

      final date = await repository.completeDate(1);

      expect(date.id, 1);
      expect(date.status, 'completed');

      verify(() => apiClient.post<dynamic>('/dates/1/complete')).called(1);
    });

    test('cancelDate calls correct endpoint', () async {
      when(() => apiClient.post<dynamic>('/dates/1/cancel')).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/dates/1/cancel'),
          data: {
            'success': true,
            'message': 'Date cancelled successfully.',
            'data': {
              'date': {
                'id': 1,
                'couple_id': 10,
                'created_by': 20,
                'title': 'Dinner together',
                'description': null,
                'location': null,
                'scheduled_at': '2026-09-25T19:00:00.000Z',
                'status': 'cancelled',
                'completed_at': null,
                'created_at': null,
                'updated_at': null,
              },
            },
          },
          statusCode: 200,
        ),
      );

      final date = await repository.cancelDate(1);

      expect(date.id, 1);
      expect(date.status, 'cancelled');

      verify(() => apiClient.post<dynamic>('/dates/1/cancel')).called(1);
    });
  });
}
