## 0.1.0

- Initial Android + iOS release.
- Flutter-shaped `LocalAuthentication` API: `isDeviceSupported`,
  `canCheckBiometrics`, `getAvailableBiometrics`, `authenticate`,
  `stopAuthentication`.
- Face ID / Touch ID via `LocalAuthentication` (iOS) and `BiometricPrompt`
  (Android), over FFI.
