import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/device_model.dart';
import '../data/repositories/device_repository.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository();
});

final devicesProvider = FutureProvider.autoDispose<List<DeviceModel>>((ref) {
  final repository = ref.watch(deviceRepositoryProvider);

  return repository.getDevices();
});
