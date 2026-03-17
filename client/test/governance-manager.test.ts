import { describe, it, expect } from 'vitest';
import { GovernanceManager } from '../src/modules/governance-manager';

describe('GovernanceManager', () => {
  describe('getThreshold', () => {
    it('parameter_change = 51%', () => {
      expect(GovernanceManager.getThreshold('parameter_change')).toBe(0.51);
    });

    it('contract_upgrade = 66%', () => {
      expect(GovernanceManager.getThreshold('contract_upgrade')).toBe(0.66);
    });

    it('constitutional = 75%', () => {
      expect(GovernanceManager.getThreshold('constitutional')).toBe(0.75);
    });
  });

  describe('getQuorum', () => {
    it('village = 67%', () => {
      expect(GovernanceManager.getQuorum('village')).toBe(0.67);
    });

    it('town = 60%', () => {
      expect(GovernanceManager.getQuorum('town')).toBe(0.60);
    });

    it('city = 40%', () => {
      expect(GovernanceManager.getQuorum('city')).toBe(0.40);
    });

    it('metropolis = 51%', () => {
      expect(GovernanceManager.getQuorum('metropolis')).toBe(0.51);
    });
  });

  describe('isGenesisEra', () => {
    it('true before block 2,100,000', () => {
      expect(GovernanceManager.isGenesisEra(0)).toBe(true);
      expect(GovernanceManager.isGenesisEra(2_099_999)).toBe(true);
    });

    it('false at/after block 2,100,000', () => {
      expect(GovernanceManager.isGenesisEra(2_100_000)).toBe(false);
      expect(GovernanceManager.isGenesisEra(3_000_000)).toBe(false);
    });
  });

  describe('tally', () => {
    it('passes with 51% for parameter_change', () => {
      const result = GovernanceManager.tally(8, 2, 1, 25, 'city', 'parameter_change');
      // 8/(8+2) = 80% > 51%, quorum: 11/25 = 44% > 40%
      expect(result).toBe('passed');
    });

    it('rejects when below threshold', () => {
      const result = GovernanceManager.tally(3, 8, 0, 25, 'city', 'parameter_change');
      // 3/11 = 27% < 51%
      expect(result).toBe('rejected');
    });

    it('pending when quorum not met', () => {
      const result = GovernanceManager.tally(3, 0, 0, 25, 'city', 'parameter_change');
      // 3/25 = 12% < 40% quorum
      expect(result).toBe('pending');
    });

    it('constitutional requires 75%', () => {
      // 7/11 = 63.6% < 75%
      const result = GovernanceManager.tally(7, 4, 0, 25, 'city', 'constitutional');
      expect(result).toBe('rejected');
    });
  });

  describe('canExecute', () => {
    it('requires execution delay for normal proposals', () => {
      expect(GovernanceManager.canExecute(800_000, 800_100, 'parameter_change')).toBe(false);
      expect(GovernanceManager.canExecute(800_000, 800_432, 'parameter_change')).toBe(true);
    });

    it('emergency proposals execute without delay', () => {
      expect(GovernanceManager.canExecute(800_000, 800_001, 'emergency')).toBe(true);
    });
  });

  describe('getProposalDeposit', () => {
    it('returns 0.1 BSV (10,000,000 sats)', () => {
      expect(GovernanceManager.getProposalDeposit()).toBe(10_000_000);
    });
  });
});
