import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/observability/crash_reporter.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/account/presentation/account_screen.dart';
import 'package:frontend/features/auth/data/models/auth_response_model.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository.dart';
import 'package:frontend/features/auth/providers/auth_dependencies.dart';
import 'package:frontend/features/auth/providers/auth_providers.dart';
import 'package:frontend/features/auth/providers/auth_state.dart';
import 'package:frontend/features/device/services/device_registration_service.dart';
import 'package:frontend/features/home/data/models/date_model.dart';
import 'package:frontend/features/memories/data/models/memory_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

class _MockDevices extends Mock implements DeviceRegistrationService {}

/// In-memory TokenStorage (the real one needs the platform keystore).
class _FakeTokens implements TokenStorage {
  String? token;
  DateTime? expiresAt;

  @override
  Future<void> saveToken(String value, {DateTime? expiresAt}) async {
    token = value;
    this.expiresAt = expiresAt;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<DateTime?> getExpiresAt() async => expiresAt;

  @override
  Future<void> deleteToken() async {
    token = null;
    expiresAt = null;
  }
}

UserModel _user() => UserModel.fromJson({
  'id': 1,
  'name': 'Alice',
  'email': 'alice@example.com',
});

void main() {
  late _MockRepo repo;
  late _FakeTokens tokens;
  late ProviderContainer container;

  setUp(() {
    repo = _MockRepo();
    tokens = _FakeTokens();
    final devices = _MockDevices();
    when(() => devices.registerCurrentDevice()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStorageProvider.overrideWithValue(tokens),
        deviceRegistrationServiceProvider.overrideWithValue(devices),
      ],
    );
  });

  tearDown(() => container.dispose());

  AuthState state() => container.read(authNotifierProvider);

  group('session start', () {
    test(
      'offline start keeps the saved session and reports an error',
      () async {
        tokens.token = 'saved';
        tokens.expiresAt = DateTime.now().add(const Duration(days: 50));
        when(() => repo.me()).thenThrow(
          const ApiException(message: 'Unable to connect to the server.'),
        );

        await container.read(authNotifierProvider.notifier).checkAuth();

        expect(state().status, AuthStatus.error);
        expect(
          tokens.token,
          'saved',
          reason: 'a bad network must not log the user out',
        );
      },
    );

    test('a 401 clears the session', () async {
      tokens.token = 'revoked';
      when(() => repo.me()).thenThrow(
        const ApiException(message: 'Unauthenticated.', statusCode: 401),
      );

      await container.read(authNotifierProvider.notifier).checkAuth();

      expect(state().status, AuthStatus.unauthenticated);
      expect(tokens.token, isNull);
    });

    test('a token far from expiry is not refreshed', () async {
      tokens.token = 'fresh';
      tokens.expiresAt = DateTime.now().add(const Duration(days: 50));
      when(() => repo.me()).thenAnswer((_) async => _user());

      await container.read(authNotifierProvider.notifier).checkAuth();

      expect(state().status, AuthStatus.authenticated);
      verifyNever(() => repo.refreshToken());
    });

    test('a token close to expiry (or of unknown age) is rotated', () async {
      tokens.token = 'old';
      tokens.expiresAt = DateTime.now().add(const Duration(days: 3));
      final newExpiry = DateTime.now().add(const Duration(days: 60));
      when(() => repo.me()).thenAnswer((_) async => _user());
      when(() => repo.refreshToken()).thenAnswer(
        (_) async => AuthTokenModel(token: 'new', expiresAt: newExpiry),
      );

      await container.read(authNotifierProvider.notifier).checkAuth();

      expect(state().status, AuthStatus.authenticated);
      expect(tokens.token, 'new');
      expect(tokens.expiresAt, newExpiry);
    });

    test('a failed refresh keeps the still-valid token', () async {
      tokens.token = 'old';
      when(() => repo.me()).thenAnswer((_) async => _user());
      when(
        () => repo.refreshToken(),
      ).thenThrow(const ApiException(message: 'Server error', statusCode: 500));

      await container.read(authNotifierProvider.notifier).checkAuth();

      expect(state().status, AuthStatus.authenticated);
      expect(tokens.token, 'old');
    });

    test('login stores the token expiry', () async {
      final expiry = DateTime.utc(2027, 1, 1);
      when(
        () => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => AuthResponseModel(
          token: 't',
          user: _user(),
          tokenExpiresAt: expiry,
        ),
      );

      await container
          .read(authNotifierProvider.notifier)
          .login(email: 'a@b.c', password: 'pw');

      expect(tokens.expiresAt, expiry);
    });
  });

