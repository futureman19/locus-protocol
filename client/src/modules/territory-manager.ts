/**
 * TerritoryManager — claim, release, transfer territories at any level.
 *
 * Per spec 01-territory-hierarchy.md:
 * /128 Continent → /64 Country → /32 City → /16 Block → /8 Building → /4 Home → /2 Aura → /1 Object
 */

import {
  TerritoryLevel,
  TerritoryClaimParams,
  FeeDistribution,
  TerritoryFeeBreakdown,
} from '../types';
import { TransactionBuilder } from './transaction-builder';
import { stakeForLevel, progressiveTax, calculateLockHeight } from '../utils/stakes';
import {
  FEE_DISTRIBUTION,
  TERRITORY_FEE_SPLIT,
} from '../constants/stakes';

export class TerritoryManager {
  /** Build a TERRITORY_CLAIM transaction script. */
  static buildClaimTransaction(params: TerritoryClaimParams): Buffer {
    return TransactionBuilder.buildTerritoryClaim(params);
  }

  /** Build a TERRITORY_RELEASE transaction script. */
  static buildReleaseTransaction(territoryId: string, ownerPubkey: string): Buffer {
    return TransactionBuilder.encode('territory_release', {
      territory_id: territoryId,
      owner_pubkey: ownerPubkey,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }

  /** Build a TERRITORY_TRANSFER transaction script. */
  static buildTransferTransaction(
    territoryId: string,
    fromPubkey: string,
    toPubkey: string,
    price = 0,
  ): Buffer {
    return TransactionBuilder.buildTerritoryTransfer(territoryId, fromPubkey, toPubkey, price);
  }

  /** Returns the base stake for a territory level. */
  static getStakeForLevel(level: TerritoryLevel): number {
    return stakeForLevel(level);
  }

  /** Returns the progressive tax for the Nth property at a given level. */
  static getProgressiveTax(level: TerritoryLevel, propertyNumber: number): number {
    const base = stakeForLevel(level);
    return progressiveTax(base, propertyNumber);
  }

  /** Calculate CLTV lock height for a territory claim. */
  static getLockHeight(currentBlockHeight: number): number {
    return calculateLockHeight(currentBlockHeight);
  }

  /**
   * Distributes a fee amount according to the protocol split.
   * Per spec 01-territory-hierarchy.md:
   *   50% developer, 40% territory, 10% protocol
   */
  static distributeFees(totalFee: number): FeeDistribution {
    return {
      developer: Math.floor(totalFee * FEE_DISTRIBUTION.DEVELOPER),
      territory: Math.floor(totalFee * FEE_DISTRIBUTION.TERRITORY),
      protocol: Math.floor(totalFee * FEE_DISTRIBUTION.PROTOCOL),
    };
  }

  /**
   * Breaks down the territory share (40%) among building, city, and block.
   * Per spec 01-territory-hierarchy.md:
   *   50% building owner, 30% city treasury, 20% block owner
   */
  static distributeTerritoryFees(territoryShare: number): TerritoryFeeBreakdown {
    return {
      building: Math.floor(territoryShare * TERRITORY_FEE_SPLIT.BUILDING),
      city: Math.floor(territoryShare * TERRITORY_FEE_SPLIT.CITY),
      block: Math.floor(territoryShare * TERRITORY_FEE_SPLIT.BLOCK),
    };
  }
}
