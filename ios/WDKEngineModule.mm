/**
 * WDKEngineModule.mm — ObjC++ TurboModule bridge for React Native 0.76+
 *
 * This file:
 * 1. Declares the ObjC interface that bridges to the Swift implementation
 * 2. Exports the module using RCT_EXTERN_MODULE / RCT_EXTERN_METHOD
 * 3. Implements getTurboModule: so the TurboModule infrastructure can
 *    create the JSI binding (codegen-generated NativeWDKEngineSpecJSI)
 *
 * The actual business logic lives in WDKEngineModule.swift.
 */

#import <React/RCTBridgeModule.h>
#import <ReactCommon/RCTTurboModule.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <WDKEngineSpec/WDKEngineSpec.h>
#endif

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

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeWDKEngineSpecJSI>(params);
}
#endif

@end
