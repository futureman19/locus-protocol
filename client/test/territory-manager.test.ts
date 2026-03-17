import { describe, it, expect } from 'vitest';
import { TerritoryManager } from '../src/modules/territory-manager';

describe('TerritoryManager', () => {
  describe('getStakeForLevel', () => {
    it('returns correct stakes per spec', () => {
      expect(TerritoryManager.getStakeForLevel(32)).toBe(3_200_000_000); // 32 BSV
      expect(TerritoryManager.getStakeForLevel(16)).toBe(800_000_000);   // 8 BSV
      expect(TerritoryManager.getStakeForLevel(8)).toBe(800_000_000);    // 8 BSV
      expect(TerritoryManager.getStakeForLevel(4)).toBe(400_000_000);    // 4 BSV
    });
  });

  describe('getProgressiveTax', () => {
    it('doubles per additional property', () => {
      // Building at 8 BSV
      expect(TerritoryManager.getProgressiveTax(8, 1)).toBe(800_000_000);
      expect(TerritoryManager.getProgressiveTax(8, 2)).toBe(1_600_000_000);
      expect(TerritoryManager.getProgressiveTax(8, 3)).toBe(3_200_000_000);
    });

    it('city founding progressive tax', () => {
      expect(TerritoryManager.getProgressiveTax(32, 1)).toBe(3_200_000_000);
      expect(TerritoryManager.getProgressiveTax(32, 2)).toBe(6_400_000_000);
    });
  });

  describe('distributeFees', () => {
    it('splits 50/40/10 per spec', () => {
      const fees = TerritoryManager.distributeFees(10_000);
      expect(fees.developer).toBe(5_000);  // 50%
      expect(fees.territory).toBe(4_000);  // 40%
      expect(fees.protocol).toBe(1_000);   // 10%
    });
  });

  describe('distributeTerritoryFees', () => {
    it('splits territory share 50/30/20', () => {
      const breakdown = TerritoryManager.distributeTerritoryFees(4_000);
      expect(breakdown.building).toBe(2_000);  // 50% of territory
      expect(breakdown.city).toBe(1_200);       // 30% of territory
      expect(breakdown.block).toBe(800);        // 20% of territory
    });
  });

  describe('getLockHeight', () => {
    it('adds 21,600 blocks', () => {
      expect(TerritoryManager.getLockHeight(800_000)).toBe(821_600);
    });
  });

  describe('buildClaimTransaction', () => {
    it('produces a valid OP_RETURN script', () => {
      const script = TerritoryManager.buildClaimTransaction({
        level: 8,
        h3Index: '891f1d48177ffff',
        ownerPubkey: 'owner_key_hex',
        stakeAmount: 800_000_000,
        lockHeight: 821_600,
      });

      expect(Buffer.isBuffer(script)).toBe(true);
      expect(script[0]).toBe(0x6a);
    });
  });
});
