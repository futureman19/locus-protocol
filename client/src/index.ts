/**
 * Locus Protocol JavaScript Client
 * 
 * A TypeScript/JavaScript client for interacting with the Locus Protocol
 * on the Bitcoin SV blockchain.
 * 
 * @example
 * ```typescript
 * import { LocusClient, WalletProvider } from '@locusprotocol/client';
 * 
 * const client = new LocusClient({
 *   network: 'testnet',
 *   walletProvider: WalletProvider.YOURS
 * });
 * 
 * // Register a ghost
 * const ghost = await client.registerGhost({
 *   name: 'My Oracle',
 *   type: GhostType.ORACLE,
 *   lat: 40.7128,
 *   lng: -74.0060,
 *   stakeAmount: 10000000
 * });
 * ```
 */

export { LocusClient } from './client';
export { TransactionBuilder } from './transaction-builder';
export { GhostRegistry } from './registry';
export { ARCBroadcaster } from './broadcaster';

// Types
export * from './types';

// Constants
export { 
  PROTOCOL_PREFIX,
  PROTOCOL_VERSION,
  GHOST_TYPES,
  CHALLENGE_TYPES,
  MIN_STAKE_AMOUNTS,
  LOCK_PERIOD_BLOCKS,
  HEARTBEAT_INTERVALS,
  CHALLENGE_WINDOW,
  CHALLENGER_STAKE,
  FEE_DISTRIBUTION
} from './constants';
