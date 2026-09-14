/// Abstract class for platform-specific prompt copy.
///
/// Pass a list of [AndroidAuthMessages] / [IOSAuthMessages] to
/// [LocalAuthentication.authenticate] the same way Flutter `local_auth` 3.x
/// does.
abstract class AuthMessages {
  const AuthMessages();
}

/// Default Android BiometricPrompt title (Flutter `local_auth` default).
const androidSignInTitle = 'Authentication required';

/// Default Android BiometricPrompt subtitle.
const androidSignInHint = 'Verify identity';

/// Default Android negative-button label (biometric-only prompts).
const androidCancelButton = 'Cancel';

/// Default iOS cancel-button label (Flutter `local_auth` default is `OK`).
const iosCancelButton = 'OK';

/// Android-side authentication messages.
class AndroidAuthMessages extends AuthMessages {
  const AndroidAuthMessages({
    this.signInHint,
    this.cancelButton,
    this.signInTitle,
  });

  /// Subtitle on the BiometricPrompt. Maximum 60 characters.
  final String? signInHint;

  /// Negative button when the prompt is biometric-only.
  /// Maximum 30 characters.
  final String? cancelButton;

  /// Title on the BiometricPrompt. Maximum 60 characters.
  final String? signInTitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidAuthMessages &&
          signInHint == other.signInHint &&
          cancelButton == other.cancelButton &&
          signInTitle == other.signInTitle;

  @override
  int get hashCode => Object.hash(signInHint, cancelButton, signInTitle);
}

/// iOS-side authentication messages.
class IOSAuthMessages extends AuthMessages {
  const IOSAuthMessages({this.cancelButton, this.localizedFallbackTitle});

  /// `LAContext.localizedCancelTitle`. Maximum 30 characters.
  final String? cancelButton;

  /// `LAContext.localizedFallbackTitle`. Empty string hides the fallback
  /// button.
  final String? localizedFallbackTitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IOSAuthMessages &&
          cancelButton == other.cancelButton &&
          localizedFallbackTitle == other.localizedFallbackTitle;

  @override
  int get hashCode => Object.hash(cancelButton, localizedFallbackTitle);
}
