/**
 * WDK v2 React Native — Type Definitions
 */

/** Wallet lifecycle state */
export type WalletState = 'created' | 'unlocked' | 'ready' | 'locked' | 'destroyed';

/** Supported chain identifiers */
export type ChainId = 'btc' | 'evm' | 'ton' | 'tron' | 'solana' | 'spark';

/** Parameters for creating a wallet */
export interface CreateWalletParams {
  wordCount?: 12 | 24;
}

/** Result from creating a wallet */
export interface CreateWalletResult {
  mnemonic: string;
}

/** Parameters for unlocking a wallet */
export interface UnlockWalletParams {
  mnemonic: string;
  passphrase?: string;
}

/** Parameters for sending a transaction */
export interface SendParams {
  chain: ChainId;
  to: string;
  amount: string;
  token?: string;
  memo?: string;
}

/** Result from sending a transaction */
export interface SendResult {
  txHash: string;
}

/** Parameters for getting an address */
export interface GetAddressParams {
  chain: ChainId;
  account?: number;
  index?: number;
}

/** Parameters for getting a balance */
export interface GetBalanceParams {
  chain: ChainId;
  address: string;
  token?: string;
}

/** Transaction history record */
export interface TxRecord {
  txHash: string;
  chain: ChainId;
  from: string;
  to: string;
  amount: string;
  fee?: string;
  direction?: 'sent' | 'received' | 'self';
  token?: string;
  timestamp: number;
  status: 'pending' | 'confirmed' | 'failed';
  blockNumber?: number;
}

/** WDK event names */
export const WDKEvents = {
  WALLET_CREATED: 'wallet:created',
  WALLET_UNLOCKED: 'wallet:unlocked',
  WALLET_LOCKED: 'wallet:locked',
  WALLET_DESTROYED: 'wallet:destroyed',
  TX_SENT: 'tx:sent',
  TX_CONFIRMED: 'tx:confirmed',
  TX_FAILED: 'tx:failed',
  ERROR: 'error',
} as const;

export type WDKEventName = typeof WDKEvents[keyof typeof WDKEvents];
