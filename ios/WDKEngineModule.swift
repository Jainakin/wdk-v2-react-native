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
// MARK: - WDKEngineModule — TurboModule Implementation
// ════════════════════════════════════════════════════════════════════

@objc(WDKEngineModule)
class WDKEngineModule: NSObject, RCTBridgeModule {

    // MARK: Module identity

    @objc static func moduleName() -> String { "WDKEngine" }
    @objc static func requiresMainQueueSetup() -> Bool { false }

    // MARK: Private state

    private let engineQueue = DispatchQueue(
        label: "com.tetherto.wdk.engine",
        qos: .userInitiated
    )
    private var engine: OpaquePointer?
    private var isInitialized = false

    // Static C strings for platform info (must outlive the C structs)
    private static let osName  = strdup("ios")!
    private static let version = strdup("0.2.0")!

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

            // 2. Platform bridge — OS info, random bytes, logging
            var platform = WDKPlatformProvider(
                os_name:          WDKEngineModule.osName,
                engine_version:   WDKEngineModule.version,
                get_random_bytes: wdkGetRandomBytes,
                log_message:      wdkLogMessage
            )
            wdk_register_platform_bridge(ctx, &platform)

            // 3. Storage bridge — Keychain (secure) + UserDefaults (regular)
            var storage = WDKStorageProvider(
                secure_set:     wdkSecureSet,
                secure_get:     wdkSecureGet,
                secure_delete:  wdkSecureDelete,
                secure_has:     wdkSecureHas,
                regular_set:    wdkRegularSet,
                regular_get:    wdkRegularGet,
                regular_delete: wdkRegularDelete
            )
            wdk_register_storage_bridge(ctx, &storage)

            // 4. Network bridge — URLSession
            var net = WDKNetProvider(fetch: wdkFetch)
            wdk_register_net_bridge(ctx, &net)

            // 5. Load JS bundle from app bundle resources
            guard let bundleURL = Bundle.main.url(
                forResource: "wdk-bundle",
                withExtension: "js"
            ) else {
                reject("E_BUNDLE", "wdk-bundle.js not found in app bundle", nil)
                return
            }

            guard let jsSource = try? String(contentsOf: bundleURL, encoding: .utf8) else {
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
            let state = String(cString: resultPtr)
            wdk_free_string(resultPtr)
            // Strip wrapping JSON quotes: "\"locked\"" → "locked"
            let cleaned = state.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            resolve(cleaned)
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

    deinit {
        if let eng = engine { wdk_engine_destroy(eng) }
    }
}
