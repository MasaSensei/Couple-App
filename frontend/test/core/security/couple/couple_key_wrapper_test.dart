import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key_wrapper.dart';

void main() {
  group('CoupleKeyWrapper', () {
    late CoupleKeyWrapper wrapper;

    setUp(() {
      wrapper = CoupleKeyWrapper();
    });

    test('wraps and unwraps a couple key successfully', () async {
      final recipientKeyPair = await X25519().newKeyPair();

      final originalBytes = List<int>.generate(32, (index) => index);

      final coupleKey = SecretKey(originalBytes);

      final recipientPublicKey = await recipientKeyPair.extractPublicKey();

      final wrapped = await wrapper.wrap(
        keyId: 'test-key-id',
        coupleKey: coupleKey,
        recipientPublicKey: recipientPublicKey,
      );

      final unwrapped = await wrapper.unwrap(
        wrappedKey: wrapped,
        recipientKeyPair: recipientKeyPair,
      );

      final result = await unwrapped.extractBytes();

      expect(result, originalBytes);
    });

    test('wrapped ciphertext is different from plaintext', () async {
      final recipientKeyPair = await X25519().newKeyPair();

      final originalBytes = List<int>.generate(32, (index) => index);

      final coupleKey = SecretKey(originalBytes);

      final recipientPublicKey = await recipientKeyPair.extractPublicKey();

      final wrapped = await wrapper.wrap(
        keyId: 'test-key-id',
        coupleKey: coupleKey,
        recipientPublicKey: recipientPublicKey,
      );

      expect(wrapped.ciphertext, isNot(equals(originalBytes)));
    });

    test('two wraps of the same key produce different ciphertext', () async {
      final recipientKeyPair = await X25519().newKeyPair();

      final coupleKey = SecretKey(List<int>.filled(32, 42));

      final recipientPublicKey = await recipientKeyPair.extractPublicKey();

      final first = await wrapper.wrap(
        keyId: 'test-key-id',
        coupleKey: coupleKey,
        recipientPublicKey: recipientPublicKey,
      );

      final second = await wrapper.wrap(
        keyId: 'test-key-id',
        coupleKey: coupleKey,
        recipientPublicKey: recipientPublicKey,
      );

      expect(first.ciphertext, isNot(equals(second.ciphertext)));

      expect(
        first.ephemeralPublicKey.bytes,
        isNot(equals(second.ephemeralPublicKey.bytes)),
      );
    });

    test('cannot unwrap with another private key', () async {
      final recipientKeyPair = await X25519().newKeyPair();

      final wrongKeyPair = await X25519().newKeyPair();

      final coupleKey = SecretKey(List<int>.filled(32, 42));

      final recipientPublicKey = await recipientKeyPair.extractPublicKey();

      final wrapped = await wrapper.wrap(
        keyId: 'test-key-id',
        coupleKey: coupleKey,
        recipientPublicKey: recipientPublicKey,
      );

      expect(
        () =>
            wrapper.unwrap(wrappedKey: wrapped, recipientKeyPair: wrongKeyPair),
        throwsA(anything),
      );
    });

    test('cannot unwrap when key metadata is modified', () async {
      final recipientKeyPair = await X25519().newKeyPair();

      final coupleKey = SecretKey(List<int>.filled(32, 42));

      final recipientPublicKey = await recipientKeyPair.extractPublicKey();

      final wrapped = await wrapper.wrap(
        keyId: 'original-key-id',
        coupleKey: coupleKey,
        recipientPublicKey: recipientPublicKey,
      );

      final tampered = WrappedCoupleKey(
        keyId: 'tampered-key-id',
        encryptionVersion: wrapped.encryptionVersion,
        ephemeralPublicKey: wrapped.ephemeralPublicKey,
        nonce: wrapped.nonce,
        ciphertext: wrapped.ciphertext,
        mac: wrapped.mac,
      );

      expect(
        () => wrapper.unwrap(
          wrappedKey: tampered,
          recipientKeyPair: recipientKeyPair,
        ),
        throwsA(anything),
      );
    });

    test('cannot unwrap when encryption version is modified', () async {
      final recipientKeyPair = await X25519().newKeyPair();

      final coupleKey = SecretKey(List<int>.filled(32, 42));

      final recipientPublicKey = await recipientKeyPair.extractPublicKey();

      final wrapped = await wrapper.wrap(
        keyId: 'test-key-id',
        coupleKey: coupleKey,
        recipientPublicKey: recipientPublicKey,
      );

      final tampered = WrappedCoupleKey(
        keyId: wrapped.keyId,
        encryptionVersion: 999,
        ephemeralPublicKey: wrapped.ephemeralPublicKey,
        nonce: wrapped.nonce,
        ciphertext: wrapped.ciphertext,
        mac: wrapped.mac,
      );

      expect(
        () => wrapper.unwrap(
          wrappedKey: tampered,
          recipientKeyPair: recipientKeyPair,
        ),
        throwsA(anything),
      );
    });
  });
}
