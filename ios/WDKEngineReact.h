/*
 * WDKEngineReact.h — Exposes React Native ObjC types to the pod's Swift module
 *
 * CocoaPods includes every .h file in source_files in the generated umbrella
 * header, which becomes part of the pod's module map. Swift code in the pod
 * can then see RCTBridgeModule, RCTPromiseResolveBlock, RCTPromiseRejectBlock,
 * and other React Native ObjC types — without a bridging header.
 *
 * Why this file exists:
 *   Swift pods cannot use bridging headers. The only way to expose ObjC
 *   types from a dependency (React-Core) to Swift in the same pod is to
 *   #import them in a header that lands in the pod's umbrella.
 */

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
