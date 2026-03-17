/**
 * @locusprotocol/client — Territory-centric JavaScript SDK for Locus Protocol on BSV
 *
 * Cities are the core primitive. Ghosts are just one type of /1 Object.
 *
 * @example
 * ```typescript
 * import { LocusClient, CityManager, TransactionBuilder } from '@locusprotocol/client';
 *
 * const client = new LocusClient({ network: 'testnet' });
 *
 * // Found a city (32 BSV stake)
 * const script = CityManager.buildFoundTransaction({
 *   name: 'Neo-Tokyo',
 *   lat: 35.6762,
 *   lng: 139.6503,
 *   h3Res7: '8f283080dcb019d',
 *   founderPubkey: '02abc...',
 * });
 *
 * // Get city phase by citizen count
 * const phase = CityManager.getPhase(25); // 'city'
 * ```
 */

// Main client
export { LocusClient } from './client';

// Managers
export { CityManager } from './modules/city-manager';
export { TerritoryManager } from './modules/territory-manager';
export { ObjectManager } from './modules/object-manager';
export { TreasuryManager } from './modules/treasury-manager';
export { GovernanceManager } from './modules/governance-manager';
export { HeartbeatManager } from './modules/heartbeat-manager';
export { TransactionBuilder } from './modules/transaction-builder';

// Broadcaster
export { ARCBroadcaster } from './broadcaster';

// Types
export * from './types';

// Constants
export {
  TERRITORY_STAKES,
  OBJECT_STAKES,
  TOKEN_DISTRIBUTION,
  LOCK_PERIOD_BLOCKS,
  EMERGENCY_PENALTY_RATE,
  FEE_DISTRIBUTION,
  TERRITORY_FEE_SPLIT,
  UBI,
  GOVERNANCE,
  PROPOSAL_THRESHOLDS,
  QUORUM_BY_PHASE,
  progressiveTax,
} from './constants/stakes';

export {
  PROTOCOL_PREFIX,
  PROTOCOL_VERSION,
  TYPE_CODES,
  REVERSE_CODES,
  PROPOSAL_TYPE_CODES,
  VOTE_CODES,
  DUST_LIMIT,
  DEFAULT_FEE_RATE,
} from './constants/opcodes';

export { ARC_ENDPOINTS, getARCConfig } from './constants/networks';

// Utils
export {
  sequence as fibonacciSequence,
  sumUpTo as fibonacciSum,
  blocksForCitizens,
  phaseForCitizens,
  governanceForPhase,
  phaseNumber,
} from './utils/fibonacci';

export {
  stakeForLevel,
  stakeForObjectType,
  calculateLockHeight,
  calculatePenalty,
  calculateEmergencyReturn,
  progressiveTax as calculateProgressiveTax,
} from './utils/stakes';

export { h3ResolutionForLevel, isValidH3Index } from './utils/h3';
export { buildLockConfig, isLockExpired, emergencyUnlockOutputs } from './utils/cltv';
