/**
 * Type definitions for Locus Protocol
 */

import { GhostType, ChallengeType, TransactionType } from './constants';

// ============================================================================
// Core Types
// ============================================================================

export type Network = 'mainnet' | 'testnet' | 'stn';

export type GhostState = 'pending' | 'active' | 'inactive' | 'slashed' | 'retired';

export type WalletProvider = 'yours' | 'relayx' | 'handcash' | 'twetch';

// ============================================================================
// Geographic Types
// ============================================================================

export interface LatLng {
  lat: number;  // Latitude in degrees (-90 to 90)
  lng: number;  // Longitude in degrees (-180 to 180)
}

export interface H3Index {
  index: string;  // H3 hex index
  resolution: number;
}

export interface GeoLocation extends LatLng {
  h3Index: string;
}

// ============================================================================
// Ghost Types
// ============================================================================

export interface Ghost {
  id: string;                    // Derived from stake tx
  name: string;
  type: GhostType;
  location: GeoLocation;
  stakeAmount: number;           // In satoshis
  lockHeight: number;            // Block height when unlockable
  ownerPubKey: string;           // Hex-encoded public key
  codeHash?: string;             // SHA-256 of ghost code (optional)
  codeUri?: string;              // UHRP URI for code (optional)
  baseFee: number;               // Minimum invocation fee (sats)
  timeout: number;               // Response timeout (seconds)
  meta?: Record<string, unknown>;
  
  // State
  state: GhostState;
  heartbeatSeq: number;
  lastHeartbeat?: Date;
  createdAt: Date;
}

export interface GhostRegistrationParams {
  name: string;
  type: GhostType | keyof typeof GhostType;
  lat: number;
  lng: number;
  stakeAmount: number;
  codeHash?: string;
  codeUri?: string;
  baseFee?: number;
  timeout?: number;
  meta?: Record<string, unknown>;
}

export interface GhostUpdateParams {
  name?: string;
  baseFee?: number;
  timeout?: number;
  meta?: Record<string, unknown>;
}

// ============================================================================
// Staking Types
// ============================================================================

export interface StakeInfo {
  txid: string;
  vout: number;
  amount: number;
  lockHeight: number;
  redeemScript: string;
  p2shAddress: string;
}

export interface SlashCondition {
  type: 'no_show' | 'fraud' | 'malfunction' | 'timeout';
  percentage: number;  // 0.1 = 10%, 0.5 = 50%, etc.
}

// ============================================================================
// Heartbeat Types
// ============================================================================

export interface HeartbeatParams {
  ghostId: string;
  sequence: number;
  location: GeoLocation;
  timestamp?: number;
}

export interface HeartbeatInfo {
  ghostId: string;
  sequence: number;
  h3Index: string;
  lat: number;  // Microdegrees
  lng: number;  // Microdegrees
  timestamp: number;
}

// ============================================================================
// Invocation Types
// ============================================================================

export interface InvocationParams {
  ghostId: string;
  params: Record<string, unknown>;
  nonce?: string;
  timestamp?: number;
}

export interface InvocationRequest {
  ghostId: string;
  params: Record<string, unknown>;
  feeAmount: number;
  invokerPubKey: string;
}

export interface InvocationResult {
  invocationId: string;
  ghostId: string;
  result: unknown;
  signature?: string;
  timestamp: number;
}

export interface FeeDistribution {
  developer: number;
  executor: number;
  protocol: number;
}

// ============================================================================
// Challenge Types
// ============================================================================

export interface ChallengeParams {
  ghostId: string;
  type: ChallengeType | keyof typeof ChallengeType;
  evidence: string;  // Description or hash of evidence
  timestamp?: number;
}

export interface Challenge {
  id: string;
  ghostId: string;
  type: ChallengeType;
  evidence: string;
  challenger: string;  // Public key
  stakeAmount: number;
  createdAt: Date;
  status: 'pending' | 'responded' | 'upheld' | 'rejected';
  response?: ChallengeResponse;
  respondedAt?: Date;
}

export interface ChallengeResponse {
  challengeId: string;
  evidence: string;
  signature: string;
  timestamp: number;
}

// ============================================================================
// Transaction Types
// ============================================================================

export interface UTXO {
  txid: string;
  vout: number;
  satoshis: number;
  script: string;
}

export interface LocusTransaction {
  protocol: string;
  version: string;
  type: TransactionType;
  data: unknown;
}

export interface RawTransaction {
  txid?: string;
  hex: string;
}

// ============================================================================
// Client Configuration
// ============================================================================

export interface LocusClientConfig {
  network?: Network;
  arcEndpoint?: string;
  arcApiKey?: string;
  walletProvider?: WalletProvider;
}

// ============================================================================
// ARC Types
// ============================================================================

export interface ARCConfig {
  endpoint: string;
  apiKey?: string;
}

export interface ARCBroadcastResult {
  txid: string;
  txStatus: string;
  blockHash?: string;
  blockHeight?: number;
}

// ============================================================================
// Wallet Types
// ============================================================================

export interface WalletInterface {
  getPublicKey(): Promise<string>;
  getAddress(): Promise<string>;
  signTransaction(tx: unknown): Promise<unknown>;
  getBalance(): Promise<number>;
  getUTXOs(): Promise<UTXO[]>;
}

// ============================================================================
// Protocol Payloads (MessagePack encoded)
// ============================================================================

export interface GhostRegisterPayload {
  name: string;
  type: number;
  lat: number;        // Microdegrees
  lng: number;        // Microdegrees
  h3: string;         // H3 index
  stake_amt: number;
  lock_blocks: number;
  unlock_h: number;   // Unlock block height
  owner_pk: string;   // Hex public key
  code_hash?: string;
  code_uri?: string;
  base_fee: number;
  timeout: number;
  meta?: Record<string, unknown>;
}

export interface HeartbeatPayload {
  ghost_id: string;
  seq: number;
  h3: string;
  lat: number;        // Microdegrees
  lng: number;        // Microdegrees
  ts: number;         // Unix timestamp
}

export interface InvocationPayload {
  ghost_id: string;
  params: Record<string, unknown>;
  nonce: string;
  ts: number;
}

export interface ChallengePayload {
  ghost_id: string;
  type: number;
  evidence: string;
  challenger: string;  // Hex public key
  ts: number;
}
