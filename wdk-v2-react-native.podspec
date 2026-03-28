require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

# Resolve react_native_pods.rb to get install_modules_dependencies helper
# This handles all the New Architecture / TurboModule setup automatically.
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

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

  s.swift_version = "5.9"

  # Use install_modules_dependencies to set up TurboModule / New Architecture
  # dependencies automatically. This replaces the old "React-Core" dependency
  # and handles codegen, Folly, ReactCommon headers, etc.
  if defined?(install_modules_dependencies)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"
    s.dependency "ReactCommon/turbomodule/core"
  end
end
