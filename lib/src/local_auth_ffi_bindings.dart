/// FFI bindings for the local_auth_kit native layer (iOS + Android).
///
/// On iOS the @_cdecl symbols are linked into the process binary, so we
/// resolve them through `DynamicLibrary.process()`. On Android the JNI
/// bridge lives in `liblocal_auth_kit.so`.
///
/// Call [LocalAuthFFIBindings.loadSymbols] once at app start (the generated
/// registrant does this). Safe to call again — it is idempotent.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'backend.dart';

typedef _IntC = Int32 Function();
typedef _IntD = int Function();

typedef _StopC = Int32 Function();
typedef _StopD = int Function();

typedef _SetDispatcherC = Void Function(Int64);
typedef _SetDispatcherD = void Function(int);

typedef _AuthenticateC = Void Function(Int64, Pointer<Utf8>, Int32);
typedef _AuthenticateD = void Function(int, Pointer<Utf8>, int);

/// (token, result, message)
typedef _AuthDispatchC = Void Function(Int64, Int32, Pointer<Utf8>);

void _dispatchAuthResult(int token, int result, Pointer<Utf8> message) {
  LocalAuthFFIBindings._complete(
    token,
    result,
    message == nullptr ? '' : message.toDartString(),
  );
}

final Pointer<NativeFunction<_AuthDispatchC>> _authDispatchPtr =
    Pointer.fromFunction<_AuthDispatchC>(_dispatchAuthResult);

/// Internal FFI loader — apps use [LocalAuthentication] instead.
class LocalAuthFFIBindings implements LocalAuthBackend {
  LocalAuthFFIBindings._();

  static final LocalAuthFFIBindings instance = LocalAuthFFIBindings._();

  static late final _IntD _isDeviceSupported;
  static late final _IntD _canCheckBiometrics;
  static late final _IntD _availableBiometrics;
  static late final _AuthenticateD _authenticate;
  static late final _StopD _stopAuthentication;

  static bool _loaded = false;

  static final Map<int, void Function(int token, int result, String message)>
      _pending = {};

  static void _complete(int token, int result, String message) {
    final complete = _pending.remove(token);
    complete?.call(token, result, message);
  }

  /// Load all symbols. Call once at app startup.
  static void loadSymbols() {
    if (_loaded) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final lib = Platform.isAndroid
        ? DynamicLibrary.open('liblocal_auth_kit.so')
        : DynamicLibrary.process();

    _isDeviceSupported = lib.lookupFunction<_IntC, _IntD>(
      'DNLocalAuthIsDeviceSupported',
    );
    _canCheckBiometrics = lib.lookupFunction<_IntC, _IntD>(
      'DNLocalAuthCanCheckBiometrics',
    );
    _availableBiometrics = lib.lookupFunction<_IntC, _IntD>(
      'DNLocalAuthGetAvailableBiometrics',
    );
    _authenticate = lib.lookupFunction<_AuthenticateC, _AuthenticateD>(
      'DNLocalAuthAuthenticate',
    );
    _stopAuthentication = lib.lookupFunction<_StopC, _StopD>(
      'DNLocalAuthStopAuthentication',
    );

    final setDispatcher =
        lib.lookupFunction<_SetDispatcherC, _SetDispatcherD>(
      'DNLocalAuthSetDispatcher',
    );
    setDispatcher(_authDispatchPtr.address);
    _loaded = true;
  }

  @override
  int isDeviceSupported() {
    _ensureLoaded();
    return _isDeviceSupported();
  }

  @override
  int canCheckBiometrics() {
    _ensureLoaded();
    return _canCheckBiometrics();
  }

  @override
  int availableBiometrics() {
    _ensureLoaded();
    return _availableBiometrics();
  }

  @override
  void authenticate({
    required int token,
    required String reason,
    required int options,
    required void Function(int token, int result, String message) complete,
  }) {
    _ensureLoaded();
    _pending[token] = complete;
    final ptr = reason.toNativeUtf8();
    try {
      _authenticate(token, ptr, options);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  int stopAuthentication() {
    _ensureLoaded();
    return _stopAuthentication();
  }

  static void _ensureLoaded() {
    if (!_loaded) {
      loadSymbols();
    }
    assert(_loaded, 'Call LocalAuthFFIBindings.loadSymbols() first.');
  }
}
