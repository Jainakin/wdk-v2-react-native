require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = "wdk-v2-react-native"
  s.version      = package['version']
  s.summary      = package['description']
  s.homepage     = "https://github.com/Jainakin/wdk-v2-react-native"
  s.license      = package['license']
  s.author       = "Tether"
  s.platform     = :ios, "15.0"
  s.source       = { :git => "https://github.com/Jainakin/wdk-v2-react-native.git", :tag => s.version }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  # Depend on the native engine (Phase 1)
  # In production, this would be a CocoaPod or SPM package.
  # For now, the engine is linked from the app's Xcode project.

  s.dependency "React-Core"

  s.swift_version = "5.9"
end
