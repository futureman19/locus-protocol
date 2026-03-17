/**
 * TreasuryManager — UBI calculations, token redemption, treasury accounting.
 *
 * Per spec 03-staking-economics.md:
 * - UBI activates at Phase 4 (:city, 21+ citizens)
 * - Formula: daily_ubi = (treasury_bsv * 0.001) / citizen_count
 * - Monthly cap: 1% of treasury
 * - Min treasury: 100 BSV (10,000,000,000 sats)
 */

import { CityPhase, UBIInfo } from '../types';
import { TransactionBuilder } from './transaction-builder';
import { UBI, TOKEN_DISTRIBUTION } from '../constants/stakes';

export class TreasuryManager {
  /**
   * Calculate daily UBI per citizen.
   * Formula: (treasury_sats * 0.001) / citizen_count
   */
  static calculateDailyUBI(treasurySats: number, citizenCount: number): number {
    if (citizenCount <= 0) return 0;
    return Math.floor((treasurySats * UBI.RATE) / citizenCount);
  }

  /**
   * Calculate monthly cap on UBI distribution.
   * Max 1% of treasury per month.
   */
  static calculateMonthlyCap(treasurySats: number): number {
    return Math.floor(treasurySats * UBI.MONTHLY_CAP_RATE);
  }

  /** Check if UBI can be distributed (phase + treasury minimums). */
  static isUBIEligible(phase: CityPhase, treasurySats: number): boolean {
    const eligiblePhases: CityPhase[] = ['city', 'metropolis'];
    return eligiblePhases.includes(phase) && treasurySats >= UBI.MIN_TREASURY_SATS;
  }

  /** Get full UBI info for a city. */
  static getUBIInfo(phase: CityPhase, treasurySats: number, citizenCount: number): UBIInfo {
    const isActive = TreasuryManager.isUBIEligible(phase, treasurySats);
    return {
      dailyPerCitizen: isActive ? TreasuryManager.calculateDailyUBI(treasurySats, citizenCount) : 0,
      monthlyCap: TreasuryManager.calculateMonthlyCap(treasurySats),
      treasuryBalance: treasurySats,
      citizenCount,
      isActive,
      minTreasury: UBI.MIN_TREASURY_SATS,
    };
  }

  /** Build a UBI_CLAIM transaction script. */
  static buildClaimTransaction(cityId: string, citizenPubkey: string, claimPeriods: number): Buffer {
    return TransactionBuilder.buildUBIClaim(cityId, citizenPubkey, claimPeriods);
  }

  /**
   * Calculate token redemption rate.
   * rate = treasury_sats / total_token_supply
   */
  static redemptionRate(treasurySats: number, totalSupply?: number): number {
    const supply = totalSupply ?? TOKEN_DISTRIBUTION.TOTAL_SUPPLY;
    if (supply <= 0) return 0;
    return treasurySats / supply;
  }

  /**
   * Calculate BSV received for redeeming tokens.
   * amount = tokens * (treasury_sats / total_supply)
   */
  static redeemTokens(tokens: number, treasurySats: number, totalSupply?: number): number {
    const rate = TreasuryManager.redemptionRate(treasurySats, totalSupply);
    return Math.floor(tokens * rate);
  }

  /**
   * Calculate vested founder tokens at a given month.
   * Linear: 1/12 per month.
   */
  static vestedFounderTokens(monthsElapsed: number): number {
    if (monthsElapsed <= 0) return 0;
    if (monthsElapsed >= TOKEN_DISTRIBUTION.FOUNDER_VEST_MONTHS) {
      return TOKEN_DISTRIBUTION.FOUNDER;
    }
    return Math.floor(TOKEN_DISTRIBUTION.FOUNDER * monthsElapsed / TOKEN_DISTRIBUTION.FOUNDER_VEST_MONTHS);
  }
}
