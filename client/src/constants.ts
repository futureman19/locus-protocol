/**
 * Protocol constants
 */

// Protocol identification
export const PROTOCOL_PREFIX = 'locus';
export const PROTOCOL_PREFIX_HEX = '0x6c6f637573';
export const PROTOCOL_VERSION = '\x00\x01'; // v0.1.0

// Transaction type codes
export enum TransactionType {
  GHOST_REGISTER = 0x01,
  GHOST_UPDATE = 0x02,
  GHOST_RETIRE = 0x03,
  HEARTBEAT = 0x04,
  INVOCATION = 0x05,
  CHALLENGE = 0x06,
  CHALLENGE_RESPONSE = 0x07,
  STAKE = 0x08,
  UNSTAKE = 0x09
}

// Ghost types
export enum GhostType {
  GREETER = 1,
  ORACLE = 2,
  GUARDIAN = 3,
  MERCHANT = 4,
  CUSTOM = 5
}

export const GHOST_TYPES = {
  GREETER: 'greeter' as const,
  ORACLE: 'oracle' as const,
  GUARDIAN: 'guardian' as const,
  MERCHANT: 'merchant' as const,
  CUSTOM: 'custom' as const
};

// Challenge types
export enum ChallengeType {
  NO_SHOW = 1,
  FRAUD = 2,
  MALFUNCTION = 3,
  TIMEOUT = 4
}

export const CHALLENGE_TYPES = {
  NO_SHOW: 'no_show' as const,
  FRAUD: 'fraud' as const,
  MALFUNCTION: 'malfunction' as const,
  TIMEOUT: 'timeout' as const
};

// Staking tiers (in satoshis)
export const MIN_STAKE_AMOUNTS = {
  [GhostType.GREETER]: 1_000_000,    // 0.01 BSV
  [GhostType.ORACLE]: 10_000_000,    // 0.1 BSV
  [GhostType.GUARDIAN]: 50_000_000,  // 0.5 BSV
  [GhostType.MERCHANT]: 10_000_000,  // 0.1 BSV
  [GhostType.CUSTOM]: 100_000_000    // 1 BSV
};

// Lock period: 5 months ≈ 21,600 blocks
export const LOCK_PERIOD_BLOCKS = 21_600;

// Heartbeat requirements (in seconds)
export const HEARTBEAT_INTERVALS = {
  MIN: 86_400,      // 24 hours
  MAX: 172_800,     // 48 hours
  GRACE: 86_400     // 24 hours grace period
};

// Challenge window: 72 hours
export const CHALLENGE_WINDOW = 259_200;

// Challenger stake (in satoshis)
export const CHALLENGER_STAKE = 10_000;

// Fee distribution (percentages)
export const FEE_DISTRIBUTION = {
  DEVELOPER: 0.70,   // 70%
  EXECUTOR: 0.20,    // 20%
  PROTOCOL: 0.10     // 10%
};

// ARC endpoints
export const ARC_ENDPOINTS = {
  MAINNET: 'https://arc.taal.com',
  TESTNET: 'https://arc.gorillapool.io',
  STN: 'https://arc.stn.gorillapool.io'
};

// Dust limit (in satoshis)
export const DUST_LIMIT = 546;

// Default transaction fee (satoshis per byte)
export const DEFAULT_FEE_RATE = 0.5;
