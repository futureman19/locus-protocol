import { TerritoryLevel, ObjectType } from '../types';
import {
  TERRITORY_STAKES,
  OBJECT_STAKES,
  LOCK_PERIOD_BLOCKS,
  EMERGENCY_PENALTY_RATE,
} from '../constants/stakes';

/** Returns the stake amount in satoshis for a territory level. */
export function stakeForLevel(level: TerritoryLevel): number {
  switch (level) {
    case 32: return TERRITORY_STAKES.CITY;
    case 16: return TERRITORY_STAKES.BLOCK_PRIVATE;
    case 8:  return TERRITORY_STAKES.BUILDING;
    case 4:  return TERRITORY_STAKES.HOME;
    default: return 0;
  }
}

/** Returns the minimum stake for an object type. */
export function stakeForObjectType(objectType: ObjectType): number {
  switch (objectType) {
    case 'item':      return OBJECT_STAKES.ITEM;
    case 'waypoint':  return OBJECT_STAKES.WAYPOINT_MIN;
    case 'agent':     return OBJECT_STAKES.AGENT_MIN;
    case 'billboard': return OBJECT_STAKES.BILLBOARD_MIN;
    case 'rare':      return OBJECT_STAKES.RARE;
    case 'epic':      return OBJECT_STAKES.EPIC;
    case 'legendary': return OBJECT_STAKES.LEGENDARY;
  }
}

/** Calculates the lock height given the current block height. */
export function calculateLockHeight(currentHeight: number): number {
  return currentHeight + LOCK_PERIOD_BLOCKS;
}

/** Calculates the 10% emergency penalty amount. */
export function calculatePenalty(stakeAmount: number): number {
  return Math.floor(stakeAmount * EMERGENCY_PENALTY_RATE);
}

/** Calculates the 90% returned on emergency unlock. */
export function calculateEmergencyReturn(stakeAmount: number): number {
  return stakeAmount - calculatePenalty(stakeAmount);
}

/**
 * Progressive property tax: cost = base * 2^(n-1)
 * Per spec 03-staking-economics.md.
 * 
 * SECURITY FIX: Use integer bit shift instead of Math.pow to avoid
 * floating point precision errors.
 */
export function progressiveTax(baseCost: number, propertyNumber: number): number {
  // SECURITY FIX: Use bit shift for exact integer math
  // Math.pow(2, n-1) can introduce floating point errors
  // 1 << (n-1) is exact for reasonable property numbers
  const multiplier = 1 << (propertyNumber - 1);
  return baseCost * multiplier;
}
