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

  # Source files: ObjC bridge (.mm) + Swift implementation + C header for Swift→C interop
  s.source_files = "ios/**/*.{h,m,mm,swift}"

  # WDKEngineBridge.h is a public header — CocoaPods includes it in the
  # generated umbrella header so that WDKEngineModule.swift can see the C
  # engine functions (wdk_engine_create, etc.) via the pod's module map.
  # The app's bridging header no longer declares these functions, so there
  # is no duplicate-declaration conflict.

  s.swift_version = "5.9"

  # React-Core: ObjC bridge types (RCTBridgeModule, RCTPromiseResolveBlock, etc.)
  # ReactCommon/turbomodule/core: ObjCTurboModule runtime — wraps RCT_EXTERN_MODULE
  #   classes as TurboModules accessible via TurboModuleRegistry.getEnforcing()
  #   in RN 0.76+ bridgeless mode, without requiring codegen.
  s.dependency "React-Core"
  s.dependency "ReactCommon/turbomodule/core"
  s.dependency "React-NativeModulesApple"
end
