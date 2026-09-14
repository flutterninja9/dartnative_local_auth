// DNLocalAuthBridge.swift
// @_cdecl FFI entry points for local_auth_kit.
//
// Exposes LocalAuthentication.framework as a small set of C functions so
// Dart apps can prompt Face ID / Touch ID / Optic ID / device passcode
// without Flutter platform channels.

import Foundation
import Darwin
import LocalAuthentication
import UIKit

// MARK: - Result / option / biometric codes (keep in sync with lib/src/types.dart)

private enum ResultCode: Int32 {
  case success = 0
  case userCanceled = 1
  case systemCanceled = 2
  case notAvailable = 3
  case notEnrolled = 4
  case lockedOut = 5
  case permanentlyLockedOut = 6
  case timeout = 7
  case passcodeNotSet = 8
  case biometricOnlyNotSupported = 9
  case noActivity = 10
  case uiUnavailable = 11
  case error = 12
  case userRequestedFallback = 13
  case authInProgress = 14
  case hardwareUnavailable = 15
  case deviceError = 16
}

private let optionBiometricOnly: Int32 = 1 << 0
private let optionPersist: Int32 = 1 << 2

private let bitFingerprint: Int32 = 1 << 0
private let bitFace: Int32 = 1 << 1
private let bitIris: Int32 = 1 << 2
private let bitWeak: Int32 = 1 << 3
private let bitStrong: Int32 = 1 << 4

// MARK: - Result dispatcher (hot-restart-safe slot)

/// (token, result, message)
private typealias AuthDispatch =
  @convention(c) (Int64, Int32, UnsafePointer<CChar>) -> Void

private let _dispatcherSlot: UnsafeMutablePointer<Int64> = {
  let p = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
  p.pointee = 0
  return p
}()
private var _slotRegistered = false

@_cdecl("DNLocalAuthSetDispatcher")
public func DNLocalAuthSetDispatcher(_ callbackPtr: Int64) {
  _dispatcherSlot.pointee = callbackPtr
  if !_slotRegistered {
    _slotRegistered = true
    typealias RegFn = @convention(c) (UnsafeMutablePointer<Int64>) -> Void
    if let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2),
                       "DNRegisterAsyncDispatcherSlot") {
      unsafeBitCast(sym, to: RegFn.self)(_dispatcherSlot)
    }
  }
}

private func fireResult(token: Int64, code: ResultCode, message: String = "") {
  DispatchQueue.main.async {
    let addr = _dispatcherSlot.pointee
    guard addr != 0 else { return }
    message.withCString { cStr in
      unsafeBitCast(addr, to: AuthDispatch.self)(token, code.rawValue, cStr)
    }
  }
}

// MARK: - Session

private struct PromptStrings {
  var iosCancelButton = "OK"
  var localizedFallbackTitle: String? = nil
}

private func parseMessages(_ ptr: UnsafePointer<CChar>?) -> PromptStrings {
  var parsed = PromptStrings()
  guard let json = cString(ptr),
        let data = json.data(using: .utf8),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  else {
    return parsed
  }
  if let v = obj["iosCancelButton"] as? String, !v.isEmpty {
    parsed.iosCancelButton = v
  }
  if let v = obj["localizedFallbackTitle"] as? String {
    parsed.localizedFallbackTitle = v
  }
  return parsed
}

private final class AuthSession {
  let context = LAContext()
  var persist = false
  var token: Int64 = 0
  var reason = ""
  var strings = PromptStrings()
  var policy: LAPolicy = .deviceOwnerAuthentication
  var becomingActive: NSObjectProtocol?

  func invalidate() {
    if let obs = becomingActive {
      NotificationCenter.default.removeObserver(obs)
      becomingActive = nil
    }
    context.invalidate()
  }
}

private var _session: AuthSession?

private func cString(_ ptr: UnsafePointer<CChar>?) -> String? {
  guard let ptr else { return nil }
  let s = String(cString: ptr)
  return s.isEmpty ? nil : s
}

private func mapLAError(_ error: Error?) -> ResultCode {
  guard let la = error as? LAError else { return .error }
  switch la.code {
  case .userCancel:
    return .userCanceled
  case .systemCancel, .appCancel:
    return .systemCanceled
  case .biometryNotAvailable:
    return .notAvailable
  case .biometryNotEnrolled:
    return .notEnrolled
  case .biometryLockout:
    return .lockedOut
  case .passcodeNotSet:
    return .passcodeNotSet
  case .userFallback:
    return .userRequestedFallback
  case .authenticationFailed:
    return .error
  default:
    if #available(iOS 18.0, *) {
      // Keep compiling on older SDKs; unknown codes fall through.
    }
    return .error
  }
}

