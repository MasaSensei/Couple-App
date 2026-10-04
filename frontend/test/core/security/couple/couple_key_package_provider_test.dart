import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/couple/couple_key_package.dart';
import 'package:frontend/core/security/couple/couple_key_package_provider.dart';
import 'package:frontend/core/security/couple/couple_key_package_repository.dart';

class FakeCoupleKeyPackageRepository extends CoupleKeyPackageRepository {
  FakeCoupleKeyPackageRepository({required this.packages});

  final List<CoupleKeyPackage> packages;

  @override
  Future<List<CoupleKeyPackage>> getKeyPackages() async {
    return packages;
  }
}

void main() {
  test('coupleKeyPackagesProvider returns key packages', () async {
    final packages = [
      CoupleKeyPackage(
        id: 1,
        deviceId: 2,
        keyId: 'test-key',
        encryptionVersion: 1,
        ephemeralPublicKey: 'public-key',
        nonce: 'nonce',
        ciphertext: 'ciphertext',
        mac: 'mac',
        createdAt: null,
        updatedAt: null,
        revokedAt: null,
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        coupleKeyPackageRepositoryProvider.overrideWithValue(
          FakeCoupleKeyPackageRepository(packages: packages),
        ),
      ],
    );

    addTearDown(container.dispose);

    final result = await container.read(coupleKeyPackagesProvider.future);

    expect(result, hasLength(1));
    expect(result.first.id, 1);
    expect(result.first.keyId, 'test-key');
  });
}
