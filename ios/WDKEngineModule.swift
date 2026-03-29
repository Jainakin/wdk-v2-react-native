/**
 * WDKEngineModule.swift — iOS TurboModule for wdk-v2-react-native
 *
 * Bridges React Native's JS thread to the wdk-v2-engine C library.
 * All engine operations run on a serial background GCD queue.
 *
 * JS module name:  "WDKEngine"
 * ObjC class name: WDKEngineModule (matches RCT_EXTERN_MODULE in .mm)
 * Spec file:       src/NativeWDKEngine.ts
 *
 * Platform providers registered on initialize():
 *   - Platform: SecRandomCopyBytes, print(), "ios"
 *   - Storage:  iOS Keychain (secure) + UserDefaults (regular)
 *   - Network:  URLSession.shared
 */

import Foundation
import Security

// ════════════════════════════════════════════════════════════════════
// MARK: - C Callbacks (file-scope, @convention(c) compatible)
//
// These MUST be top-level (not inside a class/struct) because they
// are passed as raw C function pointers to the C bridge structs.
// ════════════════════════════════════════════════════════════════════

private let wdkKeychainService = "com.tetherto.wdk"
private let wdkDefaultsSuite   = "com.tetherto.wdk.storage"

// MARK: Platform: random bytes

private func wdkGetRandomBytes(_ buf: UnsafeMutablePointer<UInt8>?,
                                _ len: Int) -> Int32 {
    guard let buf, len > 0 else { return -1 }
    return SecRandomCopyBytes(kSecRandomDefault, len, buf) == errSecSuccess ? 0 : -1
}

// MARK: Platform: log

private func wdkLogMessage(_ level: Int32,
                            _ message: UnsafePointer<CChar>?) {
    guard let message else { return }
    let msg = String(cString: message)
    switch level {
    case 0: print("[WDK DEBUG] \(msg)")
    case 1: print("[WDK INFO]  \(msg)")
    case 2: print("[WDK WARN]  \(msg)")
    case 3: print("[WDK ERROR] \(msg)")
    default: print("[WDK]       \(msg)")
    }
}

// MARK: Secure Storage: Keychain

