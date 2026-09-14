## 0.2.0

- Add `authMessages` (`AndroidAuthMessages`, `IOSAuthMessages`) so callers can
  customize system-prompt copy the same way Flutter `local_auth` 3.x does.
- Align the Android prompt with Flutter: title, subtitle, description, cancel
  button, and `BIOMETRIC_STRONG` alongside weak / device credentials.
- Set iOS `localizedCancelTitle` and `localizedFallbackTitle`.
- Switch `LocalAuthException.code` to `LocalAuthExceptionCode`; keep
  `LocalAuthExceptionCodes` as 2.x name aliases. Add `details`,
  `authInProgress`, and `userRequestedFallback`.

## 0.1.0

- Initial Android + iOS release.
- Flutter-shaped `LocalAuthentication` API: `isDeviceSupported`,
  `canCheckBiometrics`, `getAvailableBiometrics`, `authenticate`,
  `stopAuthentication`.
- Face ID / Touch ID via `LocalAuthentication` (iOS) and `BiometricPrompt`
  (Android), over FFI.
