/**
 * WDK v2 React Native — Type Definitions
 *
 * Authoritative RN API contract. All object shapes used by WDKWallet
 * methods in index.ts are defined here.
 */

// ── Core types ───────────────────────────────────────────────────────────────

/** Wallet lifecycle state */
export type WalletState = 'created' | 'unlocked' | 'ready' | 'locked' | 'destroyed';

/** Supported chain identifiers */
export type ChainId = 'btc' | 'evm' | 'ton' | 'tron' | 'solana' | 'spark';

/** BTC address type — determines derivation path and script format */
export type BtcAddressType = 'p2wpkh' | 'p2pkh';

// ── Wallet lifecycle ─────────────────────────────────────────────────────────

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

/** Parameters for engine configuration */
export interface ConfigureParams {
  isTestnet?: boolean;
  chain?: string;
  network?: string;
  btcClient?: { type: string; url?: string };
}

// ── Address ──────────────────────────────────────────────────────────────────

/** Parameters for getting an address */
export interface GetAddressParams {
  chain: ChainId;
  index?: number;
  addressType?: BtcAddressType;
}

// ── Balance ──────────────────────────────────────────────────────────────────

/** Parameters for getting a balance */
export interface GetBalanceParams {
  chain: ChainId;
  /** Optional — if omitted, uses account at `index` */
  address?: string;
  index?: number;
  addressType?: BtcAddressType;
}

// ── Send ─────────────────────────────────────────────────────────────────────

/** Parameters for sending a transaction */
export interface SendParams {
  chain: ChainId;
  to: string;
  amount: string;
  index?: number;
  addressType?: BtcAddressType;
  feeRate?: number;
  /** EVM/token-specific (future) */
  token?: string;
  memo?: string;
}

/** Result from sending a transaction */
export interface SendResult {
  txHash: string;
  fee: number;
}

// ── Quote send ───────────────────────────────────────────────────────────────

/** Parameters for previewing a send (fee estimation) */
export interface QuoteSendParams {
  chain: ChainId;
  to: string;
  amount: string;
  /** Optional — if omitted, uses account at index 0 */
  address?: string;
  index?: number;
}

/** Result from quoteSend — fee estimate without signing */
export interface QuoteSendResult {
  feasible: boolean;
  fee: number;
  feeRate: number;
  inputCount: number;
  outputCount: number;
  totalInput: number;
  change: number;
  changeValue: number;
  error?: string;
}

// ── Max spendable ────────────────────────────────────────────────────────────

/** Parameters for getting max spendable amount */
export interface GetMaxSpendableParams {
  chain: ChainId;
  /** Optional — if omitted, uses account at index 0 */
  address?: string;
  index?: number;
}

/** Result from getMaxSpendable */
export interface MaxSpendableResult {
  maxSpendable: number;
  amount: number;
  fee: number;
  changeValue: number;
  utxoCount: number;
}

// ── Fee rates ────────────────────────────────────────────────────────────────

/** Parameters for getting fee rates */
export interface GetFeeRatesParams {
  chain: ChainId;
}

/** Fee rate estimates in sat/vB */
export interface FeeRatesResult {
  fast: number;
  medium: number;
  slow: number;
  /** Production alias for 'medium' */
  normal: number;
}

// ── Transaction receipt ──────────────────────────────────────────────────────

/** Parameters for getting a transaction receipt */
export interface GetReceiptParams {
  chain: ChainId;
  txHash: string;
}

/** Transaction receipt — null for unconfirmed transactions (matching production) */
export interface ReceiptResult {
  txHash: string;
  confirmed: boolean;
  confirmations: number;
  blockHeight: number;
  blockTime: number;
  fee: number;
  rawTx?: string;
}

// ── Transaction history ──────────────────────────────────────────────────────

/** Transaction history record */
export interface TxRecord {
  txHash: string;
  chain: ChainId;
  from: string;
  to: string;
  amount: string;
  fee: string;
  direction: 'sent' | 'received';
  counterparties: string[];
  timestamp: number;
  status: 'pending' | 'confirmed' | 'failed';
  blockNumber?: number;
}

// ── Transfers (per-output rows) ──────────────────────────────────────────────

/** Parameters for getting paginated transfer history */
export interface GetTransfersParams {
  chain: ChainId;
  /** Optional — if omitted, uses account at index 0 */
  address?: string;
  index?: number;
  direction?: 'incoming' | 'outgoing' | 'sent' | 'received' | 'all';
  limit?: number;
  skip?: number;
  afterTxId?: string;
  page?: number;
}

/** A single per-output transfer row (matches production BtcTransfer) */
export interface BtcTransferRow {
  txid: string;
  address: string;
  vout: number;
  height: number;
  value: number;
  direction: 'incoming' | 'outgoing';
  recipient?: string;
  fee?: number;
}

/** Paginated transfer result */
export interface TransferResult {
  transfers: BtcTransferRow[];
  hasMore: boolean;
  nextCursor?: string;
}

// ── Sign / Verify ────────────────────────────────────────────────────────────

/** Parameters for signing a message */
export interface SignMessageParams {
  chain: ChainId;
  message: string;
  index?: number;
  addressType?: BtcAddressType;
}

/** Parameters for verifying a signed message */
export interface VerifyMessageParams {
  chain: ChainId;
  message: string;
  signature: string;
  address: string;
}

// ── Account lifecycle ────────────────────────────────────────────────────────

/** Parameters for getting/creating an account */
export interface GetAccountParams {
  chain: ChainId;
  index?: number;
  addressType?: BtcAddressType;
}

/** Full account info (with signing capability) */
export interface AccountInfo {
  chainId: string;
  address: string;
  index: number;
  path: string;
  publicKey: string;
}

/** Parameters for getting an account by explicit derivation path */
export interface GetAccountByPathParams {
  chain: ChainId;
  path: string;
  index?: number;
  addressType?: BtcAddressType;
}

/** Parameters for downgrading to read-only account */
export interface ToReadOnlyAccountParams {
  chain: ChainId;
  index?: number;
  addressType?: BtcAddressType;
}

/** Read-only account info (no signing, no publicKey) */
export interface ReadOnlyAccountInfo {
  chainId: string;
  address: string;
  index: number;
  path: string;
}

/** Parameters for disposing an account */
export interface DisposeAccountParams {
  chain: ChainId;
  index?: number;
  addressType?: BtcAddressType;
}

// ── Events ───────────────────────────────────────────────────────────────────

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
