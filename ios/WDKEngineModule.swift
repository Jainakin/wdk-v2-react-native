/**
 * WDKEngineModule — iOS TurboModule Implementation (RN 0.76+)
 *
 * This is the bridge between React Native's JS thread and the
 * wdk-v2-engine C library. All heavy work (QuickJS, crypto) runs
 * on a background GCD queue.
 *
 * Module name exposed to JS: "WDKEngine"
 * Spec file: src/NativeWDKEngine.ts
 */

import Foundation

@objc(WDKEngineModule)
class WDKEngineModule: NSObject, RCTBridgeModule {

    // MARK: - Private State

    /// Serial background queue for all engine operations
    private let engineQueue = DispatchQueue(
        label: "com.tetherto.wdk.engine",
        qos: .userInitiated
    )

    /// The native C engine pointer (opaque)
    private var engine: OpaquePointer?

    /// Whether the engine has been initialized
    private var isInitialized = false

    // MARK: - Module Setup

    @objc static func moduleName() -> String {
        return "WDKEngine"
    }

    @objc static func requiresMainQueueSetup() -> Bool {
        return false
    }

    // MARK: - TurboModule Methods

    /// Initialize the engine: create QuickJS context, register bridges, load bytecode
    @objc func initialize(
        _ resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        engineQueue.async { [weak self] in
            guard let self = self else {
                reject("E_DESTROYED", "Module destroyed", nil)
                return
            }

            if self.isInitialized {
                resolve(true)
                return
            }

            // 1. Create the C engine
            guard let eng = wdk_engine_create() else {
                reject("E_CREATE", "Failed to create WDK engine", nil)
                return
            }
            self.engine = eng

            // 2. Load the JS bytecode bundle from the app bundle
            //    The bundle should be included as a resource named "wdk-bundle.js"
            guard let bundleURL = Bundle.main.url(
                forResource: "wdk-bundle",
                withExtension: "js"
            ) else {
                reject("E_BUNDLE", "wdk-bundle.js not found in app bundle", nil)
                return
            }

            do {
                let jsCode = try String(contentsOf: bundleURL, encoding: .utf8)
                let cStr = jsCode.cString(using: .utf8)!

                // Evaluate the JS bundle in the QuickJS context
                // Note: For production, use precompiled bytecode (.qbc) instead
                let result = wdk_engine_eval(eng, cStr)
                if result != 0 {
                    let error = String(cString: wdk_engine_get_error(eng))
                    reject("E_EVAL", "Failed to evaluate JS bundle: \(error)", nil)
                    return
                }

                self.isInitialized = true
                resolve(true)
            } catch {
                reject("E_LOAD", "Failed to read JS bundle: \(error)", nil)
            }
        }
    }

    /// Call a WDK function by name with JSON arguments
    @objc func call(
        _ method: String,
        jsonArgs: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        engineQueue.async { [weak self] in
            guard let self = self, let engine = self.engine else {
                reject("E_NOT_INIT", "Engine not initialized", nil)
                return
            }

            guard let result = wdk_engine_call(engine, method, jsonArgs) else {
                let error = String(cString: wdk_engine_get_error(engine))
                reject("E_CALL", "Call failed: \(error)", nil)
                return
            }

            let resultStr = String(cString: result)
            wdk_free_string(result)

            // Pump the event loop to process any pending Promises
            wdk_engine_pump(engine)

            resolve(resultStr)
        }
    }

    /// Get the current wallet state
    @objc func getState(
        _ resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        engineQueue.async { [weak self] in
            guard let self = self, let engine = self.engine else {
                resolve("locked")
                return
            }

            guard let result = wdk_engine_call(engine, "getState", "{}") else {
                resolve("locked")
                return
            }

            let state = String(cString: result)
            wdk_free_string(result)

            // Strip JSON quotes if present
            let cleaned = state.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            resolve(cleaned)
        }
    }

    /// Destroy the engine and release all resources
    @objc func destroy(
        _ resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        engineQueue.async { [weak self] in
            guard let self = self else {
                resolve(nil)
                return
            }

            if let engine = self.engine {
                wdk_engine_destroy(engine)
                self.engine = nil
            }
            self.isInitialized = false
            resolve(nil)
        }
    }

    deinit {
        if let engine = self.engine {
            wdk_engine_destroy(engine)
        }
    }
}
