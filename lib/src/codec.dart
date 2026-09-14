import 'types.dart';

/// Encodes [AuthenticationOptions] (plus the flattened `authenticate` flags)
/// into the int the native bridges read.
int encodeAuthOptions({
  required bool biometricOnly,
  required bool sensitiveTransaction,
  required bool persistAcrossBackgrounding,
}) {
  var bits = 0;
  if (biometricOnly) {
    bits |= LocalAuthOptionBits.biometricOnly;
  }
  if (sensitiveTransaction) {
    bits |= LocalAuthOptionBits.sensitiveTransaction;
  }
  if (persistAcrossBackgrounding) {
    bits |= LocalAuthOptionBits.persistAcrossBackgrounding;
  }
  return bits;
}

/// Decodes the native biometric bitmask into the Flutter-shaped list.
List<BiometricType> decodeBiometricBitmask(int mask) {
  final out = <BiometricType>[];
  if (mask & LocalAuthBiometricBits.face != 0) {
    out.add(BiometricType.face);
  }
  if (mask & LocalAuthBiometricBits.fingerprint != 0) {
    out.add(BiometricType.fingerprint);
  }
  if (mask & LocalAuthBiometricBits.iris != 0) {
    out.add(BiometricType.iris);
  }
  if (mask & LocalAuthBiometricBits.weak != 0) {
    out.add(BiometricType.weak);
  }
  if (mask & LocalAuthBiometricBits.strong != 0) {
    out.add(BiometricType.strong);
  }
  return out;
}

/// Maps a native result code to a [LocalAuthException], or `null` on success.
LocalAuthException? exceptionForResult(int code, String message) {
  if (code == LocalAuthNativeResult.success) {
    return null;
  }
  final mapped = switch (code) {
    LocalAuthNativeResult.userCanceled => LocalAuthExceptionCodes.userCanceled,
    LocalAuthNativeResult.systemCanceled =>
      LocalAuthExceptionCodes.systemCanceled,
    LocalAuthNativeResult.notAvailable => LocalAuthExceptionCodes.notAvailable,
    LocalAuthNativeResult.notEnrolled => LocalAuthExceptionCodes.notEnrolled,
    LocalAuthNativeResult.lockedOut => LocalAuthExceptionCodes.lockedOut,
    LocalAuthNativeResult.permanentlyLockedOut =>
      LocalAuthExceptionCodes.permanentlyLockedOut,
    LocalAuthNativeResult.timeout => LocalAuthExceptionCodes.timeout,
    LocalAuthNativeResult.passcodeNotSet =>
      LocalAuthExceptionCodes.passcodeNotSet,
    LocalAuthNativeResult.biometricOnlyNotSupported =>
      LocalAuthExceptionCodes.biometricOnlyNotSupported,
    LocalAuthNativeResult.noActivity => LocalAuthExceptionCodes.noActivity,
    LocalAuthNativeResult.uiUnavailable =>
      LocalAuthExceptionCodes.uiUnavailable,
    _ => LocalAuthExceptionCodes.unknownError,
  };
  return LocalAuthException(
    code: mapped,
    description: message.isEmpty ? null : message,
  );
}
