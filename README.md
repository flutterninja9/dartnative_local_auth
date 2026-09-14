# local_auth_kit

On-device authentication for DartNative — Face ID / Touch ID / Optic ID on
iOS, and `BiometricPrompt` (biometrics + optional PIN / pattern / passcode)
on Android. Flutter-shaped `LocalAuthentication` API, pure FFI, no platform
channels.

This is an early community plugin. Match the Flutter call sites and swap the
import.

## Install

```yaml
dependencies:
  local_auth_kit:
    path: ../dartnative_local_auth   # or the dartpub.dev version once published
```

```bash
dn pub get
```

```dart
void main() {
  DartNativePluginRegistrant.registerAll();
  runApp(const MyApp());
}
```

The generated registrant calls `LocalAuthFFIBindings.loadSymbols()`.

## Usage

```dart
import 'package:local_auth_kit/local_auth_kit.dart';

final auth = LocalAuthentication();

if (!await auth.isDeviceSupported()) {
  // no biometrics and no device credential
}

if (await auth.canCheckBiometrics) {
  final kinds = await auth.getAvailableBiometrics();
  // BiometricType.face / fingerprint / iris / weak / strong
}

try {
  final ok = await auth.authenticate(
    localizedReason: 'Unlock to continue',
    biometricOnly: true, // no PIN / passcode fallback
    authMessages: const [
      AndroidAuthMessages(
        signInTitle: 'Unlock to continue',
        cancelButton: 'No thanks',
      ),
      IOSAuthMessages(
        cancelButton: 'No thanks',
        localizedFallbackTitle: 'Use passcode',
      ),
    ],
  );
  if (ok) { /* unlocked */ }
} on LocalAuthException catch (e) {
  if (e.code == LocalAuthExceptionCode.userCanceled) {
    // user backed out
  }
}
```

`local_auth` 2.x `AuthenticationOptions` still works — when passed, its fields
override the flattened flags:

```dart
await auth.authenticate(
  localizedReason: 'Unlock to continue',
  options: const AuthenticationOptions(
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  ),
);
```

`LocalAuthExceptionCodes` aliases the 2.x names onto the 3.x enum, so
`e.code == LocalAuthExceptionCodes.userCanceled` still compiles.

## Platform setup

### iOS

Add a Face ID usage description to `ios/Runner/Info.plist`. iOS rejects the
prompt without it:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to unlock the app</string>
```

No extra entitlements. Touch ID / Optic ID use the same APIs.

### Android

The plugin declares `USE_BIOMETRIC` / `USE_FINGERPRINT`. The host
`MainActivity` must be a `FragmentActivity` — DartNative's
`DartNativeActivity` already is (`AppCompatActivity`).

## API

| Method | Meaning |
|---|---|
| `isDeviceSupported()` | Hardware biometrics **or** a device PIN / pattern / passcode |
| `canCheckBiometrics` | Biometric hardware is present (enrolled or not) |
| `getAvailableBiometrics()` | Enrolled / advertised kinds |
| `authenticate(...)` | Show the system prompt; `true` on success |
| `stopAuthentication()` | Dismiss an in-flight prompt |

`authenticate` accepts `authMessages` (`AndroidAuthMessages`,
`IOSAuthMessages`) to customize title, subtitle, cancel, and iOS fallback
copy — the same shape as Flutter `local_auth` 3.x.

Failures throw `LocalAuthException` with `LocalAuthExceptionCode` values:
`userCanceled`, `systemCanceled`, `noBiometricHardware`,
`noBiometricsEnrolled`, `noCredentialsSet`, `temporaryLockout`,
`biometricLockout`, `timeout`, `uiUnavailable`, `authInProgress`,
`userRequestedFallback`, `biometricHardwareTemporarilyUnavailable`,
`deviceError`, `unknownError`.

## Platforms

v0.2.0 ships **iOS and Android**. Other platforms can follow the same FFI
surface later.

## License

MIT
