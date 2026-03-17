import { describe, it, expect } from 'vitest';
import { CityManager } from '../src/modules/city-manager';

describe('CityManager', () => {
  describe('getPhase', () => {
    it('returns correct phases for citizen counts', () => {
      expect(CityManager.getPhase(0)).toBe('none');
      expect(CityManager.getPhase(1)).toBe('genesis');
      expect(CityManager.getPhase(3)).toBe('settlement');
      expect(CityManager.getPhase(5)).toBe('village');
      expect(CityManager.getPhase(15)).toBe('town');
      expect(CityManager.getPhase(25)).toBe('city');
      expect(CityManager.getPhase(100)).toBe('metropolis');
    });
  });

  describe('getGovernanceType', () => {
    it('genesis = founder', () => {
      expect(CityManager.getGovernanceType('genesis')).toBe('founder');
    });

    it('city = direct_democracy', () => {
      expect(CityManager.getGovernanceType('city')).toBe('direct_democracy');
    });

    it('metropolis = senate', () => {
      expect(CityManager.getGovernanceType('metropolis')).toBe('senate');
    });
  });

  describe('getUnlockedBlocks', () => {
    it('matches spec 02 table', () => {
      expect(CityManager.getUnlockedBlocks(1)).toBe(2);
      expect(CityManager.getUnlockedBlocks(4)).toBe(5);
      expect(CityManager.getUnlockedBlocks(9)).toBe(8);
      expect(CityManager.getUnlockedBlocks(21)).toBe(16);
      expect(CityManager.getUnlockedBlocks(51)).toBe(24);
    });
  });

  describe('getFoundingStake', () => {
    it('returns 32 BSV (3,200,000,000 sats)', () => {
      expect(CityManager.getFoundingStake()).toBe(3_200_000_000);
    });
  });

  describe('getLockHeight', () => {
    it('adds 21,600 blocks', () => {
      expect(CityManager.getLockHeight(800_000)).toBe(821_600);
    });
  });

  describe('getTokenDistribution', () => {
    it('totals 3.2M tokens', () => {
      const dist = CityManager.getTokenDistribution();
      expect(dist.total).toBe(3_200_000);
      expect(dist.founder).toBe(640_000);     // 20%
      expect(dist.treasury).toBe(1_600_000);  // 50%
      expect(dist.publicSale).toBe(800_000);  // 25%
      expect(dist.protocolDev).toBe(160_000);  // 5%
      expect(dist.founder + dist.treasury + dist.publicSale + dist.protocolDev).toBe(dist.total);
    });
  });

  describe('founderVestedTokens', () => {
    it('0 months = 0 tokens', () => {
      expect(CityManager.founderVestedTokens(0)).toBe(0);
    });

    it('6 months = 50% vested', () => {
      expect(CityManager.founderVestedTokens(6)).toBe(320_000);
    });

    it('12 months = fully vested', () => {
      expect(CityManager.founderVestedTokens(12)).toBe(640_000);
    });

    it('24 months = still only 640,000 (capped)', () => {
      expect(CityManager.founderVestedTokens(24)).toBe(640_000);
    });
  });

  describe('isUBIActive', () => {
    it('inactive in early phases', () => {
      expect(CityManager.isUBIActive('genesis')).toBe(false);
      expect(CityManager.isUBIActive('settlement')).toBe(false);
      expect(CityManager.isUBIActive('village')).toBe(false);
      expect(CityManager.isUBIActive('town')).toBe(false);
    });

    it('active in city and metropolis', () => {
      expect(CityManager.isUBIActive('city')).toBe(true);
      expect(CityManager.isUBIActive('metropolis')).toBe(true);
    });
  });

  describe('buildFoundTransaction', () => {
    it('produces a valid OP_RETURN script', () => {
      const script = CityManager.buildFoundTransaction({
        name: 'Neo-Tokyo',
        description: 'A cyberpunk city',
        lat: 35.6762,
        lng: 139.6503,
        h3Res7: '8f283080dcb019d',
        founderPubkey: 'abcdef1234567890',
      });

      expect(Buffer.isBuffer(script)).toBe(true);
      expect(script[0]).toBe(0x6a); // OP_RETURN
    });
  });
});
