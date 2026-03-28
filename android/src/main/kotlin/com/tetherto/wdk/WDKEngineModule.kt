/**
 * WDKEngineModule — Android TurboModule Implementation (RN 0.76+)
 *
 * Bridge between React Native's JS thread and the wdk-v2-engine C library.
 * All heavy work runs on Dispatchers.Default via coroutines.
 *
 * Extends NativeWDKEngineSpec (codegen-generated from NativeWDKEngine.ts)
 * to properly integrate with the TurboModule infrastructure.
 */

package com.tetherto.wdk

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactMethod
import com.tetherto.wdk.NativeWDKEngineSpec
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader

class WDKEngineModule(reactContext: ReactApplicationContext) :
    NativeWDKEngineSpec(reactContext) {

    companion object {
        const val NAME = "WDKEngine"

        init {
            System.loadLibrary("wdk_engine")
        }
    }

    // Native JNI methods (from wdk-v2-engine)
    private external fun nativeCreate(): Long
    private external fun nativeLoadBytecode(ptr: Long, bytecode: ByteArray): Int
    private external fun nativeCall(ptr: Long, method: String, jsonArgs: String): String?
    private external fun nativePump(ptr: Long): Int
    private external fun nativeGetError(ptr: Long): String?
    private external fun nativeDestroy(ptr: Long)

    // Engine state
    private var enginePtr: Long = 0
    private var isInitialized = false
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val mutex = kotlinx.coroutines.sync.Mutex()

    override fun getName(): String = NAME

    /**
     * Initialize the engine: create QuickJS context, register bridges, load JS bundle.
     */
    @ReactMethod
    override fun initialize(promise: Promise) {
        scope.launch {
            mutex.withLock {
                try {
                    if (isInitialized) {
                        promise.resolve(true)
                        return@withLock
                    }

                    // 1. Create the C engine
                    enginePtr = nativeCreate()
                    if (enginePtr == 0L) {
                        promise.reject("E_CREATE", "Failed to create WDK engine")
                        return@withLock
                    }

                    // 2. Load the JS bundle from assets
                    val jsCode = loadAsset("wdk-bundle.js")
                    if (jsCode == null) {
                        promise.reject("E_BUNDLE", "wdk-bundle.js not found in assets")
                        return@withLock
                    }

                    // Evaluate the JS bundle
                    // Note: For production, use precompiled bytecode (.qbc)
                    val result = nativeCall(enginePtr, "__eval", jsCode)
                    nativePump(enginePtr)

                    isInitialized = true
                    promise.resolve(true)
                } catch (e: Exception) {
                    promise.reject("E_INIT", "Initialization failed: ${e.message}")
                }
            }
        }
    }

    /**
     * Call a WDK function by name with JSON arguments.
     */
    @ReactMethod
    override fun call(method: String, jsonArgs: String, promise: Promise) {
        scope.launch {
            mutex.withLock {
                try {
                    if (enginePtr == 0L) {
                        promise.reject("E_NOT_INIT", "Engine not initialized")
                        return@withLock
                    }

                    val result = nativeCall(enginePtr, method, jsonArgs)
                    nativePump(enginePtr)

                    if (result != null) {
                        promise.resolve(result)
                    } else {
                        val error = nativeGetError(enginePtr) ?: "Unknown error"
                        promise.reject("E_CALL", "Call failed: $error")
                    }
                } catch (e: Exception) {
                    promise.reject("E_CALL", "Call exception: ${e.message}")
                }
            }
        }
    }

    /**
     * Get the current wallet state.
     */
    @ReactMethod
    override fun getState(promise: Promise) {
        scope.launch {
            mutex.withLock {
                try {
                    if (enginePtr == 0L) {
                        promise.resolve("locked")
                        return@withLock
                    }

                    val result = nativeCall(enginePtr, "getState", "{}")
                    nativePump(enginePtr)

                    // Strip JSON quotes
                    val state = result?.trim('"') ?: "locked"
                    promise.resolve(state)
                } catch (e: Exception) {
                    promise.resolve("locked")
                }
            }
        }
    }

    /**
     * Destroy the engine and release all resources.
     */
    @ReactMethod
    override fun destroy(promise: Promise) {
        scope.launch {
            mutex.withLock {
                try {
                    if (enginePtr != 0L) {
                        nativeDestroy(enginePtr)
                        enginePtr = 0
                    }
                    isInitialized = false
                    promise.resolve(null)
                } catch (e: Exception) {
                    promise.reject("E_DESTROY", "Destroy failed: ${e.message}")
                }
            }
        }
    }

    /**
     * Load a text file from the Android assets directory.
     */
    private fun loadAsset(name: String): String? {
        return try {
            val inputStream = reactApplicationContext.assets.open(name)
            val reader = BufferedReader(InputStreamReader(inputStream))
            val content = reader.readText()
            reader.close()
            content
        } catch (e: Exception) {
            null
        }
    }

    override fun onCatalystInstanceDestroy() {
        scope.cancel()
        if (enginePtr != 0L) {
            nativeDestroy(enginePtr)
            enginePtr = 0
        }
    }
}
