/**
 * WDKEngineModule.mm — Objective-C++ bridge for React Native
 *
 * React Native's TurboModule infrastructure requires an ObjC/ObjC++ file
 * that exports the module. The actual implementation is in Swift.
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
