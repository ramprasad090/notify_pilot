Pod::Spec.new do |s|
  s.name             = 'notify_pilot'
  s.version          = '1.0.0'
  s.summary          = 'Unified notification API for Flutter.'
  s.description      = <<-DESC
Unified notification API for Flutter. Local + push + scheduled
notifications in 3 lines. Cron scheduling, auto-grouping,
notification history, action buttons, analytics.
                       DESC
  s.homepage         = 'https://github.com/ramprasad090/notify_pilot'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ramprasad' => 'ramprasad090@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
