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

import { NativeEventEmitter } from 'react-native';
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
  // void-returning JS functions: C engine now returns "null" for undefined results.
  // Also handle edge cases where the native bridge returns undefined/null directly.
  if (jsonResult === undefined || jsonResult === null || jsonResult === 'undefined') {
    return undefined as T;
  }
  const parsed = JSON.parse(jsonResult);
  return parsed as T;
}

let initialized = false;
let initPromise: Promise<void> | null = null;

/**
 * Ensure the engine is initialized. If already done, returns immediately
 * (no async overhead). If initialization is in progress, awaits the same
 * Promise to avoid race conditions from concurrent calls.
 */
async function ensureInitialized(): Promise<void> {
  if (initialized) return;
  if (initPromise) {
    await initPromise;
    return;
  }
  initPromise = NativeWDKEngine.initialize().then(() => {
    initialized = true;
    initPromise = null;
  });
  await initPromise;
}

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
    await ensureInitialized();
  },

  /**
   * Configure engine settings — call before unlockWallet().
   * Use to switch a chain to testnet before the first unlock.
   *
   * @example
   *   await WDKWallet.configure({ isTestnet: true });          // BTC testnet
   *   await WDKWallet.configure({ chain: 'btc', isTestnet: true });
   */
  async configure(params: {
    isTestnet?: boolean;
    chain?: string;
    network?: string;
    btcClient?: { type: string; url?: string };
  }): Promise<void> {
    await ensureInitialized();
    await engineCall<void>('configure', params);
  },

  /**
   * Create a new wallet. Returns a mnemonic phrase.
   * Does NOT unlock the wallet — call unlockWallet() with the mnemonic.
   */
  async createWallet(params?: CreateWalletParams): Promise<CreateWalletResult> {
    await ensureInitialized();
    return engineCall<CreateWalletResult>('createWallet', params);
  },

  /**
   * Unlock a wallet with a mnemonic phrase.
   * Derives the seed and master key. After this, chain operations are available.
   */
  async unlockWallet(params: UnlockWalletParams): Promise<void> {
    await ensureInitialized();
    await engineCall<void>('unlockWallet', params);
  },

  /**
   * Lock the wallet. Releases all key handles from memory.
   * The wallet can be unlocked again with the mnemonic.
   */
  async lockWallet(): Promise<void> {
    await ensureInitialized();
    await engineCall<void>('lockWallet');
  },

  /**
   * Destroy the wallet engine. Cannot be reused after this.
   */
  async destroyWallet(): Promise<void> {
    await NativeWDKEngine.destroy();
    initialized = false;
    initPromise = null;
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
    await ensureInitialized();
    return engineCall<string>('getAddress', params);
  },

  /**
   * Get the balance for an address on a specific chain.
   */
  async getBalance(params: GetBalanceParams): Promise<string> {
    await ensureInitialized();
    return engineCall<string>('getBalance', params);
  },

  /**
   * Send a transaction.
   * Builds, signs, and broadcasts in one call.
   */
  async send(params: SendParams): Promise<SendResult> {
    await ensureInitialized();
    return engineCall<SendResult>('send', params);
  },

  /**
   * Get transaction history for an address.
   */
  async getHistory(params: { chain: ChainId; address: string; limit?: number }): Promise<TxRecord[]> {
    await ensureInitialized();
    return engineCall<TxRecord[]>('getHistory', params);
  },

  /**
   * Preview a send transaction — estimate fees without signing/broadcasting.
   */
  async quoteSend(params: {
    chain: ChainId;
    from?: string;
    address?: string;
    to: string;
    amount: string;
  }): Promise<{
    feasible: boolean;
    fee: number;
    feeRate: number;
    inputCount: number;
    outputCount: number;
    change: number;
    error?: string;
  }> {
    await ensureInitialized();
    return engineCall('quoteSend', params);
  },

  /**
   * Get the maximum spendable amount for an address.
   */
  async getMaxSpendable(params: {
    chain: ChainId;
    address: string;
  }): Promise<{
    maxSpendable: number;
    fee: number;
    utxoCount: number;
  }> {
    await ensureInitialized();
    return engineCall('getMaxSpendable', params);
  },

  /**
   * Get transaction confirmation status.
   */
  async getReceipt(params: {
    chain: ChainId;
    txHash: string;
  }): Promise<{
    txHash: string;
    confirmed: boolean;
    blockHeight: number;
    blockTime: number;
    fee: number;
  }> {
    await ensureInitialized();
    return engineCall('getReceipt', params);
  },

  /**
   * Get current fee rates in sat/vB.
   */
  async getFeeRates(params: {
    chain: ChainId;
  }): Promise<{
    fast: number;
    medium: number;
    slow: number;
    normal: number;    // production alias for 'medium'
  }> {
    await ensureInitialized();
    return engineCall('getFeeRates', params);
  },

  /**
   * Get paginated transfer history with direction filter.
   */
  async getTransfers(params: {
    chain: ChainId;
    address: string;
    direction?: 'sent' | 'received' | 'all';
    limit?: number;
    afterTxId?: string;
    page?: number;
  }): Promise<{
    transfers: Array<{
      txHash: string;
      direction: 'sent' | 'received' | 'self';
      amount: number;
      fee: number;
      timestamp: number;
      blockHeight: number;
      confirmed: boolean;
      counterparties: string[];
    }>;
    hasMore: boolean;
    nextCursor?: string;
  }> {
    await ensureInitialized();
    return engineCall('getTransfers', params);
  },

  /**
   * Sign a message using Bitcoin Signed Message format.
   * Returns base64-encoded 65-byte signature.
   */
  async signMessage(params: {
    chain: ChainId;
    message: string;
    index?: number;
  }): Promise<string> {
    await ensureInitialized();
    return engineCall('signMessage', params);
  },

  /**
   * Verify a Bitcoin Signed Message against an address.
   */
  async verifyMessage(params: {
    chain: ChainId;
    message: string;
    signature: string;
    address: string;
  }): Promise<boolean> {
    await ensureInitialized();
    return engineCall('verifyMessage', params);
  },
};

// Singleton emitter — NativeEventEmitter requires the native module reference
// and must not be re-created on every render.
const wdkEmitter = new NativeEventEmitter(NativeWDKEngine as any);

/**
 * React hook: get the current wallet state.
 *
 * Subscribes to the native "wdkStateChange" event emitted by WDKEngineModule
 * (an RCTEventEmitter) whenever a state-mutating call completes.  Seeds the
 * initial value with a one-time getState() call so the UI is correct on mount.
 *
 * No polling — zero overhead when the state is not changing.
 */
export function useWalletState(): WalletState {
  // Lazy import React to avoid issues in non-React contexts
  const { useState, useEffect } = require('react');
  const [state, setState] = useState<WalletState>('locked');

  useEffect(() => {
    let mounted = true;

    // Seed with current state in case we mounted after a transition
    WDKWallet.getState()
      .then(s => { if (mounted) setState(s); })
      .catch(() => {}); // engine not yet initialized — stay 'locked'

    // Subscribe to native state-change events
    const sub = wdkEmitter.addListener(
      'wdkStateChange',
      (event: { state: string }) => {
        if (mounted) setState(event.state as WalletState);
      }
    );

    return () => {
      mounted = false;
      sub.remove();
    };
  }, []);

  return state;
}

// Default export for convenience
export default WDKWallet;
