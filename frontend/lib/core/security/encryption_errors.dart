/// This device has no usable Couple Key yet: it must be approved by another
/// device (own or partner's) or restored with the Recovery Key.
class CoupleKeyUnavailableException implements Exception {
  const CoupleKeyUnavailableException();
}

/// The user has no recovery package on the server.
class RecoveryUnavailableException implements Exception {
  const RecoveryUnavailableException();
}

/// Ciphertext failed checksum, size or AES-GCM authentication. Never display it.
class PhotoVerificationException implements Exception {
  const PhotoVerificationException();
}

/// User-facing copy. Never expose cryptographic internals.
abstract final class EncryptionMessages {
  static const encryptionFailed =
      "We couldn't secure this photo. Please try again.";
  static const uploadFailed =
      'Your photo is still safe on this device. You can retry the upload.';
  static const decryptionFailed =
      "We couldn't verify this photo. The file may be corrupted or incomplete.";
  static const keyUnavailable =
      "This device doesn't have the key needed to open this photo.";
  static const recoveryUnavailable =
      'Your private recovery information is required to restore access.';
}
