import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'couple_key_package.dart';
import 'couple_key_package_repository.dart';

final coupleKeyPackageRepositoryProvider = Provider<CoupleKeyPackageRepository>(
  (ref) {
    return CoupleKeyPackageRepository();
  },
);

final coupleKeyPackagesProvider =
    FutureProvider.autoDispose<List<CoupleKeyPackage>>((ref) {
      final repository = ref.watch(coupleKeyPackageRepositoryProvider);

      return repository.getKeyPackages();
    });