private func biometricMask(from context: LAContext) -> Int32 {
  if #available(iOS 17.0, *), context.biometryType == .opticID {
    return bitIris | bitStrong
  }
  switch context.biometryType {
  case .faceID:
    return bitFace | bitStrong
  case .touchID:
    return bitFingerprint | bitStrong
  case .none:
    return 0
  default:
    return 0
  }
}

// MARK: - Queries

@_cdecl("DNLocalAuthIsDeviceSupported")
public func DNLocalAuthIsDeviceSupported() -> Int32 {
  let ctx = LAContext()
  var error: NSError?
  let biometrics = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
  let any = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
  return (biometrics || any) ? 1 : 0
}

@_cdecl("DNLocalAuthCanCheckBiometrics")
public func DNLocalAuthCanCheckBiometrics() -> Int32 {
  let ctx = LAContext()
  var error: NSError?
  if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
    return 1
  }
  if let la = error as? LAError, la.code == .biometryNotEnrolled {
    return 1
  }
  return 0
}

@_cdecl("DNLocalAuthGetAvailableBiometrics")
public func DNLocalAuthGetAvailableBiometrics() -> Int32 {
  let ctx = LAContext()
  var error: NSError?
  if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
    return biometricMask(from: ctx)
  }
  return 0
}

// MARK: - Authenticate

@_cdecl("DNLocalAuthAuthenticate")
public func DNLocalAuthAuthenticate(
  _ token: Int64,
  _ reasonPtr: UnsafePointer<CChar>?,
  _ options: Int32,
  _ messagesPtr: UnsafePointer<CChar>?
) {
  guard let reason = cString(reasonPtr) else {
    fireResult(token: token, code: .error, message: "localizedReason must not be empty")
    return
  }

  let strings = parseMessages(messagesPtr)

  DispatchQueue.main.async {
    _session?.invalidate()
    let session = AuthSession()
    session.token = token
    session.reason = reason
    session.strings = strings
    session.persist = (options & optionPersist) != 0
    session.policy = (options & optionBiometricOnly) != 0
      ? .deviceOwnerAuthenticationWithBiometrics
      : .deviceOwnerAuthentication
    session.context.localizedCancelTitle = strings.iosCancelButton
    if let fallback = strings.localizedFallbackTitle {
      session.context.localizedFallbackTitle = fallback
    }
    _session = session
    evaluate(session)
  }
}

@_cdecl("DNLocalAuthStopAuthentication")
public func DNLocalAuthStopAuthentication() -> Int32 {
  guard let session = _session else { return 0 }
  let token = session.token
  session.invalidate()
  _session = nil
  fireResult(token: token, code: .userCanceled, message: "stopped")
  return 1
}

private func evaluate(_ session: AuthSession) {
  var error: NSError?
  guard session.context.canEvaluatePolicy(session.policy, error: &error) else {
    fireResult(
      token: session.token,
      code: mapLAError(error),
      message: error?.localizedDescription ?? ""
    )
    if _session === session { _session = nil }
    return
  }

  session.context.evaluatePolicy(session.policy, localizedReason: session.reason) { success, error in
    DispatchQueue.main.async {
      guard _session === session else { return }
      if success {
        session.invalidate()
        _session = nil
        fireResult(token: session.token, code: .success)
        return
      }

      let code = mapLAError(error)
      let shouldRetry = session.persist && (code == .systemCanceled)
      if shouldRetry {
        retryWhenForeground(session)
        return
      }

      session.invalidate()
      _session = nil
      fireResult(
        token: session.token,
        code: code,
        message: error?.localizedDescription ?? ""
      )
    }
  }
}

private func retryWhenForeground(_ session: AuthSession) {
  if session.becomingActive != nil { return }
  session.becomingActive = NotificationCenter.default.addObserver(
    forName: UIApplication.didBecomeActiveNotification,
    object: nil,
    queue: .main
  ) { [weak session] _ in
    guard let session, _session === session else { return }
    if let obs = session.becomingActive {
      NotificationCenter.default.removeObserver(obs)
      session.becomingActive = nil
    }
    evaluate(session)
  }
}
