import 'dart:async';

import 'backend.dart';
import 'codec.dart';
import 'local_auth_ffi_bindings.dart';
import 'types.dart';

export 'backend.dart';
export 'types.dart';

/// On-device authentication — Face ID / Touch ID / Optic ID on iOS,
/// BiometricPrompt (biometrics + optional device credential) on Android.
///
/// Drop-in shape for `package:local_auth`'s `LocalAuthentication`:
///
/// ```dart
/// final auth = LocalAuthentication();
/// if (!await auth.isDeviceSupported()) return;
/// final ok = await auth.authenticate(
///   localizedReason: 'Unlock to continue',
///   biometricOnly: true,
/// );
/// ```
class LocalAuthentication {
  LocalAuthentication() : _backend = LocalAuthFFIBindings.instance;

  /// Test-only constructor. Production code should use the default.
  LocalAuthentication.withBackend(this._backend);

  final LocalAuthBackend _backend;

  static int _nextToken = 1;

  /// True if the device can do biometrics or fall back to a device PIN /
  /// pattern / passcode.
  Future<bool> isDeviceSupported() async =>
      _backend.isDeviceSupported() != 0;

  /// True if the device has biometric hardware (enrolled or not).
  Future<bool> get canCheckBiometrics async =>
      _backend.canCheckBiometrics() != 0;

  /// Enrolled / available biometric kinds. Empty if none are usable.
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      decodeBiometricBitmask(_backend.availableBiometrics());

  /// Prompts the user. Returns `true` on success.
  ///
  /// Throws [LocalAuthException] on failure, including user cancel
  /// ([LocalAuthExceptionCodes.userCanceled]).
  ///
  /// [options] is the local_auth 2.x bag — when set, its fields override
  /// the flattened flags ([biometricOnly], [sensitiveTransaction],
  /// [persistAcrossBackgrounding]).
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
    AuthenticationOptions? options,
  }) {
    if (localizedReason.trim().isEmpty) {
      throw ArgumentError.value(
        localizedReason,
        'localizedReason',
        'must not be empty — iOS and Android both require a reason string',
      );
    }

    final token = _nextToken++;
    final bits = encodeAuthOptions(
      biometricOnly: options?.biometricOnly ?? biometricOnly,
      sensitiveTransaction:
          options?.sensitiveTransaction ?? sensitiveTransaction,
      persistAcrossBackgrounding:
          options?.persist ?? persistAcrossBackgrounding,
    );

    final pending = Completer<bool>();
    _backend.authenticate(
      token: token,
      reason: localizedReason,
      options: bits,
      complete: (completedToken, result, message) {
        if (completedToken != token || pending.isCompleted) return;
        final error = exceptionForResult(result, message);
        if (error == null) {
          pending.complete(true);
        } else {
          pending.completeError(error);
        }
      },
    );
    return pending.future;
  }

  /// Cancels an in-flight prompt. Returns `true` if a prompt was canceled.
  Future<bool> stopAuthentication() async =>
      _backend.stopAuthentication() != 0;
}