private func wdkSecureSet(_ key: UnsafePointer<CChar>?,
                           _ value: UnsafePointer<UInt8>?,
                           _ valueLen: Int) -> Int32 {
    guard let key, let value, valueLen > 0 else { return -1 }
    let keyStr = String(cString: key)
    let data   = Data(bytes: value, count: valueLen)

    let del: [String: Any] = [
        kSecClass as String:       kSecClassGenericPassword,
        kSecAttrService as String: wdkKeychainService,
        kSecAttrAccount as String: keyStr,
    ]
    SecItemDelete(del as CFDictionary)

    let add: [String: Any] = [
        kSecClass as String:       kSecClassGenericPassword,
        kSecAttrService as String: wdkKeychainService,
        kSecAttrAccount as String: keyStr,
        kSecValueData as String:   data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? 0 : -1
}

private func wdkSecureGet(_ key: UnsafePointer<CChar>?,
                           _ outValue: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
                           _ outLen: UnsafeMutablePointer<Int>?) -> Int32 {
    guard let key, let outValue, let outLen else { return -1 }
    let keyStr = String(cString: key)

    let query: [String: Any] = [
        kSecClass as String:       kSecClassGenericPassword,
        kSecAttrService as String: wdkKeychainService,
        kSecAttrAccount as String: keyStr,
        kSecReturnData as String:  true,
        kSecMatchLimit as String:  kSecMatchLimitOne,
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess, let data = result as? Data else {
        outValue.pointee = nil
        outLen.pointee   = 0
        return -1
    }

    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
    data.copyBytes(to: buf, count: data.count)
    outValue.pointee = buf
    outLen.pointee   = data.count
    return 0
}

private func wdkSecureDelete(_ key: UnsafePointer<CChar>?) -> Int32 {
    guard let key else { return -1 }
    let query: [String: Any] = [
        kSecClass as String:       kSecClassGenericPassword,
        kSecAttrService as String: wdkKeychainService,
        kSecAttrAccount as String: String(cString: key),
    ]
    let st = SecItemDelete(query as CFDictionary)
    return (st == errSecSuccess || st == errSecItemNotFound) ? 0 : -1
}

private func wdkSecureHas(_ key: UnsafePointer<CChar>?) -> Int32 {
    guard let key else { return 0 }
    let query: [String: Any] = [
        kSecClass as String:       kSecClassGenericPassword,
        kSecAttrService as String: wdkKeychainService,
        kSecAttrAccount as String: String(cString: key),
        kSecReturnData as String:  false,
    ]
    return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess ? 1 : 0
}

// MARK: Regular Storage: UserDefaults

private func wdkRegularSet(_ key: UnsafePointer<CChar>?,
                            _ value: UnsafePointer<CChar>?) -> Int32 {
    guard let key, let value else { return -1 }
    let defaults = UserDefaults(suiteName: wdkDefaultsSuite) ?? .standard
    defaults.set(String(cString: value), forKey: String(cString: key))
    return 0
}

private func wdkRegularGet(_ key: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
    guard let key else { return nil }
    let defaults = UserDefaults(suiteName: wdkDefaultsSuite) ?? .standard
    guard let val = defaults.string(forKey: String(cString: key)) else { return nil }
    return strdup(val)
}

private func wdkRegularDelete(_ key: UnsafePointer<CChar>?) -> Int32 {
    guard let key else { return -1 }
    let defaults = UserDefaults(suiteName: wdkDefaultsSuite) ?? .standard
    defaults.removeObject(forKey: String(cString: key))
    return 0
}

// MARK: Network: URLSession

private func wdkFetch(
    _ url: UnsafePointer<CChar>?,
    _ method: UnsafePointer<CChar>?,
    _ headersJson: UnsafePointer<CChar>?,
    _ body: UnsafePointer<UInt8>?,
    _ bodyLen: Int,
    _ timeoutMs: Int32,
    _ context: UnsafeMutableRawPointer?,
    _ callback: WDKFetchCallback?
) {
    guard let url, let callback else {
        callback?(context, 0, nil, nil, 0, "Invalid parameters")
        return
    }

    let urlStr    = String(cString: url)
    let methodStr = method != nil ? String(cString: method!) : "GET"

    guard let requestURL = URL(string: urlStr) else {
        "Invalid URL".withCString { callback(context, 0, nil, nil, 0, $0) }
        return
    }

    var request = URLRequest(url: requestURL)
    request.httpMethod      = methodStr
    request.timeoutInterval = timeoutMs > 0 ? TimeInterval(timeoutMs) / 1000.0 : 30.0

    if let headersJson {
        let hStr = String(cString: headersJson)
        if let data = hStr.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            for (k, v) in dict { request.setValue(v, forHTTPHeaderField: k) }
        }
    }

    if let body, bodyLen > 0 {
        request.httpBody = Data(bytes: body, count: bodyLen)
    }

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
            let errStr = error.localizedDescription
            errStr.withCString { cStr in callback(context, 0, nil, nil, 0, cStr) }
            return
        }

        let http       = response as? HTTPURLResponse
        let statusCode = Int32(http?.statusCode ?? 0)

        var hDict: [String: String] = [:]
        if let allHeaders = http?.allHeaderFields {
            for (k, v) in allHeaders { hDict["\(k)"] = "\(v)" }
        }
        let hJson = (try? JSONSerialization.data(withJSONObject: hDict))
                        .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let bodyData = data ?? Data()
        hJson.withCString { hCStr in
            bodyData.withUnsafeBytes { buf in
                let ptr = buf.baseAddress?.assumingMemoryBound(to: UInt8.self)
                callback(context, statusCode, hCStr, ptr, bodyData.count, nil)
            }
        }
    }.resume()
}

// ════════════════════════════════════════════════════════════════════
// MARK: - WDKEngineModule — TurboModule + EventEmitter Implementation
// ════════════════════════════════════════════════════════════════════

@objc(WDKEngineModule)
class WDKEngineModule: RCTEventEmitter {

    // MARK: Module identity

    @objc override static func moduleName() -> String! { "WDKEngine" }
    @objc override static func requiresMainQueueSetup() -> Bool { false }

    // MARK: - RCTEventEmitter

    /// The single event emitted whenever the wallet state changes.
    override func supportedEvents() -> [String]! {
        return ["wdkStateChange"]
    }

