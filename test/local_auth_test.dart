import 'dart:convert';

import 'package:local_auth_kit/local_auth_kit.dart';
import 'package:local_auth_kit/src/codec.dart';
import 'package:test/test.dart';

void main() {
  group('encodeAuthOptions', () {
    test('encodes an empty flag set as zero', () {
      expect(
        encodeAuthOptions(
          biometricOnly: false,
          sensitiveTransaction: false,
          persistAcrossBackgrounding: false,
        ),
        0,
      );
    });

    test('sets each option bit independently', () {
      expect(
        encodeAuthOptions(
          biometricOnly: true,
          sensitiveTransaction: false,
          persistAcrossBackgrounding: false,
        ),
        LocalAuthOptionBits.biometricOnly,
      );
      expect(
        encodeAuthOptions(
          biometricOnly: false,
          sensitiveTransaction: true,
          persistAcrossBackgrounding: false,
        ),
        LocalAuthOptionBits.sensitiveTransaction,
      );
      expect(
        encodeAuthOptions(
          biometricOnly: false,
          sensitiveTransaction: false,
          persistAcrossBackgrounding: true,
        ),
        LocalAuthOptionBits.persistAcrossBackgrounding,
      );
    });

    test('combines bits with OR', () {
      expect(
        encodeAuthOptions(
          biometricOnly: true,
          sensitiveTransaction: true,
          persistAcrossBackgrounding: true,
        ),
        LocalAuthOptionBits.biometricOnly |
            LocalAuthOptionBits.sensitiveTransaction |
            LocalAuthOptionBits.persistAcrossBackgrounding,
      );
    });
  });

  group('decodeBiometricBitmask', () {
    test('returns an empty list for zero', () {
      expect(decodeBiometricBitmask(0), isEmpty);
    });

    test('decodes each biometric kind', () {
      expect(decodeBiometricBitmask(LocalAuthBiometricBits.face), [
        BiometricType.face,
      ]);
      expect(decodeBiometricBitmask(LocalAuthBiometricBits.fingerprint), [
        BiometricType.fingerprint,
      ]);
      expect(decodeBiometricBitmask(LocalAuthBiometricBits.iris), [
        BiometricType.iris,
      ]);
      expect(decodeBiometricBitmask(LocalAuthBiometricBits.weak), [
        BiometricType.weak,
      ]);
      expect(decodeBiometricBitmask(LocalAuthBiometricBits.strong), [
        BiometricType.strong,
      ]);
    });

    test(
      'preserves Flutter-shaped order: face, fingerprint, iris, weak, strong',
      () {
        final mask =
            LocalAuthBiometricBits.strong |
            LocalAuthBiometricBits.fingerprint |
            LocalAuthBiometricBits.face;
        expect(decodeBiometricBitmask(mask), [
          BiometricType.face,
          BiometricType.fingerprint,
          BiometricType.strong,
        ]);
      },
    );
  });

  group('exceptionForResult', () {
    test('returns null on success', () {
      expect(exceptionForResult(LocalAuthNativeResult.success, ''), isNull);
    });

    test('maps every known native code to a LocalAuthExceptionCode', () {
      expect(
        exceptionForResult(LocalAuthNativeResult.userCanceled, 'x')!.code,
        LocalAuthExceptionCodes.userCanceled,
      );
      expect(
        exceptionForResult(LocalAuthNativeResult.notEnrolled, '')!.code,
        LocalAuthExceptionCodes.notEnrolled,
      );
      expect(
        exceptionForResult(
          LocalAuthNativeResult.lockedOut,
          'wait',
        )!.description,
        'wait',
      );
      expect(
        exceptionForResult(
          LocalAuthNativeResult.userRequestedFallback,
          'fb',
        )!.code,
        LocalAuthExceptionCode.userRequestedFallback,
      );
      expect(
        exceptionForResult(99, 'boom')!.code,
        LocalAuthExceptionCodes.unknownError,
      );
    });
  });

  group('encodeAuthMessages', () {
    test('encodes Flutter defaults when no platform messages are passed', () {
      final payload = jsonDecode(encodeAuthMessages(const [])) as Map;
      expect(payload['signInTitle'], 'Authentication required');
      expect(payload['signInHint'], 'Verify identity');
      expect(payload['cancelButton'], 'Cancel');
      expect(payload['iosCancelButton'], 'OK');
      expect(payload.containsKey('localizedFallbackTitle'), isFalse);
    });

    test('prefers AndroidAuthMessages and IOSAuthMessages from the list', () {
      final payload =
          jsonDecode(
                encodeAuthMessages(const [
                  AndroidAuthMessages(
                    signInTitle: 'Unlock',
                    signInHint: 'Face the sensor',
                    cancelButton: 'No thanks',
                  ),
                  IOSAuthMessages(
                    cancelButton: 'Nope',
                    localizedFallbackTitle: 'Use passcode',
                  ),
                ]),
              )
              as Map;
      expect(payload['signInTitle'], 'Unlock');
      expect(payload['signInHint'], 'Face the sensor');
      expect(payload['cancelButton'], 'No thanks');
      expect(payload['iosCancelButton'], 'Nope');
      expect(payload['localizedFallbackTitle'], 'Use passcode');
    });

    test('keeps an empty iOS fallback title so the native button can hide', () {
      final payload =
          jsonDecode(
                encodeAuthMessages(const [
                  IOSAuthMessages(localizedFallbackTitle: ''),
                ]),
              )
              as Map;
      expect(payload['localizedFallbackTitle'], '');
    });
  });

  group('LocalAuthExceptionCodes aliases', () {
    test('maps 2.x names onto the 3.x enum', () {
      expect(
        LocalAuthExceptionCodes.notAvailable,
        LocalAuthExceptionCode.noBiometricHardware,
      );
      expect(
        LocalAuthExceptionCodes.notEnrolled,
        LocalAuthExceptionCode.noBiometricsEnrolled,
      );
      expect(
        LocalAuthExceptionCodes.lockedOut,
        LocalAuthExceptionCode.temporaryLockout,
      );
      expect(
        LocalAuthExceptionCodes.permanentlyLockedOut,
        LocalAuthExceptionCode.biometricLockout,
      );
      expect(
        LocalAuthExceptionCodes.passcodeNotSet,
        LocalAuthExceptionCode.noCredentialsSet,
      );
      expect(
        LocalAuthExceptionCodes.noActivity,
        LocalAuthExceptionCode.uiUnavailable,
      );
    });
  });

  group('LocalAuthentication with a fake backend', () {
    test(
      'isDeviceSupported and canCheckBiometrics read native ints as bools',
      () async {
        final auth = LocalAuthentication.withBackend(
          _FakeBackend(
            supported: 1,
            canCheck: 0,
            biometrics: LocalAuthBiometricBits.face,
          ),
        );

        expect(await auth.isDeviceSupported(), isTrue);
        expect(await auth.canCheckBiometrics, isFalse);
        expect(await auth.getAvailableBiometrics(), [BiometricType.face]);
      },
    );

    test('authenticate completes true on native success', () async {
      final auth = LocalAuthentication.withBackend(
        _FakeBackend(authResult: LocalAuthNativeResult.success),
      );

      expect(
        await auth.authenticate(localizedReason: 'Unlock to continue'),
        isTrue,
      );
    });

    test('authenticate throws LocalAuthException on native failure', () async {
      final auth = LocalAuthentication.withBackend(
        _FakeBackend(
          authResult: LocalAuthNativeResult.notEnrolled,
          authMessage: 'no prints',
        ),
      );

      try {
        await auth.authenticate(localizedReason: 'Unlock');
        fail('expected LocalAuthException');
      } on LocalAuthException catch (e) {
        expect(e.code, LocalAuthExceptionCodes.notEnrolled);
        expect(e.description, 'no prints');
      }
    });

    test('AuthenticationOptions override the flattened flags', () async {
      final backend = _FakeBackend(authResult: LocalAuthNativeResult.success);
      final auth = LocalAuthentication.withBackend(backend);

      await auth.authenticate(
        localizedReason: 'Unlock',
        biometricOnly: false,
        options: const AuthenticationOptions(biometricOnly: true),
      );

      expect(
        backend.lastOptions & LocalAuthOptionBits.biometricOnly,
        LocalAuthOptionBits.biometricOnly,
      );
    });

    test('stopAuthentication forwards to the backend', () async {
      final backend = _FakeBackend();
      final auth = LocalAuthentication.withBackend(backend);
      expect(await auth.stopAuthentication(), isTrue);
      expect(backend.stopped, isTrue);
    });

    test('authenticate forwards encoded authMessages to the backend', () async {
      final backend = _FakeBackend(authResult: LocalAuthNativeResult.success);
      final auth = LocalAuthentication.withBackend(backend);

      await auth.authenticate(
        localizedReason: 'Unlock',
        authMessages: const [AndroidAuthMessages(signInTitle: 'Hello')],
      );

      expect(backend.lastMessages, contains('"signInTitle":"Hello"'));
    });

    test('rejects overlapping authenticate with authInProgress', () async {
      final backend = _FakeBackend(completeImmediately: false);
      final auth = LocalAuthentication.withBackend(backend);

      final first = auth.authenticate(localizedReason: 'one');
      try {
        await auth.authenticate(localizedReason: 'two');
        fail('expected LocalAuthException');
      } on LocalAuthException catch (e) {
        expect(e.code, LocalAuthExceptionCode.authInProgress);
      }

      backend.completePending(LocalAuthNativeResult.success, '');
      expect(await first, isTrue);
    });
  });
}

