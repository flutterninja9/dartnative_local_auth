/// local_auth_kit — Face ID / fingerprint / device credentials
/// for DartNative apps.
///
/// Backed by `LocalAuthentication` on iOS and `BiometricPrompt` on Android,
/// over FFI — no Flutter platform channels.
///
/// **Initialization** — the generated registrant calls this at app start:
/// ```dart
/// LocalAuthFFIBindings.loadSymbols();
/// ```
///
/// **Usage:**
/// ```dart
/// import 'package:local_auth_kit/local_auth_kit.dart';
///
/// final auth = LocalAuthentication();
/// if (await auth.canCheckBiometrics) {
///   final ok = await auth.authenticate(
///     localizedReason: 'Unlock to continue',
///   );
/// }
/// ```
library;

export 'src/local_auth.dart';
export 'src/local_auth_ffi_bindings.dart';
export 'src/types.dart';
