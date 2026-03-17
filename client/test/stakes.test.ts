import { describe, it, expect } from 'vitest';
import {
  stakeForLevel,
  stakeForObjectType,
  calculateLockHeight,
  calculatePenalty,
  calculateEmergencyReturn,
  progressiveTax,
} from '../src/utils/stakes';

describe('Stakes', () => {
  describe('stakeForLevel', () => {
    it('/32 city = 32 BSV', () => {
      expect(stakeForLevel(32)).toBe(3_200_000_000);
    });

    it('/16 block = 8 BSV', () => {
      expect(stakeForLevel(16)).toBe(800_000_000);
    });

    it('/8 building = 8 BSV', () => {
      expect(stakeForLevel(8)).toBe(800_000_000);
    });

    it('/4 home = 4 BSV', () => {
      expect(stakeForLevel(4)).toBe(400_000_000);
    });
  });

  describe('stakeForObjectType', () => {
    it('item = 0.0001 BSV', () => {
      expect(stakeForObjectType('item')).toBe(10_000);
    });

    it('agent = 0.1 BSV min', () => {
      expect(stakeForObjectType('agent')).toBe(10_000_000);
    });

    it('rare = 16 BSV', () => {
      expect(stakeForObjectType('rare')).toBe(1_600_000_000);
    });

    it('epic = 32 BSV', () => {
      expect(stakeForObjectType('epic')).toBe(3_200_000_000);
    });

    it('legendary = 64 BSV', () => {
      expect(stakeForObjectType('legendary')).toBe(6_400_000_000);
    });
  });

  describe('calculateLockHeight', () => {
    it('adds 21,600 blocks', () => {
      expect(calculateLockHeight(800_000)).toBe(821_600);
    });
  });

  describe('calculatePenalty', () => {
    it('10% penalty per spec (NOT 50%)', () => {
      const stake = 3_200_000_000; // 32 BSV
      expect(calculatePenalty(stake)).toBe(320_000_000); // 3.2 BSV
    });
  });

  describe('calculateEmergencyReturn', () => {
    it('returns 90% of stake', () => {
      const stake = 3_200_000_000;
      expect(calculateEmergencyReturn(stake)).toBe(2_880_000_000); // 28.8 BSV
    });

    it('penalty + return == original stake', () => {
      const stake = 3_200_000_000;
      const penalty = calculatePenalty(stake);
      const returned = calculateEmergencyReturn(stake);
      expect(penalty + returned).toBe(stake);
    });
  });

  describe('progressiveTax', () => {
    it('progressive doubling per spec: cost = base * 2^(n-1)', () => {
      const base = 800_000_000; // 8 BSV for building

      expect(progressiveTax(base, 1)).toBe(800_000_000);
      expect(progressiveTax(base, 2)).toBe(1_600_000_000);
      expect(progressiveTax(base, 3)).toBe(3_200_000_000);
      expect(progressiveTax(base, 4)).toBe(6_400_000_000);
    });

    it('city founding progressive tax', () => {
      const base = 3_200_000_000; // 32 BSV for city

      expect(progressiveTax(base, 1)).toBe(3_200_000_000);   // 32 BSV
      expect(progressiveTax(base, 2)).toBe(6_400_000_000);   // 64 BSV
      expect(progressiveTax(base, 3)).toBe(12_800_000_000);  // 128 BSV
      expect(progressiveTax(base, 5)).toBe(51_200_000_000);  // 512 BSV
    });
  });
});
