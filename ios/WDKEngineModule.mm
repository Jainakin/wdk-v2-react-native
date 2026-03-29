/**
 * WDKEngineModule.mm — ObjC++ bridge for the WDKEngineModule TurboModule
 *
 * Declares the ObjC interface (RCT_EXTERN_MODULE / RCT_EXTERN_METHOD) that
 * bridges to WDKEngineModule.swift, and implements getTurboModule: so that
 * the module is accessible via TurboModuleRegistry.getEnforcing() in RN 0.76+
 * bridgeless (new arch) mode.
 *
 * getTurboModule: uses ObjCTurboModule — a React Native runtime class that
 * dynamically wraps any RCTBridgeModule as a TurboModule using ObjC runtime
 * introspection. No codegen / NativeWDKEngineSpecJSI required.
 *
 * The actual business logic lives in WDKEngineModule.swift.
 */

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <ReactCommon/RCTTurboModule.h>

@interface RCT_EXTERN_REMAP_MODULE(WDKEngine, WDKEngineModule, RCTEventEmitter)

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

RCT_EXTERN_METHOD(writeTestLog:
                  (NSString *)content
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

/**
 * getTurboModule: — registers this module as a TurboModule in bridgeless mode.
 *
 * ObjCTurboModule wraps the ObjC methods declared above via runtime
 * introspection, so TurboModuleRegistry.getEnforcing('WDKEngine') can find
 * and call the module without a codegen-generated JSI binding.
 */
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::ObjCTurboModule>(params);
}

@end
