/**
 * CityManager — city founding, citizen management, phase tracking.
 *
 * Per spec 02-city-lifecycle.md:
 * - Cities are the core /32 primitive
 * - 6 phases driven by citizen count
 * - 32 BSV founding stake with 21,600-block CLTV lock
 */

import {
  City,
  CityPhase,
  GovernanceType,
  CityFoundParams,
  TokenDistribution,
} from '../types';
import { TransactionBuilder } from './transaction-builder';
import { phaseForCitizens, blocksForCitizens, governanceForPhase } from '../utils/fibonacci';
import { calculateLockHeight } from '../utils/stakes';
import { TERRITORY_STAKES, TOKEN_DISTRIBUTION, LOCK_PERIOD_BLOCKS } from '../constants/stakes';

export class CityManager {
  /**
   * Build a CITY_FOUND transaction script.
   * Requires 32 BSV stake.
   */
  static buildFoundTransaction(params: CityFoundParams): Buffer {
    return TransactionBuilder.buildCityFound(params);
  }

  /** Build a CITIZEN_JOIN transaction script. */
  static buildJoinTransaction(cityId: string, citizenPubkey: string): Buffer {
    return TransactionBuilder.buildCitizenJoin(cityId, citizenPubkey);
  }

  /** Build a CITIZEN_LEAVE transaction script. */
  static buildLeaveTransaction(cityId: string, citizenPubkey: string): Buffer {
    return TransactionBuilder.encode('citizen_leave', {
      city_id: cityId,
      citizen_pubkey: citizenPubkey,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  /** Returns the current phase for a city based on citizen count. */
  static getPhase(citizenCount: number): CityPhase | 'none' {
    return phaseForCitizens(citizenCount);
  }

  /** Returns the governance type for the current phase. */
  static getGovernanceType(phase: CityPhase): GovernanceType {
    return governanceForPhase(phase);
  }

  /** Returns the number of /16 blocks unlocked for the citizen count. */
  static getUnlockedBlocks(citizenCount: number): number {
    return blocksForCitizens(citizenCount);
  }

  /** Returns the founding stake in satoshis (32 BSV). */
  static getFoundingStake(): number {
    return TERRITORY_STAKES.CITY;
  }

  /** Returns the CLTV lock height for founding at a given block. */
  static getLockHeight(currentBlockHeight: number): number {
    return calculateLockHeight(currentBlockHeight);
  }

  /** Returns the token distribution for a new city. */
  static getTokenDistribution(): TokenDistribution {
    return {
      founder: TOKEN_DISTRIBUTION.FOUNDER,
      treasury: TOKEN_DISTRIBUTION.TREASURY,
      publicSale: TOKEN_DISTRIBUTION.PUBLIC_SALE,
      protocolDev: TOKEN_DISTRIBUTION.PROTOCOL_DEV,
      total: TOKEN_DISTRIBUTION.TOTAL_SUPPLY,
    };
  }

  /**
   * Calculate how many founder tokens are vested at a given month.
   * Linear vest: 1/12 per month over 12 months.
   */
  static founderVestedTokens(monthsElapsed: number): number {
    if (monthsElapsed <= 0) return 0;
    if (monthsElapsed >= TOKEN_DISTRIBUTION.FOUNDER_VEST_MONTHS) {
      return TOKEN_DISTRIBUTION.FOUNDER;
    }
    return Math.floor(TOKEN_DISTRIBUTION.FOUNDER * monthsElapsed / TOKEN_DISTRIBUTION.FOUNDER_VEST_MONTHS);
  }

  /** Checks if UBI is active for the given phase. Requires Phase 4 (:city, 21+ citizens). */
  static isUBIActive(phase: CityPhase): boolean {
    const ubiPhases: CityPhase[] = ['city', 'metropolis'];
    return ubiPhases.includes(phase);
  }

  /** Returns the lock period in blocks. */
  static getLockPeriod(): number {
    return LOCK_PERIOD_BLOCKS;
  }
}
