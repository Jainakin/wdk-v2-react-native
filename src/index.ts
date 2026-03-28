/**
 * wdk-v2-react-native — Public API
 *
 * Provides a clean TypeScript API for React Native apps to interact
 * with the WDK v2 wallet engine. All calls are routed through the
 * TurboModule to the native C engine running on a background thread.
 *
 * Usage:
 *   import { WDKWallet, useWalletState } from 'wdk-v2-react-native';
 *
 *   // Create wallet
 *   const { mnemonic } = await WDKWallet.createWallet();
 *
 *   // Unlock
 *   await WDKWallet.unlockWallet({ mnemonic });
 *
 *   // Send (requires chain module registered — Phase 4+)
 *   const { txHash } = await WDKWallet.send({ chain: 'btc', to: '...', amount: '0.001' });
 */

import NativeWDKEngine from './NativeWDKEngine';
import type {
  WalletState,
  ChainId,
  CreateWalletParams,
  CreateWalletResult,
  UnlockWalletParams,
  SendParams,
  SendResult,
  GetAddressParams,
  GetBalanceParams,
  TxRecord,
} from './types';

// Re-export types
export * from './types';

/**
 * Internal helper: call the native engine with typed params and result.
 */
async function engineCall<T>(method: string, params?: Record<string, unknown>): Promise<T> {
  const jsonArgs = JSON.stringify(params ?? {});
  const jsonResult = await NativeWDKEngine.call(method, jsonArgs);
  return JSON.parse(jsonResult) as T;
}

let initialized = false;

/**
 * WDKWallet — The main API for interacting with the wallet engine.
 *
 * All methods are async because they cross the JS → Native → QuickJS bridge.
 * The native engine runs on a background thread — UI is never blocked.
 */
export const WDKWallet = {
  /**
   * Initialize the WDK engine. Must be called once at app startup.
   * Loads the QuickJS engine and the JS bundle.
   */
  async initialize(): Promise<void> {
    if (initialized) return;
    await NativeWDKEngine.initialize();
    initialized = true;
  },

  /**
   * Create a new wallet. Returns a mnemonic phrase.
   * Does NOT unlock the wallet — call unlockWallet() with the mnemonic.
   */
  async createWallet(params?: CreateWalletParams): Promise<CreateWalletResult> {
    await WDKWallet.initialize();
    return engineCall<CreateWalletResult>('createWallet', params);
  },

  /**
   * Unlock a wallet with a mnemonic phrase.
   * Derives the seed and master key. After this, chain operations are available.
   */
  async unlockWallet(params: UnlockWalletParams): Promise<void> {
    await WDKWallet.initialize();
    await engineCall<void>('unlockWallet', params);
  },

  /**
   * Lock the wallet. Releases all key handles from memory.
   * The wallet can be unlocked again with the mnemonic.
   */
  async lockWallet(): Promise<void> {
    await engineCall<void>('lockWallet');
  },

  /**
   * Destroy the wallet engine. Cannot be reused after this.
   */
  async destroyWallet(): Promise<void> {
    await NativeWDKEngine.destroy();
    initialized = false;
  },

  /**
   * Get the current wallet state.
   */
  async getState(): Promise<WalletState> {
    const state = await NativeWDKEngine.getState();
    return state as WalletState;
  },

  /**
   * Get a wallet address for a specific chain.
   * Requires the wallet to be unlocked and the chain module registered.
   */
  async getAddress(params: GetAddressParams): Promise<string> {
    return engineCall<string>('getAddress', params);
  },

  /**
   * Get the balance for an address on a specific chain.
   */
  async getBalance(params: GetBalanceParams): Promise<string> {
    return engineCall<string>('getBalance', params);
  },

  /**
   * Send a transaction.
   * Builds, signs, and broadcasts in one call.
   */
  async send(params: SendParams): Promise<SendResult> {
    return engineCall<SendResult>('send', params);
  },

  /**
   * Get transaction history for an address.
   */
  async getHistory(params: { chain: ChainId; address: string; limit?: number }): Promise<TxRecord[]> {
    return engineCall<TxRecord[]>('getHistory', params);
  },
};

/**
 * React hook: get the current wallet state.
 * Polls every 500ms. For production, replace with event-based updates.
 */
export function useWalletState(): WalletState {
  // Lazy import React to avoid issues in non-React contexts
  const { useState, useEffect } = require('react');
  const [state, setState] = useState<WalletState>('locked');

  useEffect(() => {
    let mounted = true;

    const poll = async () => {
      try {
        const s = await WDKWallet.getState();
        if (mounted) setState(s);
      } catch {
        // Engine not initialized yet
      }
    };

    poll();
    const interval = setInterval(poll, 500);
    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, []);

  return state;
}

// Default export for convenience
export default WDKWallet;
