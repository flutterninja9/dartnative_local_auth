/// Biometric kinds a device may expose.
///
/// Matches `package:local_auth`'s [BiometricType] so Flutter ports can keep
/// the same switch cases. Android also reports [weak] / [strong] (the
/// BiometricPrompt authenticator classes). iOS reports the enrolled
/// modality: [face], [fingerprint], or [iris] (Optic ID).
enum BiometricType {
  face,
  fingerprint,
  iris,
  weak,
  strong,
}

/// How a failed [LocalAuthentication.authenticate] should be classified.
///
/// String values match `local_auth`'s `LocalAuthExceptionCodes` so existing
/// `on LocalAuthException catch` handlers keep working.
abstract final class LocalAuthExceptionCodes {
  static const notAvailable = 'NotAvailable';
  static const notEnrolled = 'NotEnrolled';
  static const lockedOut = 'LockedOut';
  static const permanentlyLockedOut = 'PermanentlyLockedOut';
  static const userCanceled = 'UserCanceled';
  static const systemCanceled = 'SystemCanceled';
  static const timeout = 'Timeout';
  static const passcodeNotSet = 'PasscodeNotSet';
  static const biometricOnlyNotSupported = 'BiometricOnlyNotSupported';
  static const noActivity = 'NoActivity';
  static const uiUnavailable = 'UIUnavailable';
  static const unknownError = 'UnknownError';
}

/// Thrown by [LocalAuthentication.authenticate] when the attempt does not
/// succeed. User cancel is also thrown (code [LocalAuthExceptionCodes.userCanceled])
/// so callers can distinguish "user backed out" from "hardware failed".
class LocalAuthException implements Exception {
  const LocalAuthException({
    required this.code,
    this.description,
  });

  final String code;
  final String? description;

  @override
  String toString() =>
      'LocalAuthException($code${description == null ? '' : ', $description'})';
}

/// Optional bag matching `local_auth` 2.x. Prefer the named arguments on
/// [LocalAuthentication.authenticate]; if this is passed, its fields win.
class AuthenticationOptions {
  const AuthenticationOptions({
    this.biometricOnly = false,
    this.sensitiveTransaction = true,
    this.persistAcrossBackgrounding = false,
    this.stickyAuth = false,
    this.useErrorDialogs = true,
  });

  /// If true, device PIN / pattern / passcode cannot be used as a fallback.
  final bool biometricOnly;

  /// Android: marks the prompt as a sensitive transaction (confirmation
  /// required after biometric match on some devices). Ignored on iOS.
  final bool sensitiveTransaction;

  /// If true, a system/app cancel caused by backgrounding is retried when
  /// the app returns to the foreground instead of failing immediately.
  ///
  /// `stickyAuth` is accepted as an alias (local_auth 2.x name).
  final bool persistAcrossBackgrounding;

  /// Alias for [persistAcrossBackgrounding] (local_auth 2.x).
  final bool stickyAuth;

  /// Android: show the system error dialog on some failure paths.
  /// Accepted for API parity; the platform prompt owns most messaging.
  final bool useErrorDialogs;

  bool get persist => persistAcrossBackgrounding || stickyAuth;
}

/// Native result codes shared by the iOS @_cdecl bridge and the Android JNI
/// bridge. Keep in sync with `DNLocalAuthBridge.swift` / `.kt`.
abstract final class LocalAuthNativeResult {
  static const success = 0;
  static const userCanceled = 1;
  static const systemCanceled = 2;
  static const notAvailable = 3;
  static const notEnrolled = 4;
  static const lockedOut = 5;
  static const permanentlyLockedOut = 6;
  static const timeout = 7;
  static const passcodeNotSet = 8;
  static const biometricOnlyNotSupported = 9;
  static const noActivity = 10;
  static const uiUnavailable = 11;
  static const error = 12;
}

/// Native biometric bitmask. Keep in sync with the Swift/Kotlin bridges.
abstract final class LocalAuthBiometricBits {
  static const fingerprint = 1 << 0;
  static const face = 1 << 1;
  static const iris = 1 << 2;
  static const weak = 1 << 3;
  static const strong = 1 << 4;
}

/// Native options bitmask. Keep in sync with the Swift/Kotlin bridges.
abstract final class LocalAuthOptionBits {
  static const biometricOnly = 1 << 0;
  static const sensitiveTransaction = 1 << 1;
  static const persistAcrossBackgrounding = 1 << 2;
}
