Pod::Spec.new do |s|
  s.name             = 'dartnative_local_auth'
  s.version          = '0.1.0'
  s.summary          = 'Local authentication (Face ID / Touch ID) for DartNative.'
  s.description      = <<-DESC
    Wraps LocalAuthentication.framework over FFI @_cdecl — Face ID, Touch ID,
    Optic ID, and device passcode fallback. Zero Flutter platform channels.
  DESC
  s.homepage         = 'https://github.com/flutterninja9/dartnative_local_auth'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Anirudh' => 'anirudh@local' }
  s.platform         = :ios, '13.0'

  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.swift'
  s.frameworks       = 'LocalAuthentication', 'UIKit', 'Foundation'

  s.swift_version    = '5.9'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
end
