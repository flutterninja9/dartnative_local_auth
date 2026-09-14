/// Native-facing surface used by [LocalAuthentication].
///
/// Production talks to the FFI bindings; tests inject a fake.
abstract class LocalAuthBackend {
  int isDeviceSupported();

  int canCheckBiometrics();

  int availableBiometrics();

  void authenticate({
    required int token,
    required String reason,
    required int options,
    required void Function(int token, int result, String message) complete,
  });

  int stopAuthentication();
}