  group('account deletion', () {
    test('success clears local credentials and signs out', () async {
      tokens.token = 'session';
      when(() => repo.deleteAccount(password: 'pw'))
          .thenAnswer((_) async => 'kept_by_partner');

      final outcome = await container
          .read(authNotifierProvider.notifier)
          .deleteAccount(password: 'pw');

      expect(outcome, 'kept_by_partner');
      expect(tokens.token, isNull);
      expect(state().status, AuthStatus.unauthenticated);
    });

    test('a wrong password keeps the user signed in', () async {
      tokens.token = 'session';
      when(() => repo.deleteAccount(password: 'bad')).thenThrow(
        const ApiException(
          message: 'password: The password is incorrect.',
          statusCode: 422,
        ),
      );

      await expectLater(
        container
            .read(authNotifierProvider.notifier)
            .deleteAccount(password: 'bad'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.token, 'session');
    });

    testWidgets('dialog only allows deletion after password + confirmation', (
      tester,
    ) async {
      String? result = 'unset';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showDialog<String>(
                context: context,
                builder: (_) => const DeleteAccountDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      FilledButton submit() => tester.widget<FilledButton>(
        find.byKey(const Key('delete-account-submit')),
      );
      expect(submit().onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('delete-account-password')),
        'secret-pw',
      );
      await tester.pump();
      expect(
        submit().onPressed,
        isNull,
        reason: 'confirmation checkbox still unticked',
      );

      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-account-submit')));
      await tester.pumpAndSettle();

      expect(result, 'secret-pw');
    });
  });

  group('release configuration', () {
    test('dev builds may use the local HTTP API', () {
      expect(
        () => AppConfig.validate(
          url: 'http://10.0.2.2:8000/api/v1',
          environment: 'dev',
          isRelease: false,
        ),
        returnsNormally,
      );
    });

    test('release and non-dev builds require HTTPS and a real host', () {
      expect(
        () => AppConfig.validate(
          url: 'http://10.0.2.2:8000/api/v1',
          environment: 'dev',
          isRelease: true,
        ),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(
          url: 'http://api.example.com/api/v1',
          environment: 'production',
          isRelease: true,
        ),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(
          url: 'https://localhost/api/v1',
          environment: 'staging',
          isRelease: true,
        ),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(
          url: 'https://api.example.com/api/v1',
          environment: 'qa',
          isRelease: true,
        ),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(
          url: 'https://api.example.com/api/v1',
          environment: 'production',
          isRelease: true,
        ),
        returnsNormally,
      );
    });

    test('crash text is scrubbed of tokens, recovery keys and emails', () {
      final scrubbed = CrashReporter.scrub(
        'DioException Bearer 12|abcdefghijABCDEFGHIJabcdefghijABCDEFGHIJxyz for alice@example.com '
        'key ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567-ABCD-EFGH-IJKL-MNOP-QRST url ?token=abc&page=2',
      );

      for (final secret in [
        'abcdefghij',
        'alice@example.com',
        'ABCD-EFGH',
        'token=abc',
      ]) {
        expect(scrubbed, isNot(contains(secret)));
      }
      expect(scrubbed, contains('page=2'));
    });
  });

  group('content of deleted accounts', () {
    test('dates and memories without an author still parse', () {
      final date = DateModel.fromJson({
        'id': 1,
        'couple_id': 1,
        'created_by': null,
        'title': 'Picnic',
        'description': null,
        'location': null,
        'scheduled_at': '2026-11-10T10:00:00.000Z',
        'status': 'planned',
        'completed_at': null,
        'created_at': '2026-11-01T10:00:00.000Z',
        'updated_at': '2026-11-01T10:00:00.000Z',
      });
      expect(date.createdBy, isNull);

      final memory = MemoryModel.fromJson({
        'id': 1,
        'couple_id': 1,
        'created_by': null,
        'title': 'Beach',
        'description': null,
        'memory_date': '2026-10-01',
        'location_name': null,
        'location_address': null,
        'latitude': null,
        'longitude': null,
        'created_at': '2026-11-01T10:00:00.000Z',
        'updated_at': '2026-11-01T10:00:00.000Z',
      });
      expect(memory.createdBy, isNull);
    });
  });
}