class _FakeBackend implements LocalAuthBackend {
  _FakeBackend({
    this.supported = 1,
    this.canCheck = 1,
    this.biometrics = 0,
    this.authResult = LocalAuthNativeResult.success,
    this.authMessage = '',
    this.completeImmediately = true,
  });

  final int supported;
  final int canCheck;
  final int biometrics;
  final int authResult;
  final String authMessage;
  final bool completeImmediately;

  int lastOptions = 0;
  String lastMessages = '';
  bool stopped = false;
  int? _pendingToken;
  void Function(int token, int result, String message)? _pending;

  @override
  int isDeviceSupported() => supported;

  @override
  int canCheckBiometrics() => canCheck;

  @override
  int availableBiometrics() => biometrics;

  @override
  void authenticate({
    required int token,
    required String reason,
    required int options,
    required String messages,
    required void Function(int token, int result, String message) complete,
  }) {
    lastOptions = options;
    lastMessages = messages;
    if (completeImmediately) {
      complete(token, authResult, authMessage);
    } else {
      _pendingToken = token;
      _pending = complete;
    }
  }

  void completePending(int result, String message) {
    final complete = _pending;
    final token = _pendingToken ?? 0;
    _pending = null;
    _pendingToken = null;
    complete?.call(token, result, message);
  }

  @override
  int stopAuthentication() {
    stopped = true;
    return 1;
  }
}
