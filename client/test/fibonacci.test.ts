import { describe, it, expect } from 'vitest';
import {
  sequence,
  sumUpTo,
  blocksForCitizens,
  phaseForCitizens,
  governanceForPhase,
  phaseNumber,
} from '../src/utils/fibonacci';

describe('Fibonacci', () => {
  describe('sequence', () => {
    it('returns empty for 0', () => {
      expect(sequence(0)).toEqual([]);
    });

    it('returns [1] for 1', () => {
      expect(sequence(1)).toEqual([1]);
    });

    it('returns [1, 1] for 2', () => {
      expect(sequence(2)).toEqual([1, 1]);
    });

    it('returns first 5 Fibonacci numbers', () => {
      expect(sequence(5)).toEqual([1, 1, 2, 3, 5]);
    });

    it('returns first 10 Fibonacci numbers', () => {
      expect(sequence(10)).toEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]);
    });
  });

  describe('sumUpTo', () => {
    it('sum of first 1 = 1', () => {
      expect(sumUpTo(1)).toBe(1);
    });

    it('sum of first 5 = 12', () => {
      expect(sumUpTo(5)).toBe(12); // 1+1+2+3+5
    });

    it('sum of first 10 = 143', () => {
      expect(sumUpTo(10)).toBe(143);
    });
  });

  describe('blocksForCitizens', () => {
    it('0 citizens = 0 blocks', () => {
      expect(blocksForCitizens(0)).toBe(0);
    });

    it('1 citizen = 2 blocks (Genesis)', () => {
      expect(blocksForCitizens(1)).toBe(2);
    });

    it('2-3 citizens = 2 blocks (Settlement)', () => {
      expect(blocksForCitizens(2)).toBe(2);
      expect(blocksForCitizens(3)).toBe(2);
    });

    it('4-8 citizens = 5 blocks (Village)', () => {
      expect(blocksForCitizens(4)).toBe(5);
      expect(blocksForCitizens(8)).toBe(5);
    });

    it('9-20 citizens = 8 blocks (Town)', () => {
      expect(blocksForCitizens(9)).toBe(8);
      expect(blocksForCitizens(20)).toBe(8);
    });

    it('21-50 citizens = 16 blocks (City)', () => {
      expect(blocksForCitizens(21)).toBe(16);
      expect(blocksForCitizens(50)).toBe(16);
    });

    it('51+ citizens = 24 blocks (Metropolis)', () => {
      expect(blocksForCitizens(51)).toBe(24);
      expect(blocksForCitizens(100)).toBe(24);
    });
  });

  describe('phaseForCitizens', () => {
    it('0 citizens = none', () => {
      expect(phaseForCitizens(0)).toBe('none');
    });

    it('1 citizen = genesis', () => {
      expect(phaseForCitizens(1)).toBe('genesis');
    });

    it('2-3 citizens = settlement', () => {
      expect(phaseForCitizens(2)).toBe('settlement');
      expect(phaseForCitizens(3)).toBe('settlement');
    });

    it('4-8 citizens = village', () => {
      expect(phaseForCitizens(4)).toBe('village');
      expect(phaseForCitizens(8)).toBe('village');
    });

    it('9-20 citizens = town', () => {
      expect(phaseForCitizens(9)).toBe('town');
      expect(phaseForCitizens(20)).toBe('town');
    });

    it('21-50 citizens = city', () => {
      expect(phaseForCitizens(21)).toBe('city');
      expect(phaseForCitizens(50)).toBe('city');
    });

    it('51+ citizens = metropolis', () => {
      expect(phaseForCitizens(51)).toBe('metropolis');
      expect(phaseForCitizens(200)).toBe('metropolis');
    });
  });

  describe('governanceForPhase', () => {
    it('genesis/settlement = founder', () => {
      expect(governanceForPhase('genesis')).toBe('founder');
      expect(governanceForPhase('settlement')).toBe('founder');
    });

    it('village = tribal_council', () => {
      expect(governanceForPhase('village')).toBe('tribal_council');
    });

    it('town = republic', () => {
      expect(governanceForPhase('town')).toBe('republic');
    });

    it('city = direct_democracy', () => {
      expect(governanceForPhase('city')).toBe('direct_democracy');
    });

    it('metropolis = senate', () => {
      expect(governanceForPhase('metropolis')).toBe('senate');
    });
  });

  describe('phaseNumber', () => {
    it('returns correct phase numbers', () => {
      expect(phaseNumber('genesis')).toBe(0);
      expect(phaseNumber('settlement')).toBe(1);
      expect(phaseNumber('village')).toBe(2);
      expect(phaseNumber('town')).toBe(3);
      expect(phaseNumber('city')).toBe(4);
      expect(phaseNumber('metropolis')).toBe(5);
    });
  });
});