    // Avoid the "sendEvent called without observer" warning in dev builds.
    private var listenerCount = 0

    override func startObserving() {
        listenerCount += 1
    }

    override func stopObserving() {
        listenerCount -= 1
    }

    /// Emit a state-change event to JS — only when at least one listener is active.
    private func emitStateChange(_ state: String) {
        guard listenerCount > 0 else { return }
        sendEvent(withName: "wdkStateChange", body: ["state": state])
    }

    // MARK: Private state

    private let engineQueue = DispatchQueue(
        label: "com.tetherto.wdk.engine",
        qos: .userInitiated
    )
    private var engine: OpaquePointer?
    private var isInitialized = false

    // Static C strings for platform info (must outlive the provider structs)
    private static let osName  = strdup("ios")!
    private static let version = strdup("0.2.0")!

    // Provider structs heap-allocated so C bridge pointers remain valid
    // after initialize() returns. The C bridge stores raw pointers
    // (s_platform_provider = provider) so these must stay alive as long
    // as the engine is alive. Deallocated in deinit.
    private var platformProviderPtr: UnsafeMutablePointer<WDKPlatformProvider>?
    private var storageProviderPtr:  UnsafeMutablePointer<WDKStorageProvider>?
    private var netProviderPtr:      UnsafeMutablePointer<WDKNetProvider>?

    // MARK: - initialize()

    @objc func initialize(
        _ resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        engineQueue.async { [weak self] in
            guard let self else { return }

            if self.isInitialized { resolve(true); return }

            // 1. Create QuickJS engine
            guard let eng = wdk_engine_create() else {
                reject("E_CREATE", "wdk_engine_create() returned NULL", nil)
                return
            }
            self.engine = eng

            let ctx = wdk_engine_get_context(eng)

            // 2. Pure-C bridges (crypto + encoding) — no provider struct needed
            wdk_register_crypto_bridge(ctx)
            wdk_register_encoding_bridge(ctx)

            // 3. Platform bridge — heap-allocated so the C static pointer stays valid
            let pp = UnsafeMutablePointer<WDKPlatformProvider>.allocate(capacity: 1)
            pp.initialize(to: WDKPlatformProvider(
                os_name:          WDKEngineModule.osName,
                engine_version:   WDKEngineModule.version,
                get_random_bytes: wdkGetRandomBytes,
                log_message:      wdkLogMessage
            ))
            self.platformProviderPtr = pp
            wdk_register_platform_bridge(ctx, pp)

            // 4. Storage bridge — Keychain (secure) + UserDefaults (regular)
            let sp = UnsafeMutablePointer<WDKStorageProvider>.allocate(capacity: 1)
            sp.initialize(to: WDKStorageProvider(
                secure_set:     wdkSecureSet,
                secure_get:     wdkSecureGet,
                secure_delete:  wdkSecureDelete,
                secure_has:     wdkSecureHas,
                regular_set:    wdkRegularSet,
                regular_get:    wdkRegularGet,
                regular_delete: wdkRegularDelete
            ))
            self.storageProviderPtr = sp
            wdk_register_storage_bridge(ctx, sp)

            // 5. Network bridge — URLSession
            let np = UnsafeMutablePointer<WDKNetProvider>.allocate(capacity: 1)
            np.initialize(to: WDKNetProvider(fetch: wdkFetch))
            self.netProviderPtr = np
            wdk_register_net_bridge(ctx, np)

            // 6. Load bundle: prefer pre-compiled bytecode (.qbc), fall back to source (.js)
            var bundleLoaded = false

            if let qbcURL = Bundle.main.url(forResource: "wdk-bundle", withExtension: "qbc"),
               let qbcData = try? Data(contentsOf: qbcURL) {
                let rc = qbcData.withUnsafeBytes { buf -> Int32 in
                    wdk_engine_load_bytecode(
                        eng,
                        buf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        qbcData.count
                    )
                }
                if rc == 0 {
                    bundleLoaded = true
                    print("[WDK INFO]  Loaded wdk-bundle.qbc (bytecode)")
                } else {
                    print("[WDK WARN]  wdk-bundle.qbc load failed — falling back to .js")
                }
            }

            if !bundleLoaded {
                guard let jsURL = Bundle.main.url(
                    forResource: "wdk-bundle",
                    withExtension: "js"
                ) else {
                    reject("E_BUNDLE", "wdk-bundle.js not found in app bundle", nil)
                    return
                }
                guard let jsSource = try? String(contentsOf: jsURL, encoding: .utf8) else {
                    reject("E_LOAD", "Failed to read wdk-bundle.js", nil)
                    return
                }
                let evalResult = wdk_engine_eval(eng, jsSource)
                if evalResult != 0 {
                    let err = wdk_engine_get_error(eng).map { String(cString: $0) }
                                 ?? "Unknown eval error"
                    reject("E_EVAL", err, nil)
                    return
                }
                print("[WDK INFO]  Loaded wdk-bundle.js (source eval)")
            }
            _ = wdk_engine_pump(eng)

            self.isInitialized = true
            resolve(true)
        }
    }

