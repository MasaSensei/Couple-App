import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_definition.dart';
import 'package:frontend/features/appearance/data/appearance_local_store.dart';
import 'package:frontend/features/appearance/providers/appearance_controller.dart';
import 'package:frontend/features/auth/data/models/couple_model.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_providers.dart';
import 'package:frontend/features/auth/providers/auth_state.dart';
import 'package:frontend/features/home/data/models/date_model.dart';
import 'package:frontend/features/home/providers/couple_notifier.dart';
import 'package:frontend/features/home/providers/couple_providers.dart';
import 'package:frontend/features/home/providers/couple_state.dart';
import 'package:frontend/features/home/providers/date_notifier.dart';
import 'package:frontend/features/home/providers/date_providers.dart';
import 'package:frontend/features/home/providers/date_state.dart';
import 'package:frontend/features/memories/data/models/memory_model.dart';
import 'package:frontend/features/memories/providers/memory_notifier.dart';
import 'package:frontend/features/memories/providers/memory_providers.dart';
import 'package:frontend/features/memories/providers/memory_state.dart';
import 'package:frontend/features/privacy/providers/privacy_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/appearance/appearance_fakes.dart';

/// Example data for screen-level layout and theme checks (tests only).
final sampleNow = DateTime.now();
const sampleMe = UserModel(
  id: 1,
  name: 'Raka Pratama',
  email: 'raka@example.test',
);
const samplePartner = UserModel(
  id: 2,
  name: 'Nadia',
  email: 'nadia@example.test',
);

final sampleCouple = CoupleModel(
  id: 7,
  inviteCode: 'ABCD1234',
  members: const [sampleMe, samplePartner],
  createdAt: DateTime(2025, 3, 2),
  relationshipStartedAt: DateTime(2025, 9, 22),
);

DateModel _date(
  int id,
  String title,
  DateTime at,
  String status, {
  int createdBy = 1,
  String? location,
  String? description,
  DateTime? createdAt,
}) => DateModel(
  id: id,
  coupleId: 7,
  createdBy: createdBy,
  title: title,
  description: description,
  location: location,
  scheduledAt: at,
  status: status,
  completedAt: status == 'completed' ? at : null,
  createdAt: createdAt,
  updatedAt: createdAt,
);

List<DateModel> sampleDates() => [
  _date(
    1,
    'Dinner at the little corner café by the river',
    sampleNow.add(const Duration(days: 3, hours: 2)),
    'planned',
    createdBy: 2,
    location: 'Seminyak',
    description: 'Book the window table.',
    createdAt: sampleNow.subtract(const Duration(hours: 5)),
  ),
  _date(
    2,
    'Pottery class',
    sampleNow.add(const Duration(days: 9)),
    'planned',
    location: 'Ubud',
    createdAt: sampleNow.subtract(const Duration(days: 2)),
  ),
  _date(
    3,
    'Rice terrace hike',
    sampleNow.subtract(const Duration(days: 6)),
    'completed',
    createdAt: sampleNow.subtract(const Duration(days: 20)),
  ),
  _date(
    4,
    'Beach picnic',
    sampleNow.subtract(const Duration(days: 40)),
    'cancelled',
    createdBy: 2,
  ),
];

List<MemoryModel> sampleMemories() => [
  for (var i = 0; i < 6; i++)
    MemoryModel(
      id: 10 + i,
      coupleId: 7,
      createdBy: i.isEven ? 1 : 2,
      title: [
        'Sunset walk',
        'Rice terraces',
        'Our first rainy evening together',
        'Coffee date',
        'Night market',
        'Home',
      ][i],
      description: i == 2
          ? 'We waited out the rain under the warung roof and talked until the lamps came on.'
          : null,
      memoryDate: sampleNow.subtract(Duration(days: 3 + i * 17)),
      locationName: i.isOdd ? 'Ubud' : null,
      photosCount: i * 2,
      createdAt: sampleNow.subtract(Duration(days: 3 + i * 17)),
    ),
];

class _FakeCouple extends CoupleNotifier {
  _FakeCouple(this.initial);
  final CoupleState initial;
  @override
  CoupleState build() => initial;
  @override
  Future<void> loadCouple() async {}
}

class _FakeDates extends DateNotifier {
  _FakeDates(this.initial);
  final DateState initial;
  @override
  DateState build() => initial;
  @override
  Future<void> loadDates() async {}
}

class _FakeMemories extends MemoryNotifier {
  _FakeMemories(this.initial);
  final MemoryState initial;
  @override
  MemoryState build() => initial;
  @override
  Future<void> loadTimeline({int page = 1, int perPage = 20}) async {}
}

/// Pumps [screen] with example data in [theme]. No network: every provider a
/// screen loads from is replaced with fixed data.
Future<void> pumpScreen(
  dynamic tester,
  Widget screen, {
  required ThemeDefinition theme,
  Brightness brightness = Brightness.light,
  ThemeCustomization customization = ThemeCustomization.defaults,
  double textScale = 1,
  CoupleState? couple,
  DateState? dates,
  MemoryState? memories,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceLocalStoreProvider.overrideWithValue(
          AppearanceLocalStore(prefs),
        ),
        appearanceRepositoryProvider.overrideWithValue(
          FakeAppearanceRepository(),
        ),
        authNotifierProvider.overrideWith(
          () => FakeAuthNotifier(const AuthState.authenticated(sampleMe)),
        ),
        coupleNotifierProvider.overrideWith(
          () => _FakeCouple(
            couple ??
                CoupleState(status: CoupleStatus.loaded, couple: sampleCouple),
          ),
        ),
        dateNotifierProvider.overrideWith(
          () => _FakeDates(
            dates ?? DateState(status: DateStatus.loaded, dates: sampleDates()),
          ),
        ),
        memoryNotifierProvider.overrideWith(
          () => _FakeMemories(
            memories ??
                MemoryState(
                  status: MemoryStatus.loaded,
                  memories: sampleMemories(),
                  hasMore: false,
                ),
          ),
        ),
        encryptionStatusProvider.overrideWith(
          (ref) async => const EncryptionStatus(
            hasAccess: true,
            hasRecoveryKey: true,
            pendingDevices: [],
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(theme, brightness, customization: customization),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            // Ambient ornaments loop forever; tests run with reduce motion.
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

extension SampleCouple on CoupleModel {
  CoupleModel copyWithoutAnniversary() => CoupleModel(
    id: id,
    inviteCode: inviteCode,
    members: members,
    createdAt: createdAt,
  );
}
