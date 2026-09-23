import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/features/home/data/models/date_model.dart';
import 'package:frontend/features/home/data/repositories/date_repository.dart';
import 'package:frontend/features/home/providers/date_providers.dart';
import 'package:frontend/features/home/providers/date_state.dart';

class MockDateRepository extends Mock implements DateRepository {}

DateModel createTestDate({
  int id = 1,
  String title = 'Dinner together',
  String status = 'planned',
}) {
  return DateModel(
    id: id,
    coupleId: 10,
    createdBy: 20,
    title: title,
    description: 'A nice dinner',
    location: 'Jakarta',
    scheduledAt: DateTime.parse('2026-09-25T19:00:00.000Z'),
    status: status,
    completedAt: null,
    createdAt: DateTime.parse('2026-09-20T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-20T10:00:00.000Z'),
  );
}

void main() {
  late MockDateRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockDateRepository();

    container = ProviderContainer(
      overrides: [dateRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('DateNotifier', () {
    test('initial state is initial', () {
      final state = container.read(dateNotifierProvider);

      expect(state.status, DateStatus.initial);
      expect(state.dates, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('loadDates changes state to loaded when dates exist', () async {
      final dates = [
        createTestDate(),
        createTestDate(id: 2, title: 'Movie night'),
      ];

      when(() => repository.getDates()).thenAnswer((_) async => dates);

      await container.read(dateNotifierProvider.notifier).loadDates();

      final state = container.read(dateNotifierProvider);

      expect(state.status, DateStatus.loaded);
      expect(state.dates, hasLength(2));
      expect(state.dates.first.title, 'Dinner together');
      expect(state.dates[1].title, 'Movie night');

      verify(() => repository.getDates()).called(1);
    });

    test('loadDates changes state to empty when no dates exist', () async {
      when(() => repository.getDates()).thenAnswer((_) async => []);

      await container.read(dateNotifierProvider.notifier).loadDates();

      final state = container.read(dateNotifierProvider);

      expect(state.status, DateStatus.empty);
      expect(state.dates, isEmpty);
      expect(state.errorMessage, isNull);

      verify(() => repository.getDates()).called(1);
    });

    test('loadDates changes state to error when ApiException occurs', () async {
      when(() => repository.getDates()).thenThrow(
        const ApiException(
          message: 'Unable to connect to the server.',
          statusCode: 500,
        ),
      );

      await container.read(dateNotifierProvider.notifier).loadDates();

      final state = container.read(dateNotifierProvider);

      expect(state.status, DateStatus.error);
      expect(state.errorMessage, 'Unable to connect to the server.');

      verify(() => repository.getDates()).called(1);
    });

    test('createDate creates date and reloads dates', () async {
      final createdDate = createTestDate();

      when(
        () => repository.createDate(
          title: 'Dinner together',
          description: 'A nice dinner',
          location: 'Jakarta',
          scheduledAt: DateTime.parse('2026-09-25T19:00:00.000Z'),
        ),
      ).thenAnswer((_) async => createdDate);

      when(() => repository.getDates()).thenAnswer((_) async => [createdDate]);

      final result = await container
          .read(dateNotifierProvider.notifier)
          .createDate(
            title: 'Dinner together',
            description: 'A nice dinner',
            location: 'Jakarta',
            scheduledAt: DateTime.parse('2026-09-25T19:00:00.000Z'),
          );

      final state = container.read(dateNotifierProvider);

      expect(result, isNotNull);
      expect(result!.id, 1);
      expect(result.title, 'Dinner together');

      expect(state.status, DateStatus.loaded);
      expect(state.dates, hasLength(1));
      expect(state.dates.first.title, 'Dinner together');

      verify(
        () => repository.createDate(
          title: 'Dinner together',
          description: 'A nice dinner',
          location: 'Jakarta',
          scheduledAt: DateTime.parse('2026-09-25T19:00:00.000Z'),
        ),
      ).called(1);

      verify(() => repository.getDates()).called(1);
    });
  });
}
