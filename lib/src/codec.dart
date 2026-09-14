import 'dart:convert';

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

/// Encodes [AndroidAuthMessages] / [IOSAuthMessages] into the JSON payload
/// the native bridges read. Missing fields become Flutter `local_auth`
/// defaults. [localizedFallbackTitle] is omitted unless the caller set it
/// (including to `''`, which hides the iOS fallback button).
String encodeAuthMessages(Iterable<AuthMessages> authMessages) {
  var android = const AndroidAuthMessages();
  var ios = const IOSAuthMessages();
  for (final message in authMessages) {
    if (message is AndroidAuthMessages) {
      android = message;
    } else if (message is IOSAuthMessages) {
      ios = message;
    }
  }

  final payload = <String, String>{
    'signInTitle': android.signInTitle ?? androidSignInTitle,
    'signInHint': android.signInHint ?? androidSignInHint,
    'cancelButton': android.cancelButton ?? androidCancelButton,
    'iosCancelButton': ios.cancelButton ?? iosCancelButton,
  };
  final fallback = ios.localizedFallbackTitle;
  if (fallback != null) {
    payload['localizedFallbackTitle'] = fallback;
  }
  return jsonEncode(payload);
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
    LocalAuthNativeResult.userCanceled => LocalAuthExceptionCode.userCanceled,
    LocalAuthNativeResult.systemCanceled =>
      LocalAuthExceptionCode.systemCanceled,
    LocalAuthNativeResult.notAvailable =>
      LocalAuthExceptionCode.noBiometricHardware,
    LocalAuthNativeResult.notEnrolled =>
      LocalAuthExceptionCode.noBiometricsEnrolled,
    LocalAuthNativeResult.lockedOut => LocalAuthExceptionCode.temporaryLockout,
    LocalAuthNativeResult.permanentlyLockedOut =>
      LocalAuthExceptionCode.biometricLockout,
    LocalAuthNativeResult.timeout => LocalAuthExceptionCode.timeout,
    LocalAuthNativeResult.passcodeNotSet =>
      LocalAuthExceptionCode.noCredentialsSet,
    LocalAuthNativeResult.biometricOnlyNotSupported =>
      LocalAuthExceptionCode.noBiometricHardware,
    LocalAuthNativeResult.noActivity => LocalAuthExceptionCode.uiUnavailable,
    LocalAuthNativeResult.uiUnavailable => LocalAuthExceptionCode.uiUnavailable,
    LocalAuthNativeResult.userRequestedFallback =>
      LocalAuthExceptionCode.userRequestedFallback,
    LocalAuthNativeResult.authInProgress =>
      LocalAuthExceptionCode.authInProgress,
    LocalAuthNativeResult.hardwareUnavailable =>
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
    LocalAuthNativeResult.deviceError => LocalAuthExceptionCode.deviceError,
    _ => LocalAuthExceptionCode.unknownError,
  };
  return LocalAuthException(
    code: mapped,
    description: message.isEmpty ? null : message,
  );
}