    // MARK: - call(method:jsonArgs:)

    @objc func call(
        _ method: String,
        jsonArgs: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        engineQueue.async { [weak self] in
            guard let self, let eng = self.engine else {
                reject("E_NOT_INIT", "Engine not initialized — call initialize() first", nil)
                return
            }

            guard let resultPtr = wdk_engine_call(eng, method, jsonArgs) else {
                let err = wdk_engine_get_error(eng).map { String(cString: $0) } ?? "Unknown error"
                reject("E_CALL", "'\(method)' failed: \(err)", nil)
                return
            }

            let result = String(cString: resultPtr)
            wdk_free_string(resultPtr)
            _ = wdk_engine_pump(eng)
            resolve(result)

            // Emit state-change event for methods that mutate wallet state
            let stateMutators: Set<String> = [
                "createWallet", "unlockWallet", "lockWallet", "destroyWallet"
            ]
            if stateMutators.contains(method),
               let statePtr = wdk_engine_call(eng, "getState", "{}") {
                let stateJson = String(cString: statePtr)
                wdk_free_string(statePtr)
                let decoded = (try? JSONSerialization.jsonObject(
                    with: Data(stateJson.utf8)
                ) as? String) ?? stateJson
                self.emitStateChange(decoded)
            }
        }
    }

    // MARK: - getState()

    @objc func getState(
        _ resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        engineQueue.async { [weak self] in
            guard let self, let eng = self.engine else {
                resolve("locked"); return
            }
            guard let resultPtr = wdk_engine_call(eng, "getState", "{}") else {
                resolve("locked"); return
            }
            let jsonString = String(cString: resultPtr)
            wdk_free_string(resultPtr)
            // wdk_engine_call JSON.stringifies the result, so a string "locked"
            // comes back as "\"locked\"". Decode it properly via JSONSerialization.
            // Must use .fragmentsAllowed because a bare JSON string like "ready"
            // is not a valid top-level JSON object/array per default options.
            let decoded = (try? JSONSerialization.jsonObject(
                with: Data(jsonString.utf8),
                options: .fragmentsAllowed
            ) as? String) ?? jsonString
            resolve(decoded)
        }
    }

    // MARK: - destroy()

    @objc func destroy(
        _ resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        engineQueue.async { [weak self] in
            guard let self else { resolve(nil); return }
            if let eng = self.engine {
                wdk_engine_destroy(eng)
                self.engine = nil
            }
            self.isInitialized = false
            resolve(nil)
        }
    }

    // MARK: - writeTestLog() — writes test output to tmp dir for host reading

    @objc func writeTestLog(
        _ content: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        let tmpDir = NSTemporaryDirectory()
        let filePath = (tmpDir as NSString).appendingPathComponent("wdk-test-results.txt")
        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            NSLog("[WDK_TEST_LOG] Results written to: %@", filePath)
            // Also log each line via NSLog so it appears in os_log
            for line in content.components(separatedBy: "\n") {
                NSLog("%@", line)
            }
            resolve(filePath)
        } catch {
            reject("WRITE_ERR", "Failed to write test log: \(error)", error)
        }
    }

    deinit {
        if let eng = engine { wdk_engine_destroy(eng) }
        // Release heap-allocated provider structs now that the engine is gone
        platformProviderPtr?.deallocate()
        storageProviderPtr?.deallocate()
        netProviderPtr?.deallocate()
    }
}
