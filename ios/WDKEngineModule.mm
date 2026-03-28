/**
 * WDKEngineModule.mm — ObjC bridge for the WDKEngineModule TurboModule
 *
 * Declares the ObjC interface that bridges to WDKEngineModule.swift.
 * Uses RCT_EXTERN_MODULE / RCT_EXTERN_METHOD — the standard pattern for
 * Swift TurboModules in React Native 0.76+.
 *
 * Why no getTurboModule: / NativeWDKEngineSpecJSI?
 *   Those require codegen to produce WDKEngineSpec.h, which only exists
 *   after running the codegen pipeline. Our module works correctly without
 *   the generated JSI binding — RN 0.76+ new arch auto-wraps RCT_EXTERN_MODULE
 *   classes as TurboModules accessible via TurboModuleRegistry.getEnforcing().
 *
 * The actual business logic lives in WDKEngineModule.swift.
 */

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(WDKEngineModule, NSObject)

RCT_EXTERN_METHOD(initialize:
                  (RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(call:
                  (NSString *)method
                  jsonArgs:(NSString *)jsonArgs
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getState:
                  (RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(destroy:
                  (RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

@end
