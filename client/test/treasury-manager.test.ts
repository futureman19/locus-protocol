import { describe, it, expect } from 'vitest';
import { TreasuryManager } from '../src/modules/treasury-manager';

describe('TreasuryManager', () => {
  describe('calculateDailyUBI', () => {
    it('follows formula: (treasury * 0.001) / citizens', () => {
      // 1000 BSV treasury, 25 citizens
      const treasury = 100_000_000_000; // 1000 BSV in sats
      const daily = TreasuryManager.calculateDailyUBI(treasury, 25);
      expect(daily).toBe(4_000_000); // 0.04 BSV per citizen
    });

    it('returns 0 for 0 citizens', () => {
      expect(TreasuryManager.calculateDailyUBI(100_000_000_000, 0)).toBe(0);
    });
  });

  describe('calculateMonthlyCap', () => {
    it('caps at 1% of treasury', () => {
      const treasury = 100_000_000_000; // 1000 BSV
      expect(TreasuryManager.calculateMonthlyCap(treasury)).toBe(1_000_000_000); // 10 BSV
    });
  });

  describe('isUBIEligible', () => {
    it('requires city phase and min treasury', () => {
      // Below min treasury
      expect(TreasuryManager.isUBIEligible('city', 5_000_000_000)).toBe(false);

      // Wrong phase
      expect(TreasuryManager.isUBIEligible('town', 100_000_000_000)).toBe(false);

      // Both correct
      expect(TreasuryManager.isUBIEligible('city', 100_000_000_000)).toBe(true);
      expect(TreasuryManager.isUBIEligible('metropolis', 100_000_000_000)).toBe(true);
    });
  });

  describe('getUBIInfo', () => {
    it('returns complete UBI info when active', () => {
      const info = TreasuryManager.getUBIInfo('city', 100_000_000_000, 25);
      expect(info.isActive).toBe(true);
      expect(info.dailyPerCitizen).toBe(4_000_000);
      expect(info.citizenCount).toBe(25);
    });

    it('returns inactive UBI for early phases', () => {
      const info = TreasuryManager.getUBIInfo('village', 100_000_000_000, 5);
      expect(info.isActive).toBe(false);
      expect(info.dailyPerCitizen).toBe(0);
    });
  });

  describe('redemptionRate', () => {
    it('rate = treasury / total_supply', () => {
      const rate = TreasuryManager.redemptionRate(100_000_000_000, 3_200_000);
      expect(rate).toBeCloseTo(31250, 0); // 100B sats / 3.2M tokens
    });
  });

  describe('redeemTokens', () => {
    it('calculates BSV for token redemption', () => {
      const bsv = TreasuryManager.redeemTokens(1000, 100_000_000_000, 3_200_000);
      expect(bsv).toBe(31_250_000); // 1000 * (100B / 3.2M) = 31.25M sats
    });
  });

  describe('vestedFounderTokens', () => {
    it('matches city manager vesting', () => {
      expect(TreasuryManager.vestedFounderTokens(0)).toBe(0);
      expect(TreasuryManager.vestedFounderTokens(6)).toBe(320_000);
      expect(TreasuryManager.vestedFounderTokens(12)).toBe(640_000);
    });
  });
});
