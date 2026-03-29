/**
 * NativeWDKEngine — TurboModule spec
 *
 * This defines the native module interface that React Native's
 * codegen uses to generate the native-side bridge code.
 *
 * The native implementation (Swift/Kotlin) receives these calls
 * and routes them to the wdk-v2-engine C library.
 */

import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Required by RCTEventEmitter — called by NativeEventEmitter when a
   * subscriber is added.  The native side increments its listener count.
   */
  addListener(eventName: string): void;

  /**
   * Required by RCTEventEmitter — called by NativeEventEmitter when
   * subscribers are removed.  The native side decrements its listener count.
   */
  removeListeners(count: number): void;

  /**
   * Initialize the engine and load the JS bytecode bundle.
   * Must be called once before any other method.
   */
  initialize(): Promise<boolean>;

  /**
   * Call a WDK function by name with JSON-encoded arguments.
   * Returns JSON-encoded result.
   *
   * This is the single entry point — all WDK operations go through here.
   * The native side calls wdk_engine_call(engine, method, jsonArgs).
   *
   * @param method - Function name (e.g., "createWallet", "unlockWallet")
   * @param jsonArgs - JSON-encoded arguments
   * @returns JSON-encoded result
   */
  call(method: string, jsonArgs: string): Promise<string>;

  /**
   * Get the current wallet state.
   */
  getState(): Promise<string>;

  /**
   * Destroy the engine and release all resources.
   */
  destroy(): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('WDKEngine');
