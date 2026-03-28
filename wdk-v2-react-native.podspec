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

  # Use React-Core only — no codegen / install_modules_dependencies.
  #
  # Rationale: getTurboModule: requires codegen-generated WDKEngineSpec.h,
  # which only exists after the full codegen pipeline runs. In RN 0.76+ new
  # arch, RCT_EXTERN_MODULE classes are automatically accessible via
  # TurboModuleRegistry.getEnforcing() without needing the generated JSI
  # binding. This avoids the RN 0.83 duplicate-symbol linker issue entirely.
  s.dependency "React-Core"
end
